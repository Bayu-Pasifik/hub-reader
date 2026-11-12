/// Urutan yang didukung `SeriesIndexRequest`: sort=latest|title|chapters.
enum SeriesSort {
  latest('Terbaru'),
  title('Judul A-Z'),
  chapters('Bab terbanyak');

  const SeriesSort(this.label);

  final String label;
}

/// Parameter GET /api/v1/{novels|comics}.
///
/// Validasi server: search ≤100 karakter, genre ≤64, status ≤32,
/// per_page 1..100. Pencarian mencocokkan judul ATAU penulis (LIKE).
class SeriesQuery {
  const SeriesQuery({
    this.search = '',
    this.genre,
    this.status,
    this.sort = SeriesSort.latest,
  });

  final String search;
  final String? genre;
  final String? status;
  final SeriesSort sort;

  bool get hasFilters => genre != null || status != null || sort != SeriesSort.latest;

  SeriesQuery copyWith({
    String? search,
    String? Function()? genre,
    String? Function()? status,
    SeriesSort? sort,
  }) =>
      SeriesQuery(
        search: search ?? this.search,
        genre: genre != null ? genre() : this.genre,
        status: status != null ? status() : this.status,
        sort: sort ?? this.sort,
      );

  Map<String, dynamic> toQueryParameters({required int page, required int perPage}) {
    final trimmed = search.trim();
    return {
      if (trimmed.isNotEmpty)
        'search': trimmed.length > 100 ? trimmed.substring(0, 100) : trimmed,
      if (genre != null) 'genre': genre,
      if (status != null) 'status': status,
      'sort': sort.name,
      'page': page,
      'per_page': perPage.clamp(1, 100),
    };
  }

  /// Key stabil untuk cache offline.
  String get cacheKey =>
      'q=${search.trim().toLowerCase()}|g=${genre ?? ''}|s=${status ?? ''}|o=${sort.name}';
}
