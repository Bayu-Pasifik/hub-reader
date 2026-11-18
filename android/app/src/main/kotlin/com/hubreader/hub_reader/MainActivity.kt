package com.hubreader.hub_reader

import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.view.KeyEvent
import android.view.WindowManager
import android.webkit.CookieManager
import android.webkit.WebSettings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity: dibutuhkan local_auth (kunci aplikasi).
class MainActivity : FlutterFragmentActivity() {
    private var readerChannel: MethodChannel? = null
    private var linkChannel: MethodChannel? = null

    /// Tautan hubreader:// yang membuka aplikasi; diambil Dart sekali.
    private var initialLink: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Jangan proses ulang tautan saat activity dibuat ulang (rotasi dsb.).
        if (savedInstanceState == null) initialLink = linkOf(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        linkOf(intent)?.let { linkChannel?.invokeMethod("open", it) }
    }

    private fun linkOf(intent: Intent?): String? =
        if (intent?.action == Intent.ACTION_VIEW && intent.data?.scheme == "hubreader") intent.dataString else null

    /// Tombol volume dipakai pembaca novel untuk menggulir.
    private var interceptVolume = false

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val code = event.keyCode
        if (interceptVolume && (code == KeyEvent.KEYCODE_VOLUME_UP || code == KeyEvent.KEYCODE_VOLUME_DOWN)) {
            if (event.action == KeyEvent.ACTION_DOWN) {
                readerChannel?.invokeMethod("volume", if (code == KeyEvent.KEYCODE_VOLUME_DOWN) "down" else "up")
            }
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Render halaman PDF jadi JPEG (sumber Story About Us).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hub_reader/pdf").setMethodCallHandler { call, result ->
            if (call.method != "render") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            val outDir = call.argument<String>("outDir")
            if (path == null || outDir == null) {
                result.error("ARG", "path dan outDir wajib", null)
                return@setMethodCallHandler
            }
            Thread {
                try {
                    val files = ArrayList<String>()
                    android.os.ParcelFileDescriptor.open(java.io.File(path), android.os.ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
                        android.graphics.pdf.PdfRenderer(fd).use { renderer ->
                            for (i in 0 until renderer.pageCount) {
                                renderer.openPage(i).use { page ->
                                    val scale = minOf(2.5f, 1500f / page.width)
                                    val bmp = android.graphics.Bitmap.createBitmap(
                                        (page.width * scale).toInt(), (page.height * scale).toInt(), android.graphics.Bitmap.Config.ARGB_8888)
                                    android.graphics.Canvas(bmp).drawColor(android.graphics.Color.WHITE)
                                    page.render(bmp, null, null, android.graphics.pdf.PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                    val file = java.io.File(outDir, String.format("%04d.jpg", i))
                                    file.outputStream().use { bmp.compress(android.graphics.Bitmap.CompressFormat.JPEG, 90, it) }
                                    bmp.recycle()
                                    files.add(file.absolutePath)
                                }
                            }
                        }
                    }
                    runOnUiThread { result.success(files) }
                } catch (e: Exception) {
                    runOnUiThread { result.error("PDF", e.toString(), null) }
                }
            }.start()
        }

        // Deep link ditangani di Dart (DeepLinks) dengan daftar rute yang
        // diizinkan, bukan deep linking otomatis Flutter.
        linkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hub_reader/links").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "initial" -> {
                        result.success(initialLink)
                        initialLink = null
                    }
                    "abi" -> result.success(Build.SUPPORTED_ABIS.firstOrNull())
                    "appVersion" -> result.success(packageManager.getPackageInfo(packageName, 0).versionName)
                    // Hanya https (halaman rilis / APK di GitHub), dibuka di browser.
                    "openUrl" -> {
                        val url = call.arguments as? String
                        if (url == null || !url.startsWith("https://")) {
                            result.error("ARG", "url https wajib", null)
                        } else {
                            try {
                                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                                result.success(true)
                            } catch (e: ActivityNotFoundException) {
                                result.success(false)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }

        readerChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hub_reader/reader").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "volumeKeys" -> {
                        interceptVolume = call.arguments as? Boolean ?: false
                        result.success(null)
                    }
                    // 0.05..1 = kecerahan jendela; -1 = ikut sistem.
                    "brightness" -> {
                        val v = (call.arguments as? Number)?.toFloat() ?: -1f
                        val lp = window.attributes
                        lp.screenBrightness = if (v < 0f) WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE else v
                        window.attributes = lp
                        result.success(null)
                    }
                    "secure" -> {
                        if (call.arguments as? Boolean == true) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    "keepScreenOn" -> {
                        if (call.arguments as? Boolean == true) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // Simpan gambar ke galeri (Pictures/Hub Reader) lewat MediaStore; tanpa izin penyimpanan (API 29+).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hub_reader/media")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveImage" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val name = call.argument<String>("name")
                        val mime = call.argument<String>("mime") ?: "image/jpeg"
                        if (bytes == null || name == null) {
                            result.error("ARG", "bytes dan name wajib diisi", null)
                        } else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                            // Android 9 ke bawah butuh izin tulis; Dart memakai dialog simpan sistem.
                            result.success(null)
                        } else {
                            try {
                                val values = ContentValues().apply {
                                    put(MediaStore.Images.Media.DISPLAY_NAME, name)
                                    put(MediaStore.Images.Media.MIME_TYPE, mime)
                                    put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/Hub Reader")
                                    put(MediaStore.Images.Media.IS_PENDING, 1)
                                }
                                val resolver = contentResolver
                                val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                                if (uri == null) {
                                    result.error("IO", "Tidak bisa membuat berkas di galeri", null)
                                } else {
                                    resolver.openOutputStream(uri)?.use { it.write(bytes) }
                                    values.clear()
                                    values.put(MediaStore.Images.Media.IS_PENDING, 0)
                                    resolver.update(uri, values, null, null)
                                    result.success(uri.toString())
                                }
                            } catch (e: Exception) {
                                result.error("IO", e.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // Jaringan tanpa kuota (Wi-Fi/ethernet) untuk opsi "unduh hanya lewat Wi-Fi".
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hub_reader/network")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "unmetered" -> {
                        val cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
                        val caps = cm.getNetworkCapabilities(cm.activeNetwork)
                        result.success(caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) == true)
                    }
                    else -> result.notImplemented()
                }
            }

        // Membaca cookie WebView, termasuk yang HttpOnly seperti cf_clearance,
        // yang tidak bisa diakses lewat document.cookie.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hub_reader/cookies")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "get" -> {
                        val url = call.argument<String>("url")
                        if (url == null) {
                            result.error("ARG", "url wajib diisi", null)
                        } else {
                            result.success(CookieManager.getInstance().getCookie(url))
                        }
                    }
                    // UA bawaan WebView; dipakai juga oleh Dio karena
                    // cf_clearance hanya berlaku untuk User-Agent yang sama.
                    "userAgent" -> result.success(WebSettings.getDefaultUserAgent(this))
                    "flush" -> {
                        CookieManager.getInstance().flush()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
