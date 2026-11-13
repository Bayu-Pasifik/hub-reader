import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/repo_url.dart';
import '../data/models/download.dart';
import '../sources/catalog.dart';
import '../sources/catalog_repository.dart';
import '../sources/models.dart';
import '../sources/registry.dart';
import '../sources/source.dart';
import '../sources/source_exception.dart';
import 'core_providers.dart';
import 'download_providers.dart';
import 'source_health_provider.dart';
import 'source_settings_provider.dart';

/// Registry dibuat ulang saat domain sumber diubah di pengaturan, jadi
/// semua provider turunan (daftar, detail, halaman) ikut memuat ulang.
/// Katalog sumber template saat aplikasi dibuka (bawaan + salinan repo).
/// Di-override di main(); kosong di tes.
final initialSourceCatalogProvider = Provider<SourceCatalog>((ref) => SourceCatalog.empty);

/// Null di tes: katalog tidak diperbarui dari repo.
final sourceCatalogRepositoryProvider = Provider<SourceCatalogRepository?>((ref) => null);

/// Daftar URL repo katalog sumber komik (`catalog.json`), urut prioritas.
/// Bisa diganti ke mirror/fork bila repo utama hilang.
final sourceCatalogReposProvider =
    NotifierProvider<SourceCatalogReposNotifier, List<String>>(SourceCatalogReposNotifier.new);

class SourceCatalogReposNotifier extends Notifier<List<String>> {
  static const key = 'sources.catalogRepos.v1';
  static const defaults = [SourceCatalogRepository.defaultRepoUrl];

  static List<String> read(SharedPreferences prefs) => prefs.getStringList(key) ?? defaults;

  @override
  List<String> build() => read(ref.watch(sharedPreferencesProvider));

  Future<void> _save(List<String> repos) async {
    state = List.unmodifiable(repos);
    await ref.read(sharedPreferencesProvider).setStringList(key, repos);
  }

  /// Error teks bila gagal, null bila berhasil.
  Future<String?> add(String input) async {
    final url = normalizeRepoUrl(input);
    if (url == null) return 'Bukan URL http(s) yang valid';
    if (state.contains(url)) return 'Repo sudah ada';
    await _save([...state, url]);
    return null;
  }

  Future<void> remove(String url) => _save([...state]..remove(url));

  Future<void> moveUp(String url) async {
    final list = [...state];
    final i = list.indexOf(url);
    if (i <= 0) return;
    list
      ..removeAt(i)
      ..insert(i - 1, url);
    await _save(list);
  }

  Future<void> resetDefault() => _save(defaults);
}

class SourceCatalogState {
  const SourceCatalogState(this.catalog, {this.savedAt, this.refreshing = false, this.refreshError});

  final SourceCatalog catalog;

  /// Salinan repo tertua; null = belum diketahui.
  final DateTime? savedAt;
  final bool refreshing;

  /// Gagal memperbarui (sebagian/semua repo; salinan lama tetap dipakai).
  final Object? refreshError;

  SourceCatalogState copyWith({
    SourceCatalog? catalog,
    DateTime? savedAt,
    bool? refreshing,
    Object? refreshError,
  }) =>
      SourceCatalogState(
        catalog ?? this.catalog,
        savedAt: savedAt ?? this.savedAt,
        refreshing: refreshing ?? this.refreshing,
        refreshError: refreshError,
      );
}

/// Katalog aktif: mulai dari salinan lokal, lalu diperbarui dari repo di
/// latar bila sudah lama atau daftar repo berubah.
final sourceCatalogStateProvider =
    NotifierProvider<SourceCatalogNotifier, SourceCatalogState>(SourceCatalogNotifier.new);

class SourceCatalogNotifier extends Notifier<SourceCatalogState> {
  int _generation = 0;

  @override
  SourceCatalogState build() {
    final repos = ref.watch(sourceCatalogReposProvider);
    final previous = stateOrNull;
    final generation = ++_generation;
    Future.microtask(() => _reload(repos, generation, firstBuild: previous == null));
    return previous ?? SourceCatalogState(ref.read(initialSourceCatalogProvider));
  }

