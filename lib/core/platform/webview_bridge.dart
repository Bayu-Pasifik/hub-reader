import 'dart:io';

import 'package:flutter/services.dart';

/// Akses ke WebView Android lewat MethodChannel (lihat MainActivity.kt).
class WebViewBridge {
  static const _channel = MethodChannel('hub_reader/cookies');

  /// Cookie WebView untuk [url], termasuk yang HttpOnly (cf_clearance).
  static Future<String?> cookiesFor(Uri url) async {
    if (!Platform.isAndroid) return null;
    try {
      await _channel.invokeMethod<void>('flush');
      return await _channel.invokeMethod<String>('get', {'url': url.toString()});
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// User-Agent bawaan WebView perangkat.
  static Future<String?> defaultUserAgent() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('userAgent');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
