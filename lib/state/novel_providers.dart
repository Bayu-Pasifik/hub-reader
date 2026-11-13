import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/download.dart';
import '../novels/lnreader/engine_isolate.dart';
import '../novels/lnreader/http_bridge.dart';
import '../novels/lnreader/js_engine.dart';
import '../novels/local_epub.dart';
import '../novels/novel_models.dart';
import '../novels/novel_source.dart';
import '../novels/plugin_repository.dart';
import '../sources/source.dart';
import '../sources/source_exception.dart';
import 'core_providers.dart';
import 'download_providers.dart';
import 'novel_health_provider.dart';

/// Prefix id sumber novel di favorit/riwayat (berbagi store dengan komik).
const novelSourcePrefix = 'lnr:';

bool isNovelSourceId(String sourceId) => sourceId.startsWith(novelSourcePrefix);
String novelLibraryId(String pluginId) => '$novelSourcePrefix$pluginId';
String pluginIdOf(String sourceId) => sourceId.substring(novelSourcePrefix.length);

/// Di-override di main() (butuh folder aplikasi).
final novelRepositoryProvider = Provider<NovelPluginRepository>(
  (ref) => throw UnimplementedError('Override novelRepositoryProvider di main()'),
);

/// `@libs/storage` plugin, disimpan permanen di SharedPreferences.
class PrefsKeyValueStore implements PluginKeyValueStore {
  PrefsKeyValueStore(this._prefs);

  static const _prefix = 'lnr.kv.';
  final SharedPreferences _prefs;

  @override
  String? get(String key) => _prefs.getString('$_prefix$key');

  @override
  void set(String key, String value) => _prefs.setString('$_prefix$key', value);

  @override
  void delete(String key) => _prefs.remove('$_prefix$key');

  @override
  Iterable<String> keys() =>
      _prefs.getKeys().where((k) => k.startsWith(_prefix)).map((k) => k.substring(_prefix.length));
}

