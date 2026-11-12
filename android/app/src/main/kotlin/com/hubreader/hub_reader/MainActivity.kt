package com.hubreader.hub_reader

import android.webkit.CookieManager
import android.webkit.WebSettings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
