// Port Dart dari template MangAdventure milik keiyoushi/extensions-source
// (Apache-2.0): lib-multisrc/mangadventure.
//
// API JSON `<situs>/api/v2`: `series` (daftar, pencarian, detail), `series/<slug>/chapters`
// dan `chapters/<id>/pages`. Filter penulis/ilustrator (teks) tidak didukung.

import '../../core/i18n/strings.dart';
import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class MangAdventureSource extends HttpSource {
  MangAdventureSource({
    required this.id,
    required this.name,
    required String baseUrl,
    required this.lang,
    this.contentWarning = ContentWarning.safe,
    this.categories = defaultCategories,
    super.dio,
  }) : defaultBaseUrl = baseUrl;

  @override
  final String id;
  @override
  final String name;
  @override
  final String defaultBaseUrl;
  @override
  final String lang;
  @override
  final ContentWarning contentWarning;

  /// Kategori yang dikenal situs.
  final List<String> categories;

  static const defaultCategories = [
    '4-Koma', 'Action', 'Adventure', 'Comedy', 'Doujinshi', 'Drama', 'Ecchi', 'Fantasy', 'Gender Bender', 'Harem',
    'Hentai', 'Historical', 'Horror', 'Josei', 'Martial Arts', 'Mecha', 'Mystery', 'Psychological', 'Romance',
    'School Life', 'Sci-Fi', 'Seinen', 'Shoujo', 'Shoujo Ai', 'Shounen', 'Shounen Ai', 'Slice of Life', 'Smut',
    'Sports', 'Supernatural', 'Tragedy', 'Yaoi', 'Yuri',
  ];

  String get apiUrl => '$baseUrl/api/v2';

  @override
  Map<String, String> get extraHeaders => const {'Accept': 'application/json'};

  // =========================== Daftar ===========================

  @override
  Future<MangaPage> popular(int page) => _series({'page': '$page', 'sort': '-views'});

  @override
  Future<MangaPage> latest(int page) => _series({'page': '$page', 'sort': '-latest_upload'});

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) {
    final cats = filters.multi('categories');
    return _series({
      'page': '$page',
      'title': query.trim(),
      if (filters.single('sort') case final s?) 'sort': s,
      if (filters.single('status') case final s?) 'status': s,
      if (cats.isNotEmpty) 'categories': cats.join(','),
    });
  }

  Future<MangaPage> _series(Map<String, String> params) async {
    final json = asMap(await fetchJson(Uri.parse('$apiUrl/series').replace(queryParameters: params)));
    return parseList(json);
  }

  MangaPage parseList(JsonMap json) => MangaPage(
        [
          for (final raw in asList(json['results']))
            if (_toManga(asMap(raw)) case final m?) m,
        ],
        hasNextPage: json['last'] != true,
      );

  SourceManga? _toManga(JsonMap s) {
    final slug = asString(s['slug']);
    final title = clean(asString(s['title']));
    if (slug == null || title.isEmpty) return null;
    return SourceManga(url: '$baseUrl/reader/$slug/', title: title, thumbnailUrl: asString(s['cover']));
  }

  // =========================== Filter ===========================

  @override
  Future<List<FilterDef>> filters() async => [
        const SelectFilterDef('sort', 'Sort', [
          FilterOption('Views', '-views'),
          FilterOption('Latest upload', '-latest_upload'),
          FilterOption('Chapter count', '-chapter_count'),
          FilterOption('Title', 'title'),
        ]),
        const SelectFilterDef('status', 'Status', [
          FilterOption('Any', ''),
          FilterOption('Completed', 'Completed'),
          FilterOption('Ongoing', 'Ongoing'),
          FilterOption('Hiatus', 'Hiatus'),
          FilterOption('Cancelled', 'Cancelled'),
        ]),
        if (categories.isNotEmpty)
          MultiSelectFilterDef('categories', 'Categories', [for (final c in categories) FilterOption(c, c)]),
      ];

  // =========================== Detail ===========================

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final slug = Uri.parse(mangaUrl).pathSegments.where((s) => s.isNotEmpty).lastOrNull;
    if (slug == null) throw SourceException(SourceErrorKind.parse, detail: tr('URL seri tidak dikenali.'));
    final series = asMap(await fetchJson(Uri.parse('$apiUrl/series/$slug')));
    final chapters = asMap(await fetchJson(
        Uri.parse('$apiUrl/series/$slug/chapters').replace(queryParameters: {'date_format': 'timestamp'})));
    return parseDetails(series, asList(chapters['results']));
  }

  static List<String> _strings(Object? list) => [
        for (final e in asList(list))
          if (asString(e) case final s? when s.trim().isNotEmpty) s,
      ];

  SourceMangaDetails parseDetails(JsonMap s, List<Object?> rawChapters) {
    final slug = asString(s['slug']) ?? '';
    final aliases = _strings(s['aliases']);
    final description = [
      if ((asString(s['description']) ?? '').trim().isNotEmpty) asString(s['description'])!.trim(),
      if (aliases.isNotEmpty) 'Alternative titles:\n${aliases.join('\n')}',
    ].join('\n\n');
    final chapters = <SourceChapter>[];
    for (final raw in rawChapters) {
      final c = asMap(raw);
      final id = asInt(c['id']);
      final path = asString(c['url']);
      if (id == null || path == null) continue;
      final title = clean(asString(c['full_title']));
      final groups = _strings(c['groups']);
      final ms = int.tryParse(asString(c['published']) ?? '');
      chapters.add(SourceChapter(
        url: '$baseUrl$path#$id',
        name: '${title.isEmpty ? 'Chapter ${c['number']}' : title}${c['final'] == true ? ' [END]' : ''}',
        number: asDouble(c['number']),
        scanlator: groups.isEmpty ? null : groups.join(', '),
        uploadedAt: ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms),
      ));
    }
    return SourceMangaDetails(
      url: '$baseUrl/reader/$slug/',
      title: clean(asString(s['title'])),
      thumbnailUrl: asString(s['cover']),
      author: _strings(s['authors']).join(', ').isEmpty ? null : _strings(s['authors']).join(', '),
      artist: _strings(s['artists']).join(', ').isEmpty ? null : _strings(s['artists']).join(', '),
      description: description.isEmpty ? null : description,
      genres: _strings(s['categories']),
      status: s['licensed'] == true
          ? SourceMangaStatus.cancelled
          : switch (asString(s['status'])) {
              'completed' => SourceMangaStatus.completed,
              'ongoing' => SourceMangaStatus.ongoing,
              'hiatus' => SourceMangaStatus.hiatus,
              'canceled' => SourceMangaStatus.cancelled,
              _ => SourceMangaStatus.unknown,
            },
      chapters: chapters,
    );
  }

  // =========================== Halaman ===========================

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final id = int.tryParse(Uri.parse(chapter.url).fragment);
    if (id == null) throw SourceException(SourceErrorKind.parse, detail: tr('Muat ulang daftar bab.'));
    final json = asMap(await fetchJson(
        Uri.parse('$apiUrl/chapters/$id/pages').replace(queryParameters: {'track': 'true'})));
    return parsePages(json);
  }

  List<String> parsePages(JsonMap json) {
    final pages = [
      for (final p in asList(json['results']))
        if (asString(asMap(p)['image']) case final img?) (asInt(asMap(p)['number']) ?? 0, img),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    if (pages.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    return [for (final (_, img) in pages) img];
  }
}
