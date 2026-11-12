// Port Dart dari extension Shinigami milik keiyoushi/extensions-source
// (Apache-2.0): src/id/shinigami (Shinigami.kt, Dto.kt, Filters.kt).

import '../../core/utils/json.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

/// Shinigami: semua data dari API JSON `api.shngm.io` (bukan scraping HTML),
/// jadi tidak terpengaruh perubahan tampilan situs.
///
/// URL disimpan dalam bentuk situs (`/series/<id>`, `/chapter/<id>`) supaya
/// bisa dibuka di browser; ID diambil dari segmen terakhir.
class ShinigamiSource extends HttpSource {
  ShinigamiSource({super.dio});

  @override
  String get id => 'id.shinigami';
  @override
  String get name => 'Shinigami';
  @override
  String get lang => 'id';
  @override
  String get defaultBaseUrl => 'https://11.shinigami.asia';
  @override
  ContentWarning get contentWarning => ContentWarning.safe;
  @override
  int get requestsPerSecond => 3;

  static const apiUrl = 'https://api.shngm.io';
  static const _pageSize = '30';

  // ---------------------------------------------------------------- daftar

  @override
  Future<MangaPage> popular(int page) =>
      search(page, '', filters: FilterValues.empty.withSingle('sort', 'popularity'));

