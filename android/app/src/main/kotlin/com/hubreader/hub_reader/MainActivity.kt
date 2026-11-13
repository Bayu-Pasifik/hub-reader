package com.hubreader.hub_reader

import android.view.KeyEvent
import android.view.WindowManager
import android.webkit.CookieManager
import android.webkit.WebSettings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var readerChannel: MethodChannel? = null

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
