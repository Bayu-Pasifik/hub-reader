import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'app_restart.dart';
import 'core/platform/webview_bridge.dart';
import 'core/storage/json_cache.dart';
import 'data/local/download_store.dart';
import 'novels/plugin_repository.dart';
import 'sources/catalog.dart';
import 'sources/cookie_store.dart';
import 'sources/source.dart';
import 'state/core_providers.dart';
import 'state/download_providers.dart';
import 'state/novel_providers.dart';
import 'state/source_providers.dart';

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
  final downloads = await DownloadStore.open(prefs);
  final supportDir = await getApplicationSupportDirectory();
  final novelPlugins = NovelPluginRepository(Directory('${supportDir.path}/lnreader'));
  final catalog = SourceCatalog.fromJsonString(await rootBundle.loadString('assets/sources/catalog.json'));

  // Sumber on-device: UA asli WebView + cookie tersimpan (cf_clearance).
  HttpSource.userAgent = await WebViewBridge.defaultUserAgent() ?? HttpSource.fallbackUserAgent;
  void loadCookies() => HttpSource.cookies = SourceCookieStore.fromJson(
        prefs.getString(_cookiesKey),
        onChanged: (json) => prefs.setString(_cookiesKey, json),
      );
  loadCookies();

  runApp(
    AppRestart(
      // Setelah memulihkan cadangan: cookie & semua provider dibaca ulang.
      onRestart: loadCookies,
      builder: (_) => ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          jsonCacheProvider.overrideWithValue(cache),
          downloadStoreProvider.overrideWithValue(downloads),
          sourceCatalogProvider.overrideWithValue(catalog),
          novelRepositoryProvider.overrideWithValue(novelPlugins),
        ],
        child: const HubReaderApp(),
      ),
    ),
  );
}