  Future<void> _reload(List<String> repos, int generation, {required bool firstBuild}) async {
    final repository = ref.read(sourceCatalogRepositoryProvider);
    if (repository == null) return;
    final cached = await repository.cached(repos);
    if (generation != _generation) return;
    _set(cached.catalog, savedAt: cached.savedAt);
    // Daftar repo berubah: langsung perbarui. Saat dibuka: hanya bila lama.
    if (!firstBuild || DateTime.now().difference(cached.savedAt) > SourceCatalogRepository.maxAge) {
      await refresh();
    }
  }

  void _set(SourceCatalog catalog, {DateTime? savedAt, Object? error, bool refreshing = false}) {
    final same = catalog.signature == state.catalog.signature;
    state = state.copyWith(
      catalog: same ? state.catalog : catalog,
      savedAt: savedAt,
      refreshing: refreshing,
      refreshError: error,
    );
  }

  /// Unduh ulang semua repo.
  Future<void> refresh() async {
    final repository = ref.read(sourceCatalogRepositoryProvider);
    if (repository == null) return;
    final generation = _generation;
    final repos = ref.read(sourceCatalogReposProvider);
    state = state.copyWith(refreshing: true, refreshError: state.refreshError);
    try {
      final fresh = await repository.fetch(repos);
      if (generation != _generation) return;
      _set(fresh.catalog, savedAt: fresh.savedAt, error: fresh.error);
    } catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(refreshing: false, refreshError: e);
    }
  }

  /// Hapus sumber yatim dari perangkat.
  Future<void> forgetOrphans() async {
    final repository = ref.read(sourceCatalogRepositoryProvider);
    if (repository == null) return;
    final repos = ref.read(sourceCatalogReposProvider);
    await repository.forgetOrphans(repos);
    final cached = await repository.cached(repos);
    _set(cached.catalog, savedAt: state.savedAt, error: state.refreshError);
  }
}

/// Katalog sumber template yang dipakai registry.
final sourceCatalogProvider = Provider<SourceCatalog>((ref) => ref.watch(sourceCatalogStateProvider).catalog);

final sourceRegistryProvider = Provider<SourceRegistry>((ref) {
  final settings = ref.watch(sourceBaseUrlProvider);
  final catalog = ref.watch(sourceCatalogProvider);
  final sources = builtInSources(catalog: catalog);
  for (final source in sources.whereType<HttpSource>()) {
    final setting = settings[source.id];
    source.previousHosts = {...?catalog.hostHistory[source.id], ...?setting?.previousHosts};
    if (setting != null && setting.hasOverride) source.baseUrlOverride = setting.url;
  }
  return SourceRegistry(
    sources,
    experimentalIds: {
      for (final e in catalog.entries)
        if (e.customized) e.id
    },
  );
});

final sourceProvider = Provider.family<MangaSource?, String>(
  (ref, id) => ref.watch(sourceRegistryProvider).byId(id),
);

SourceException _missing(String id) =>
    SourceException(SourceErrorKind.unknown, detail: 'Sumber "$id" tidak terdaftar.');

// ------------------------------------------------------------------ daftar

enum SourceListing { popular, latest, search }

/// [filters] hanya dipakai untuk listing search (FilterValues punya equality
/// struktural, jadi aman jadi bagian kunci provider).
typedef SourceListKey = ({String sourceId, SourceListing listing, String query, FilterValues filters});

class SourceListState {
  const SourceListState({
    this.items = const [],
    this.page = 0,
    this.hasNextPage = true,
    this.isLoading = false,
    this.error,
    this.loadMoreError,
  });

  final List<SourceManga> items;
  final int page;
  final bool hasNextPage;
  final bool isLoading;

  /// Gagal memuat halaman pertama.
  final SourceException? error;

  /// Gagal memuat halaman berikutnya.
  final SourceException? loadMoreError;

  bool get isEmpty => !isLoading && error == null && page > 0 && items.isEmpty;
}

/// Infinite scroll untuk populer / terbaru / pencarian satu sumber.
class SourceListNotifier extends AutoDisposeFamilyNotifier<SourceListState, SourceListKey> {
  bool _busy = false;
  bool _disposed = false;

  /// Naik tiap refresh; respons dari muatan lama diabaikan.
  int _generation = 0;

