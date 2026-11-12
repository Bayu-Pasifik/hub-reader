import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/platform/webview_bridge.dart';
import 'core/storage/json_cache.dart';
import 'sources/cookie_store.dart';
import 'sources/source.dart';
import 'state/core_providers.dart';

const _cookiesKey = 'sources.cookies.v1';

/// Titik masuk aplikasi.
///
/// SharedPreferences dan folder cache dibuka sekali di sini (async), lalu
/// disuntikkan ke Riverpod lewat `overrides` sehingga provider lain bisa
/// memakainya secara sinkron.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final cache = await JsonCache.open();

  // Sumber on-device: UA asli WebView + cookie tersimpan (cf_clearance).
  HttpSource.userAgent = await WebViewBridge.defaultUserAgent() ?? HttpSource.fallbackUserAgent;
  HttpSource.cookies = SourceCookieStore.fromJson(
    prefs.getString(_cookiesKey),
    onChanged: (json) => prefs.setString(_cookiesKey, json),
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        jsonCacheProvider.overrideWithValue(cache),
      ],
      child: const HubReaderApp(),
    ),
  );
}
