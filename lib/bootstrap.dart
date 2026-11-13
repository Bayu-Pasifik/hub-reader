import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/platform/webview_bridge.dart';
import 'core/storage/json_cache.dart';
import 'data/local/download_store.dart';
import 'novels/plugin_repository.dart';
import 'sources/catalog.dart';
import 'sources/cookie_store.dart';
import 'sources/local/local_source.dart';
import 'sources/source.dart';
import 'state/core_providers.dart';
import 'state/download_providers.dart';
import 'state/novel_providers.dart';
import 'state/source_providers.dart';

const _cookiesKey = 'sources.cookies.v1';
const _userAgentKey = 'sources.user_agent.v1';

/// Dependensi async yang dibuka sekali lalu disuntikkan ke Riverpod.
///
/// Dipakai oleh `main()` dan oleh isolate latar belakang (WorkManager), agar
/// pengecekan bab baru di latar memakai penyimpanan & sumber yang sama.
class AppDependencies {
  AppDependencies._({
    required this.prefs,
    required this.cache,
    required this.downloads,
    required this.novelPlugins,
    required this.catalog,
  });

  final SharedPreferences prefs;
  final JsonCache cache;
  final DownloadStore downloads;
  final NovelPluginRepository novelPlugins;
  final SourceCatalog catalog;

  /// [background]: tidak ada Activity, jadi WebView tidak bisa ditanya
  /// User-Agent-nya; pakai yang disimpan saat aplikasi terakhir dibuka.
  static Future<AppDependencies> open({bool background = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cache = await JsonCache.open();
    final downloads = await DownloadStore.open(prefs);
    final supportDir = await getApplicationSupportDirectory();
    final novelPlugins = NovelPluginRepository(Directory('${supportDir.path}/lnreader'));
    final catalog = SourceCatalog.fromJsonString(await rootBundle.loadString('assets/sources/catalog.json'));

    // Komik lokal: folder di penyimpanan aplikasi eksternal supaya bisa diisi
    // lewat USB / pengelola file (Android/data/<paket>/files/local).
    Directory? external;
    try {
      external = await getExternalStorageDirectory();
    } catch (_) {
      external = null;
    }
    LocalSource.root = Directory('${(external ?? supportDir).path}/local');
    LocalSource.cacheDir = Directory('${(await getTemporaryDirectory()).path}/local_pages');
    try {
      await LocalSource.root!.create(recursive: true);
    } catch (_) {
      // dibuat ulang saat impor
    }

    // Sumber on-device: UA asli WebView + cookie tersimpan (cf_clearance).
    // Cookie cf_clearance terikat ke UA, jadi isolate latar harus memakai UA
    // yang sama.
    final String? userAgent;
    if (background) {
      userAgent = prefs.getString(_userAgentKey);
    } else {
      userAgent = await WebViewBridge.defaultUserAgent();
      if (userAgent != null) await prefs.setString(_userAgentKey, userAgent);
    }
    HttpSource.userAgent = userAgent ?? HttpSource.fallbackUserAgent;

    final deps = AppDependencies._(
      prefs: prefs,
      cache: cache,
      downloads: downloads,
      novelPlugins: novelPlugins,
      catalog: catalog,
    );
    deps.loadCookies();
    return deps;
  }

  /// Dibaca ulang juga setelah memulihkan cadangan.
  void loadCookies() => HttpSource.cookies = SourceCookieStore.fromJson(
        prefs.getString(_cookiesKey),
        onChanged: (json) => prefs.setString(_cookiesKey, json),
      );

  List<Override> get overrides => [
        sharedPreferencesProvider.overrideWithValue(prefs),
        jsonCacheProvider.overrideWithValue(cache),
        downloadStoreProvider.overrideWithValue(downloads),
        sourceCatalogProvider.overrideWithValue(catalog),
        novelRepositoryProvider.overrideWithValue(novelPlugins),
      ];
}