/// Satu engine QuickJS (isolate latar) untuk semua plugin, dibuat saat
/// sumber novel pertama dibuka.
final novelEngineProvider = FutureProvider<LnEngine>((ref) async {
  final runtime = await rootBundle.loadString('assets/lnreader/runtime.js');
  final engine = await LnEngine.spawn(
    runtimeCode: runtime,
    fetcher: LnFetcher(
      userAgent: () => HttpSource.userAgent,
      cookieHeaderFor: (uri) => HttpSource.cookies.cookieHeaderFor(uri),
      onSetCookie: (uri, cookies) => HttpSource.cookies.save(uri, cookies),
    ),
    store: PrefsKeyValueStore(ref.watch(sharedPreferencesProvider)),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

// ------------------------------------------------------------- manifest

class NovelManifest {
  const NovelManifest(this.plugins, {required this.savedAt, this.refreshError});

  final List<NovelPluginInfo> plugins;
  final DateTime savedAt;

  /// Gagal memperbarui (manifest lama tetap dipakai).
  final Object? refreshError;

  NovelPluginInfo? byId(String id) {
    for (final p in plugins) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// Daftar plugin: salinan lokal dulu (cepat & offline), lalu diperbarui dari
/// GitHub bila sudah lama atau belum ada.
final novelManifestProvider =
    AsyncNotifierProvider<NovelManifestNotifier, NovelManifest>(NovelManifestNotifier.new);

class NovelManifestNotifier extends AsyncNotifier<NovelManifest> {
  NovelPluginRepository get _repo => ref.read(novelRepositoryProvider);

  @override
  Future<NovelManifest> build() async {
    final cached = await _repo.cachedManifest();
    if (cached == null) {
      return NovelManifest(await _repo.fetchManifest(), savedAt: DateTime.now());
    }
    final (plugins, savedAt) = cached;
    if (DateTime.now().difference(savedAt) > NovelPluginRepository.manifestMaxAge) {
      Future.microtask(() => refresh(silent: true));
    }
    return NovelManifest(plugins, savedAt: savedAt);
  }

  Future<void> refresh({bool silent = false}) async {
    final old = state.valueOrNull;
    if (!silent && old == null) state = const AsyncLoading();
    try {
      state = AsyncData(NovelManifest(await _repo.fetchManifest(), savedAt: DateTime.now()));
    } catch (e, st) {
      state = old == null
          ? AsyncError(e, st)
          : AsyncData(NovelManifest(old.plugins, savedAt: old.savedAt, refreshError: e));
    }
  }
}

/// Plugin yang pernah dibuka (kode tersimpan), tampil paling atas.
final novelInstalledProvider = FutureProvider<Set<String>>((ref) {
  ref.watch(novelManifestProvider);
  return ref.watch(novelRepositoryProvider).installedIds();
});

final novelLanguageProvider = NotifierProvider<NovelLanguageNotifier, String?>(NovelLanguageNotifier.new);

class NovelLanguageNotifier extends Notifier<String?> {
  static const _key = 'novels.language.v1';

  @override
  String? build() => ref.watch(sharedPreferencesProvider).getString(_key);

  Future<void> set(String? lang) async {
    state = lang;
    final prefs = ref.read(sharedPreferencesProvider);
    lang == null ? await prefs.remove(_key) : await prefs.setString(_key, lang);
  }
}

// --------------------------------------------------------------- sumber

/// Plugin dimuat sekali per sesi (tidak autoDispose).
final novelSourceProvider = FutureProvider.family<NovelSource, String>((ref, id) async {
  if (id == LocalNovelSource.pluginId) return LocalNovelSource();
  final manifest = await ref.watch(novelManifestProvider.future);
  final info = manifest.byId(id);
  if (info == null) {
    throw SourceException(SourceErrorKind.unknown, detail: 'Plugin novel "$id" tidak ada di daftar.');
  }
  final code = await ref.watch(novelRepositoryProvider).code(info);
  final engine = await ref.watch(novelEngineProvider.future);
  final meta = await engine.load(id, code);
  ref.invalidate(novelInstalledProvider);
  return NovelSource(info: info, engine: engine, meta: meta);
});

/// Sumber yang sudah dimuat (untuk header sampul di favorit/riwayat), tanpa
/// memicu pemuatan.
final loadedNovelSourceProvider = Provider.family<NovelSource?, String>(
  (ref, id) => ref.watch(novelSourceProvider(id)).valueOrNull,
);

// --------------------------------------------------------------- daftar

enum NovelListing { popular, latest, search }

/// [filtersJson]: nilai filter ter-encode, agar kunci provider punya equality.
typedef NovelListKey = ({String pluginId, NovelListing listing, String query, String filtersJson});

class NovelListState {
  const NovelListState({
    this.items = const [],
    this.page = 0,
    this.hasNextPage = true,
    this.isLoading = false,
    this.error,
    this.loadMoreError,
  });

  final List<NovelItem> items;
  final int page;
  final bool hasNextPage;
  final bool isLoading;
  final SourceException? error;
  final SourceException? loadMoreError;

  bool get isEmpty => !isLoading && error == null && page > 0 && items.isEmpty;
}

class NovelListNotifier extends AutoDisposeFamilyNotifier<NovelListState, NovelListKey> {
  bool _busy = false;
  bool _disposed = false;
  int _generation = 0;

  @override
  NovelListState build(NovelListKey arg) {
    // `ref.invalidate` membangun ulang notifier yang SAMA (onDispose ikut
    // terpanggil), jadi status lama harus di-reset. Tanpa ini, daftar macet
    // memuat setelah kembali dari WebView.
    _disposed = false;
    _busy = false;
    _generation++;
    ref.onDispose(() => _disposed = true);
    Future.microtask(loadMore);
    return const NovelListState(isLoading: true);
  }

  Future<void> refresh() async {
    _generation++;
    _busy = false;
    state = const NovelListState(isLoading: true);
    await loadMore();
  }

  Future<void> loadMore({bool retry = false}) async {
    final current = state;
    if (_busy || !current.hasNextPage || current.error != null) return;
    if (current.loadMoreError != null && !retry) return;
    _busy = true;
    final generation = _generation;
    final next = current.page + 1;
    if (current.page > 0) {
      state = NovelListState(items: current.items, page: current.page, isLoading: true);
    }
    try {
      final source = await ref.read(novelSourceProvider(arg.pluginId).future);
      final filters = arg.filtersJson.isEmpty ? const <String, Object?>{} : (jsonDecode(arg.filtersJson) as Map).cast<String, Object?>();
      final items = await switch (arg.listing) {
        NovelListing.popular => source.popular(next, filters: filters),
        NovelListing.latest => source.popular(next, latest: true, filters: filters),
        NovelListing.search => source.search(arg.query, next),
      };
      if (next == 1 && arg.listing == NovelListing.popular && arg.filtersJson.isEmpty) {
        ref.read(novelHealthProvider.notifier).recordResult(arg.pluginId, empty: items.isEmpty);
      }
      if (_disposed || generation != _generation) return;
      final seen = current.items.toSet();
      final fresh = items.where(seen.add).toList();
      state = NovelListState(
        items: [...current.items, ...fresh],
        page: next,
        // Halaman tanpa item baru = situs mengulang halaman terakhir.
        hasNextPage: fresh.isNotEmpty,
      );
    } catch (error) {
      if (next == 1 && arg.listing == NovelListing.popular) {
        ref.read(novelHealthProvider.notifier).recordResult(arg.pluginId, error: error);
      }
      if (_disposed || generation != _generation) return;
      final e = novelError(error);
      state = current.page == 0
          ? NovelListState(error: e)
          : NovelListState(items: current.items, page: current.page, loadMoreError: e);
    } finally {
      if (generation == _generation) _busy = false;
    }
  }
}

final novelListProvider =
    NotifierProvider.autoDispose.family<NovelListNotifier, NovelListState, NovelListKey>(NovelListNotifier.new);

// ------------------------------------------------------------ detail & bab

typedef NovelKey = ({String pluginId, String path});

/// Detail novel: dari plugin, disimpan ke cache supaya bab yang sudah diunduh
/// tetap bisa dibuka (beserta daftar babnya) saat offline.
final novelDetailsProvider = FutureProvider.autoDispose.family<NovelDetails, NovelKey>((ref, key) async {
  final cache = ref.read(jsonCacheProvider);
  final cacheKey = 'lnr.details|${key.pluginId}|${key.path}';
  try {
    final source = await ref.watch(novelSourceProvider(key.pluginId).future);
    final raw = await source.detailsRaw(key.path);
    unawaited(cache.write(cacheKey, raw));
    return NovelDetails.parse(key.path, raw);
  } catch (_) {
    final cached = await cache.read(cacheKey);
    if (cached != null) return NovelDetails.parse(key.path, cached.data);
    rethrow;
  }
});

/// Bab satu halaman daftar (plugin berhalaman). Halaman 1 diambil dari detail
/// bila detail sudah membawa bab.
final novelChapterPageProvider =
    FutureProvider.autoDispose.family<List<NovelChapter>, ({String pluginId, String path, int page})>(
  (ref, key) async {
    if (key.page == 1) {
      final details = await ref.watch(novelDetailsProvider((pluginId: key.pluginId, path: key.path)).future);
      final paged = ref.read(loadedNovelSourceProvider(key.pluginId))?.hasParsePage ?? details.totalPages > 1;
      if (details.chapters.isNotEmpty || !paged) return details.chapters;
    }
    final cache = ref.read(jsonCacheProvider);
    final cacheKey = 'lnr.page|${key.pluginId}|${key.path}|${key.page}';
    try {
      final source = await ref.watch(novelSourceProvider(key.pluginId).future);
      final raw = await source.chapterPageRaw(key.path, key.page);
      unawaited(cache.write(cacheKey, raw));
      return NovelSource.parseChapterList(raw);
    } catch (_) {
      final cached = await cache.read(cacheKey);
      if (cached != null) return NovelSource.parseChapterList(cached.data);
      rethrow;
    }
  },
);

/// Isi bab (HTML). Disimpan sebentar setelah tidak dipakai supaya bab
/// sebelumnya/berikutnya yang sudah dimuat tidak diunduh ulang.
final novelChapterProvider = FutureProvider.autoDispose.family<String, ({String pluginId, String path})>(
  (ref, key) async {
    final link = ref.keepAlive();
    final timer = Timer(const Duration(minutes: 5), link.close);
    ref.onDispose(timer.cancel);
    final offline = ref.read(downloadIndexProvider)[chapterKey(novelLibraryId(key.pluginId), key.path)];
    if (offline != null) {
      final html = await ref.read(downloadStoreProvider).readNovelChapter(offline);
      if (html != null) return html;
    }
    final source = await ref.watch(novelSourceProvider(key.pluginId).future);
    final html = await source.chapter(key.path);
    if (html.trim().isEmpty) {
      throw const SourceException(SourceErrorKind.parse, detail: 'Isi bab kosong.');
    }
    return html;
  },
);

// ------------------------------------------------------- pengaturan baca

enum NovelReaderTheme { system, light, sepia, dark, black }

/// Jenis huruf pembaca (font sistem Android).
enum NovelFont {
  sans('Sans', null),
  serif('Serif', 'serif'),
  condensed('Rapat', 'sans-serif-condensed'),
  mono('Mono', 'monospace');

  const NovelFont(this.label, this.family);

  final String label;
  final String? family;
}

class NovelReaderSettings {
  const NovelReaderSettings({
    this.fontSize = 18,
    this.lineHeight = 1.6,
    this.font = NovelFont.sans,
    this.justify = false,
    this.theme = NovelReaderTheme.system,
    this.padding = 18,
    this.ttsRate = 0.5,
    this.ttsPitch = 1.0,
    this.ttsAutoNext = true,
    this.autoNext = true,
    this.volumeKeys = false,
    this.keepScreenOn = true,
    this.autoScrollSpeed = 40,
  });

  final double fontSize;
  final double lineHeight;
  final NovelFont font;
  final bool justify;
  final NovelReaderTheme theme;
  final double padding;

  /// Kecepatan suara TTS (0.1–1.0; 0.5 = normal di Android).
  final double ttsRate;
  final double ttsPitch;

  /// Lanjut membacakan bab berikutnya setelah bab selesai.
  final bool ttsAutoNext;

  /// Tarik di akhir bab untuk pindah ke bab berikutnya.
  final bool autoNext;

  /// Tombol volume untuk menggulir satu layar.
  final bool volumeKeys;
  final bool keepScreenOn;

  /// Kecepatan gulir otomatis (piksel logis per detik).
  final double autoScrollSpeed;

  NovelReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    NovelFont? font,
    bool? justify,
    NovelReaderTheme? theme,
    double? padding,
    double? ttsRate,
    double? ttsPitch,
    bool? ttsAutoNext,
    bool? autoNext,
    bool? volumeKeys,
    bool? keepScreenOn,
    double? autoScrollSpeed,
  }) =>
      NovelReaderSettings(
        fontSize: fontSize ?? this.fontSize,
        lineHeight: lineHeight ?? this.lineHeight,
        font: font ?? this.font,
        justify: justify ?? this.justify,
        theme: theme ?? this.theme,
        padding: padding ?? this.padding,
        ttsRate: ttsRate ?? this.ttsRate,
        ttsPitch: ttsPitch ?? this.ttsPitch,
        ttsAutoNext: ttsAutoNext ?? this.ttsAutoNext,
        autoNext: autoNext ?? this.autoNext,
        volumeKeys: volumeKeys ?? this.volumeKeys,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
        autoScrollSpeed: autoScrollSpeed ?? this.autoScrollSpeed,
      );

  Map<String, Object> toJson() => {
        'font_size': fontSize,
        'line_height': lineHeight,
        'font': font.name,
        'justify': justify,
        'theme': theme.name,
        'padding': padding,
        'tts_rate': ttsRate,
        'tts_pitch': ttsPitch,
        'tts_auto_next': ttsAutoNext,
        'auto_next': autoNext,
        'volume_keys': volumeKeys,
        'keep_screen_on': keepScreenOn,
        'auto_scroll_speed': autoScrollSpeed,
      };

  static NovelReaderSettings fromJson(Map<String, Object?> json) => NovelReaderSettings(
        fontSize: (json['font_size'] as num?)?.toDouble() ?? 18,
        lineHeight: (json['line_height'] as num?)?.toDouble() ?? 1.6,
        font: NovelFont.values.where((f) => f.name == json['font']).firstOrNull ??
            (json['serif'] == true ? NovelFont.serif : NovelFont.sans),
        justify: json['justify'] == true,
        theme: NovelReaderTheme.values.where((t) => t.name == json['theme']).firstOrNull ?? NovelReaderTheme.system,
        padding: (json['padding'] as num?)?.toDouble() ?? 18,
        ttsRate: (json['tts_rate'] as num?)?.toDouble() ?? 0.5,
        ttsPitch: (json['tts_pitch'] as num?)?.toDouble() ?? 1.0,
        ttsAutoNext: json['tts_auto_next'] != false,
        autoNext: json['auto_next'] != false,
        volumeKeys: json['volume_keys'] == true,
        keepScreenOn: json['keep_screen_on'] != false,
        autoScrollSpeed: (json['auto_scroll_speed'] as num?)?.toDouble() ?? 40,
      );
}

final novelReaderSettingsProvider =
    NotifierProvider<NovelReaderSettingsNotifier, NovelReaderSettings>(NovelReaderSettingsNotifier.new);

class NovelReaderSettingsNotifier extends Notifier<NovelReaderSettings> {
  static const _key = 'novels.reader.v1';

  @override
  NovelReaderSettings build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const NovelReaderSettings();
    try {
      return NovelReaderSettings.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
    } catch (_) {
      return const NovelReaderSettings();
    }
  }

  Future<void> update(NovelReaderSettings Function(NovelReaderSettings) change) async {
    state = change(state);
    await ref.read(sharedPreferencesProvider).setString(_key, jsonEncode(state.toJson()));
  }
}
