package com.hubreader.hub_reader

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
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

        // Deep link ditangani di Dart (DeepLinks) dengan daftar rute yang
        // diizinkan, bukan deep linking otomatis Flutter.
        linkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hub_reader/links").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "initial" -> {
                        result.success(initialLink)
                        initialLink = null
                    }
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
