import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/download.dart';
import '../sources/models.dart';
import '../sources/registry.dart';
import '../sources/source.dart';
import '../sources/source_exception.dart';
import 'download_providers.dart';
import 'source_settings_provider.dart';

/// Registry dibuat ulang saat domain sumber diubah di pengaturan, jadi
/// semua provider turunan (daftar, detail, halaman) ikut memuat ulang.
final sourceRegistryProvider = Provider<SourceRegistry>((ref) {
  final settings = ref.watch(sourceBaseUrlProvider);
  final sources = builtInSources();
  for (final source in sources.whereType<HttpSource>()) {
    final setting = settings[source.id];
    if (setting == null) continue;
    if (setting.hasOverride) source.baseUrlOverride = setting.url;
    source.previousHosts = setting.previousHosts.toSet();
  }
  return SourceRegistry(sources);
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

final sourceListProvider = NotifierProvider.autoDispose
    .family<SourceListNotifier, SourceListState, SourceListKey>(SourceListNotifier.new);

// ------------------------------------------------------------ detail & bab

typedef SourceMangaKey = ({String sourceId, String url});

final sourceDetailsProvider =
    FutureProvider.autoDispose.family<SourceMangaDetails, SourceMangaKey>((ref, key) async {
  final source = ref.watch(sourceProvider(key.sourceId));
  if (source == null) throw _missing(key.sourceId);
  try {
    return await source.details(key.url);
  } catch (error) {
    throw toSourceException(error);
  }
});

final sourcePagesProvider =
    FutureProvider.autoDispose.family<List<String>, ({String sourceId, SourceChapter chapter})>(
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