  @override
  Future<MangaPage> latest(int page) =>
      search(page, '', filters: FilterValues.empty.withSingle('sort', 'latest'));

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    final json = await fetchJson(searchUrl(page, query, filters));
    return parseMangaList(asMap(json));
  }

  /// Parameter sama dengan Filters.kt: sort, sort_order, status,
  /// format (koma), genre_include (koma) + genre_include_mode=and.
  Uri searchUrl(int page, String query, FilterValues filters) {
    final genres = filters.multi('genre');
    final formats = filters.multi('format');
    return Uri.parse('$apiUrl/v1/manga/list').replace(queryParameters: {
      'page': '$page',
      'page_size': _pageSize,
      if (query.trim().isNotEmpty) 'q': query.trim(),
      for (final key in const ['sort', 'sort_order', 'status'])
        if (filters.single(key) case final value?) key: value,
      if (formats.isNotEmpty) 'format': formats.join(','),
      if (genres.isNotEmpty) ...{'genre_include': genres.join(','), 'genre_include_mode': 'and'},
    });
  }

  MangaPage parseMangaList(JsonMap json) {
    final items = <SourceManga>[
      for (final raw in asList(json['data']))
        if (asString(asMap(raw)['manga_id']) case final id? when id.isNotEmpty)
          SourceManga(
            url: '$baseUrl/series/$id',
            title: asString(asMap(raw)['title']) ?? 'Tanpa judul',
            thumbnailUrl: _cover(asMap(raw)),
          ),
    ];
    final meta = asMap(json['meta']);
    final page = asInt(meta['page']) ?? 1;
    final totalPage = asInt(meta['total_page']);
    return MangaPage(items, hasNextPage: totalPage != null && page < totalPage);
  }

  static String? _cover(JsonMap m) {
    for (final key in const ['cover_portrait_url', 'cover_image_url']) {
      final v = asString(m[key]);
      if (v != null && v.trim().isNotEmpty) return v;
    }
    return null;
  }

  // ---------------------------------------------------------------- detail

  static String _lastSegment(String url) {
    final segments = Uri.parse(url).pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      throw const SourceException(SourceErrorKind.parse, detail: 'URL Shinigami tidak valid.');
    }
    return segments.last;
  }

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final mangaId = _lastSegment(mangaUrl);
    final results = await Future.wait([
      fetchJson(Uri.parse('$apiUrl/v1/manga/detail/$mangaId')),
      fetchJson(Uri.parse('$apiUrl/v1/chapter/$mangaId/list?page_size=3000')),
    ]);
    return parseDetails(mangaUrl, asMap(asMap(results[0])['data']), asMap(results[1]));
  }

  SourceMangaDetails parseDetails(String mangaUrl, JsonMap data, JsonMap chaptersJson) {
    final taxonomy = asMap(data['taxonomy']);
    List<String> names(String key) => [
          for (final t in asList(taxonomy[key]))
            if (asString(asMap(t)['name']) case final n? when n.isNotEmpty) n,
        ];

    final alt = asString(data['alternative_title']);
    final description = [
      if (asString(data['description']) case final d? when d.trim().isNotEmpty) d.trim(),
      if (alt != null && alt.trim().isNotEmpty) 'Judul alternatif: ${alt.trim()}',
    ].join('\n\n');

    return SourceMangaDetails(
      url: mangaUrl,
      title: asString(data['title']) ?? 'Tanpa judul',
      thumbnailUrl: _cover(data),
      author: names('Author').join(', ').ifEmpty,
      artist: names('Artist').join(', ').ifEmpty,
      description: description.isEmpty ? null : description,
      genres: [...names('Genre'), ...names('Format')],
      status: switch (asInt(data['status'])) {
        1 => SourceMangaStatus.ongoing,
        2 => SourceMangaStatus.completed,
        3 => SourceMangaStatus.hiatus,
        _ => SourceMangaStatus.unknown,
      },
      chapters: [
        for (final raw in asList(chaptersJson['data']))
          if (asString(asMap(raw)['chapter_id']) case final cid? when cid.isNotEmpty)
            _chapter(asMap(raw), cid),
      ],
    );
  }

  SourceChapter _chapter(JsonMap c, String chapterId) {
    final number = asDouble(c['chapter_number']);
    final numberText = number == null
        ? ''
        : (number == number.roundToDouble() ? number.toInt().toString() : number.toString());
    final title = asString(c['chapter_title'])?.trim() ?? '';
    return SourceChapter(
      url: '$baseUrl/chapter/$chapterId',
      name: 'Chapter $numberText $title'.trim(),
      number: number,
      uploadedAt: DateTime.tryParse(asString(c['release_date']) ?? '')?.toLocal(),
    );
  }

  // ------------------------------------------------------------- halaman

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final json = asMap(await fetchJson(Uri.parse('$apiUrl/v1/chapter/detail/${_lastSegment(chapter.url)}')));
    final data = asMap(json['data']);
    final base = asString(data['base_url']) ?? '';
    final ch = asMap(data['chapter']);
    final path = asString(ch['path']) ?? '';
    final pages = [for (final f in asStringList(ch['data'])) '$base$path$f'];
    if (pages.isEmpty) {
      throw const SourceException(SourceErrorKind.parse, detail: 'Bab ini belum punya gambar.');
    }
    return pages;
  }

  // -------------------------------------------------------------- filter

  @override
  Future<List<FilterDef>> filters() async => const [
        SelectFilterDef('sort', 'Urutkan', [
          FilterOption('Default', ''),
          FilterOption('Terbaru', 'latest'),
          FilterOption('Populer', 'popularity'),
          FilterOption('Rating', 'rating'),
        ]),
        SelectFilterDef('sort_order', 'Arah urutan', [
          FilterOption('Menurun', ''),
          FilterOption('Menaik', 'asc'),
        ]),
        SelectFilterDef('status', 'Status', [
          FilterOption('Semua', ''),
          FilterOption('Berjalan', 'ongoing'),
          FilterOption('Tamat', 'completed'),
          FilterOption('Hiatus', 'hiatus'),
        ]),
        MultiSelectFilterDef('format', 'Format', [
          FilterOption('Manga', 'manga'),
          FilterOption('Manhwa', 'manhwa'),
          FilterOption('Manhua', 'manhua'),
        ]),
        MultiSelectFilterDef('genre', 'Genre', _genres),
      ];

  static const _genres = [
    FilterOption('Action', 'action'),
    FilterOption('Adventure', 'adventure'),
    FilterOption('Comedy', 'comedy'),
    FilterOption('Cooking', 'cooking'),
    FilterOption('Crime', 'crime'),
    FilterOption('Demon', 'demon'),
    FilterOption('Drama', 'drama'),
    FilterOption('Fantasy', 'fantasy'),
    FilterOption('Game', 'game'),
    FilterOption('Harem', 'harem'),
    FilterOption('Historical', 'historical'),
    FilterOption('Horror', 'horror'),
    FilterOption('Isekai', 'isekai'),
    FilterOption('Magic', 'magic'),
    FilterOption('Martial Arts', 'martial-arts'),
    FilterOption('Mecha', 'mecha'),
    FilterOption('Medical', 'medical'),
    FilterOption('Murim', 'murim'),
    FilterOption('Mystery', 'mystery'),
    FilterOption('Psychological', 'psychological'),
    FilterOption('Regression', 'regression'),
    FilterOption('Revenge', 'revenge'),
    FilterOption('Romance', 'romance'),
    FilterOption('School Life', 'school-life'),
    FilterOption('Sci-fi', 'sci-fi'),
    FilterOption('Seinen', 'seinen'),
    FilterOption('Shoujo', 'shoujo'),
    FilterOption('Shounen', 'shounen'),
    FilterOption('Slice of Life', 'slice-of-life'),
    FilterOption('Sports', 'sports'),
    FilterOption('Supernatural', 'supernatural'),
    FilterOption('Thriller', 'thriller'),
    FilterOption('Tragedy', 'tragedy'),
    FilterOption('Wuxia', 'wuxia'),
  ];
}

extension on String {
  String? get ifEmpty => isEmpty ? null : this;
}
