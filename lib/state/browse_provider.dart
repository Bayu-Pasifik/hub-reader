import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../data/models/series.dart';
import '../data/models/series_query.dart';
import 'core_providers.dart';

/// State daftar + pencarian dengan infinite scroll.
class BrowseState {
  const BrowseState({
    this.query = const SeriesQuery(),
    this.items = const [],
    this.page = 0,
    this.lastPage = 1,
    this.total = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
    this.cachedAt,
  });

  final SeriesQuery query;
  final List<Series> items;

  /// Halaman terakhir yang sudah dimuat (0 = belum ada).
  final int page;
  final int lastPage;
  final int total;
  final bool isLoading;
  final bool isLoadingMore;

  /// Error saat memuat halaman pertama (layar penuh).
  final ApiException? error;

  /// Error saat memuat halaman berikutnya (ditampilkan di bawah grid).
  final ApiException? loadMoreError;
  final DateTime? cachedAt;

  bool get hasMore => page < lastPage;
  bool get isEmpty => !isLoading && error == null && page > 0 && items.isEmpty;

  static const _unset = Object();

  BrowseState copyWith({
    List<Series>? items,
    int? page,
    int? lastPage,
    int? total,
    bool? isLoadingMore,
    Object? loadMoreError = _unset,
    Object? cachedAt = _unset,
  }) =>
      BrowseState(
        query: query,
        items: items ?? this.items,
        page: page ?? this.page,
        lastPage: lastPage ?? this.lastPage,
        total: total ?? this.total,
        isLoading: isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: error,
        loadMoreError: identical(loadMoreError, _unset)
            ? this.loadMoreError
            : loadMoreError as ApiException?,
        cachedAt: identical(cachedAt, _unset) ? this.cachedAt : cachedAt as DateTime?,
      );
}

class BrowseNotifier extends Notifier<BrowseState> {
  BrowseNotifier(this.type);

  final SeriesType type;

  /// Default SeriesIndexRequest::perPage() = 24, maks 100.
  static const perPage = 24;

  /// Naik tiap pencarian baru; respons dari pencarian lama diabaikan
  /// (mencegah hasil "melompat" saat pengguna mengetik cepat).
  int _generation = 0;

  @override
  BrowseState build() {
    // Watch repository: ganti server di Pengaturan → daftar dimuat ulang.
    ref.watch(catalogRepositoryProvider);
    const query = SeriesQuery();
    Future.microtask(() => _loadFirstPage(query));
    return const BrowseState(query: query, isLoading: true);
  }

  Future<void> applyQuery(SeriesQuery query) => _loadFirstPage(query);

  Future<void> refresh() => _loadFirstPage(state.query);

  Future<void> _loadFirstPage(SeriesQuery query) async {
    final generation = ++_generation;
    state = BrowseState(query: query, isLoading: true);
    final repository = ref.read(catalogRepositoryProvider);
    try {
      final result = await repository.browse(type, query, page: 1, perPage: perPage);
      if (generation != _generation) return;
      state = BrowseState(
        query: query,
        items: result.data.items,
        page: result.data.currentPage,
        lastPage: result.data.lastPage,
        total: result.data.total,
        cachedAt: result.cachedAt,
      );
    } catch (error) {
      if (generation != _generation) return;
      state = BrowseState(query: query, error: toApiException(error));
    }
  }

  /// [retry] = pengguna menekan "Coba lagi" setelah gagal memuat halaman berikutnya.
  Future<void> loadMore({bool retry = false}) async {
    final current = state;
    if (current.isLoading ||
        current.isLoadingMore ||
        !current.hasMore ||
        current.error != null ||
        (current.loadMoreError != null && !retry)) {
      return;
    }
    final generation = _generation;
    state = current.copyWith(isLoadingMore: true, loadMoreError: null);
    final repository = ref.read(catalogRepositoryProvider);
    try {
      final result = await repository.browse(
        type,
        current.query,
        page: current.page + 1,
        perPage: perPage,
      );
      if (generation != _generation) return;
      // Data bisa bergeser bila scraper menambah seri di tengah paginasi;
      // buang duplikat berdasarkan id.
      final seen = current.items.map((s) => s.id).toSet();
      state = state.copyWith(
        items: [...current.items, ...result.data.items.where((s) => seen.add(s.id))],
        page: result.data.currentPage,
        lastPage: result.data.lastPage,
        total: result.data.total,
        isLoadingMore: false,
        cachedAt: result.cachedAt ?? current.cachedAt,
      );
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(isLoadingMore: false, loadMoreError: toApiException(error));
    }
  }
}

final novelBrowseProvider =
    NotifierProvider<BrowseNotifier, BrowseState>(() => BrowseNotifier(SeriesType.novel));

final comicBrowseProvider =
    NotifierProvider<BrowseNotifier, BrowseState>(() => BrowseNotifier(SeriesType.comic));

NotifierProvider<BrowseNotifier, BrowseState> browseProviderFor(SeriesType type) =>
    switch (type) {
      SeriesType.novel => novelBrowseProvider,
      SeriesType.comic => comicBrowseProvider,
    };