  @override
  SourceListState build(SourceListKey arg) {
    // `ref.invalidate` membangun ulang notifier yang SAMA; reset status lama
    // supaya muatan baru tidak dibuang.
    _disposed = false;
    _busy = false;
    _generation++;
    ref.onDispose(() => _disposed = true);
    Future.microtask(loadMore);
    return const SourceListState(isLoading: true);
  }

  Future<void> refresh() async {
    _generation++;
    _busy = false;
    state = const SourceListState(isLoading: true);
    await loadMore();
  }

  Future<void> loadMore({bool retry = false}) async {
    final current = state;
    if (_busy || !current.hasNextPage || current.error != null) return;
    if (current.loadMoreError != null && !retry) return;

    final source = ref.read(sourceProvider(arg.sourceId));
    if (source == null) {
      state = SourceListState(error: _missing(arg.sourceId), hasNextPage: false);
      return;
    }

    _busy = true;
    final generation = _generation;
    final next = current.page + 1;
    if (current.page > 0) {
      state = SourceListState(
        items: current.items,
        page: current.page,
        hasNextPage: current.hasNextPage,
        isLoading: true,
      );
    }
    try {
      final result = await switch (arg.listing) {
        SourceListing.popular => source.popular(next),
        SourceListing.latest => source.latest(next),
        SourceListing.search => source.search(next, arg.query, filters: arg.filters),
      };
      if (_disposed || generation != _generation) return;
      // Membuka sumber = cek kesehatan gratis.
      if (current.page == 0 && arg.listing != SourceListing.search) {
        ref.read(sourceHealthProvider.notifier).record(
              arg.sourceId,
              result.items.isEmpty
                  ? SourceHealth(HealthStatus.broken, DateTime.now(), detail: 'Daftar kosong')
                  : SourceHealth(HealthStatus.ok, DateTime.now()),
            );
      }
      final seen = current.items.toSet();
      final fresh = result.items.where(seen.add).toList();
      state = SourceListState(
        items: [...current.items, ...fresh],
        page: next,
        // Halaman tanpa item baru = situs mengulang halaman terakhir.
        hasNextPage: result.hasNextPage && fresh.isNotEmpty,
      );
    } catch (error) {
      if (_disposed || generation != _generation) return;
      final e = toSourceException(error);
      if (current.page == 0 && arg.listing != SourceListing.search) {
        ref.read(sourceHealthProvider.notifier).record(arg.sourceId, SourceHealth.fromError(e));
      }
      state = current.page == 0
          ? SourceListState(error: e)
          : SourceListState(
              items: current.items,
              page: current.page,
              hasNextPage: current.hasNextPage,
              loadMoreError: e,
            );
    } finally {
      if (generation == _generation) _busy = false;
    }
  }
}

final sourceListProvider =
    NotifierProvider.autoDispose.family<SourceListNotifier, SourceListState, SourceListKey>(SourceListNotifier.new);

// ------------------------------------------------------------ detail & bab

typedef SourceMangaKey = ({String sourceId, String url});

final sourceDetailsProvider = FutureProvider.autoDispose.family<SourceMangaDetails, SourceMangaKey>((ref, key) async {
  final source = ref.watch(sourceProvider(key.sourceId));
  if (source == null) throw _missing(key.sourceId);
  try {
    return await source.details(key.url);
  } catch (error) {
    throw toSourceException(error);
  }
});

final sourcePagesProvider = FutureProvider.autoDispose.family<List<String>, ({String sourceId, SourceChapter chapter})>(
  (ref, key) async {
    // Bab yang sudah diunduh dibaca dari file lokal (path absolut).
    final local = ref.watch(localPagesProvider(chapterKey(key.sourceId, key.chapter.url)));
    if (local != null) return local;
    final source = ref.watch(sourceProvider(key.sourceId));
    if (source == null) throw _missing(key.sourceId);
    try {
      return await source.pages(key.chapter);
    } catch (error) {
      throw toSourceException(error);
    }
  },
);

// ------------------------------------------------------------------ filter

/// Definisi filter per sumber. Tidak autoDispose: daftar genre cukup diambil
/// sekali per sesi.
final sourceFiltersProvider = FutureProvider.family<List<FilterDef>, String>((ref, id) async {
  final source = ref.watch(sourceProvider(id));
  if (source == null) throw _missing(id);
  return source.filters();
});
