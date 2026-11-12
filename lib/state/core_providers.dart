import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../core/network/dio_factory.dart';
import '../core/storage/json_cache.dart';
import '../data/api/scraper_hub_api.dart';
import '../data/local/library_store.dart';
import '../data/repositories/catalog_repository.dart';

/// Di-override di main() setelah SharedPreferences siap.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override sharedPreferencesProvider di main()'),
);

/// Di-override di main() setelah folder cache dibuka.
final jsonCacheProvider = Provider<JsonCache>(
  (ref) => throw UnimplementedError('Override jsonCacheProvider di main()'),
);

/// Alamat server & API key. Mengubahnya membuat ulang Dio → API → repository,
/// sehingga semua layar otomatis memuat ulang dari server baru.
final settingsProvider =
    NotifierProvider<SettingsNotifier, AppConfig>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<AppConfig> {
  static const _baseUrlKey = 'settings.base_url';
  static const _apiKeyKey = 'settings.api_key';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppConfig build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final defaults = AppConfig.fromDefines();
    return AppConfig(
      baseUrl: prefs.getString(_baseUrlKey) ?? defaults.baseUrl,
      apiKey: prefs.getString(_apiKeyKey) ?? defaults.apiKey,
    );
  }

  Future<void> save(AppConfig config) async {
    await _prefs.setString(_baseUrlKey, config.baseUrl.trim());
    await _prefs.setString(_apiKeyKey, config.apiKey.trim());
    state = config;
  }

  Future<void> resetToDefaults() async {
    await _prefs.remove(_baseUrlKey);
    await _prefs.remove(_apiKeyKey);
    state = AppConfig.fromDefines();
  }
}

final dioProvider = Provider<Dio>((ref) {
  final dio = createDio(ref.watch(settingsProvider));
  ref.onDispose(dio.close);
  return dio;
});

final scraperHubApiProvider = Provider<ScraperHubApi>((ref) => ScraperHubApi(
      ref.watch(dioProvider),
      hasApiKey: ref.watch(settingsProvider.select((c) => c.hasApiKey)),
    ));

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) => CatalogRepository(
      ref.watch(scraperHubApiProvider),
      ref.watch(jsonCacheProvider),
      cacheNamespace: ref.watch(settingsProvider.select((c) => c.normalizedBaseUrl)),
    ));

final libraryStoreProvider =
    Provider<LibraryStore>((ref) => LibraryStore(ref.watch(sharedPreferencesProvider)));

/// Origin server, untuk memperbaiki URL gambar (lihat resolveMediaUrl).
final apiOriginProvider = Provider<Uri?>(
  (ref) => ref.watch(settingsProvider.select((c) => c.origin)),
);
