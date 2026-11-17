// Port Dart dari template MangaK milik keiyoushi/extensions-source
// (Apache-2.0): lib-multisrc/mangak.
//
// Situs Next.js. Daftar & pencarian dari API `https://api.<domain>/titles/search`,
// detail & gambar dari JSON `__NEXT_DATA__` halaman (`initialManga`,
// `initialChapter`), daftar bab dari `/titles/<id>/chapters`.

import 'dart:convert';

import '../../core/i18n/strings.dart';
import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class MangaKSource extends HttpSource {
  MangaKSource({
    required this.id,
    required this.name,
    required String baseUrl,
    required this.lang,
    this.contentWarning = ContentWarning.safe,
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

  String get apiUrl => 'https://api.${baseUri.host}';

  static const _pageLimit = '24';

  // =========================== Daftar ===========================

  @override
  Future<MangaPage> popular(int page) => _query({'sort': 'popular', 'window': 'week', 'page': '$page'});

  @override
  Future<MangaPage> latest(int page) => _query({'sort': 'latest', 'page': '$page'});

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) {
    final q = query.split('').where((c) => RegExp(r'[\p{L}\p{N} ]', unicode: true).hasMatch(c)).join().trim();
    final params = <String, String>{
      'page': '$page',
      if (q.isNotEmpty) 'q': q.length > 50 ? q.substring(0, 50) : q,
    };
    for (final (key, param) in const [
      ('sort', 'sort'),
      ('content_rating', 'content_rating'),
      ('status', 'status'),
      ('type', 'type'),
      ('demographic', 'demographic'),
      ('format', 'format'),
    ]) {
      final v = filters.single(key);
      if (v != null && v.isNotEmpty) params[param] = v;
    }
    final author = filters.single('author');
    if (author != null) params['author'] = author;
    final genres = filters.multi('genres');
    if (genres.isNotEmpty) params['genres'] = genres.join(',');
    return _query(params);
  }

  Future<MangaPage> _query(Map<String, String> params) async {
    final json = asMap(await fetchJson(
      Uri.parse('$apiUrl/titles/search').replace(queryParameters: {...params, 'limit': _pageLimit}),
    ));
    final data = asMap(json['data']);
    return parseList(data);
  }

  MangaPage parseList(JsonMap data) => MangaPage(
        [
          for (final raw in asList(data['items']))
            if (_toManga(asMap(raw)) case final m?) m,
        ],
        hasNextPage: asMap(data['pagination'])['has_next'] == true,
      );

  SourceManga? _toManga(JsonMap item) {
    final url = asString(item['url']);
    final title = clean(asString(item['name']));
    if (url == null || title.isEmpty) return null;
    return SourceManga(url: _abs(url), title: title, thumbnailUrl: asString(item['cover']));
  }

  String _abs(String path) => absUrl(baseUri, path) ?? '$baseUrl$path';

  // =========================== Filter ===========================

  @override
  Future<List<FilterDef>> filters() async {
    final genres = await fetchJson(Uri.parse('$apiUrl/genres'))
        .then((json) => [
              for (final g in asList(asMap(asMap(json)['data'])['items']))
                if (asString(asMap(g)['slug']) case final slug?) FilterOption(clean(asString(asMap(g)['name'])), slug),
            ])
        .catchError((Object _) => const <FilterOption>[]);
    return [
      const SelectFilterDef('sort', 'Sort By', [
        FilterOption('Best Match', ''),
        FilterOption('Most Followed', 'popular'),
        FilterOption('Latest Updated', 'latest'),
        FilterOption('Recently Added', 'newest'),
        FilterOption('Highest Rating', 'rating'),
        FilterOption('Most Viewed: Today', 'views_today'),
        FilterOption('Most Viewed: 7 Days', 'views_7days'),
        FilterOption('Most Viewed: 30 Days', 'views_30days'),
        FilterOption('Most Viewed: All Time', 'views'),
        FilterOption('Most Chapters', 'chapters'),
      ]),
      const SelectFilterDef('content_rating', 'Content Rating', [
        FilterOption('Any', ''),
        FilterOption('Safe', 'safe'),
        FilterOption('Suggestive', 'suggestive'),
        FilterOption('Erotica', 'erotica'),
        FilterOption('Pornographic', 'pornographic'),
      ]),
      const SelectFilterDef('status', 'Status', [
        FilterOption('Any', ''),
        FilterOption('Ongoing', 'ongoing'),
        FilterOption('Completed', 'completed'),
      ]),
      const SelectFilterDef('type', 'Type', [
        FilterOption('Any', ''),
        FilterOption('Manga', 'manga'),
        FilterOption('Manhwa', 'manhwa'),
        FilterOption('Manhua', 'manhua'),
      ]),
      const SelectFilterDef('demographic', 'Demographics', [
        FilterOption('Any', ''),
        FilterOption('Boy (Shounen + Seinen)', 'shounen,seinen'),
        FilterOption('Girl (Shoujo + Josei)', 'shoujo,josei'),
        FilterOption('Shounen', 'shounen'),
        FilterOption('Shoujo', 'shoujo'),
        FilterOption('Seinen', 'seinen'),
        FilterOption('Josei', 'josei'),
      ]),
      const SelectFilterDef('format', 'Format', [
        FilterOption('Any', ''),
        FilterOption('Oneshot', 'oneshot'),
        FilterOption('Adaptation', 'adaptation'),
      ]),
      if (genres.isNotEmpty) MultiSelectFilterDef('genres', 'Genres', genres),
    ];
  }

  // =========================== Detail ===========================

  /// Isi JSON `<script id="__NEXT_DATA__">` → `props.pageProps`.
  static JsonMap pageProps(String html) {
    final m = RegExp(r'<script id="__NEXT_DATA__"[^>]*>([\s\S]*?)</script>').firstMatch(html);
    if (m == null) throw SourceException(SourceErrorKind.parse, detail: tr('Data halaman tidak ditemukan.'));
    try {
      return asMap(asMap(asMap(jsonDecode(m[1]!))['props'])['pageProps']);
    } on FormatException {
      throw SourceException(SourceErrorKind.parse, detail: tr('Data halaman tidak terbaca.'));
    }
  }

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    final manga = asMap(pageProps(res.body)['initialManga']);
    final mangaId = asString(manga['id']);
    if (mangaId == null) throw SourceException(SourceErrorKind.parse, detail: tr('Detail seri tidak ditemukan.'));
    final chaptersJson = asMap(await fetchJson(Uri.parse('$apiUrl/titles/$mangaId/chapters')
        .replace(queryParameters: {'cv': '${DateTime.now().millisecondsSinceEpoch}'})));
    return parseDetails(manga, asList(asMap(chaptersJson['data'])['chapters']), mangaUrl);
  }

  static String _names(Object? list) => [
        for (final e in asList(list))
          if (clean(asString(asMap(e)['name'])) case final n when n.isNotEmpty) n,
      ].join(', ');

  SourceMangaDetails parseDetails(JsonMap m, List<Object?> rawChapters, String mangaUrl) {
    final type = asString(asMap(m['type'])['name']);
    final genres = <String>{
      if (type != null && type != 'other') '${type[0].toUpperCase()}${type.substring(1)}',
      for (final key in const ['demographics', 'formats', 'genres', 'tags'])
        for (final e in asList(m[key]))
          if (clean(asString(asMap(e)['name'])) case final n when n.isNotEmpty) n,
    };
    final seen = <String>{};
    final unique = [
      for (final g in genres)
        if (seen.add(g.toLowerCase())) g,
    ];
    final alt = [
      for (final a in asList(m['altNames']))
        if (clean(asString(asMap(a)['name'])) case final n when n.isNotEmpty && n != asString(m['name'])) n,
    ];
    final summary = clean(asString(m['summary']));
    final description = [
      if (summary.isNotEmpty) asString(m['summary'])!.trim(),
      if (alt.isNotEmpty) 'Alternative Names: ${alt.join(', ')}',
    ].join('\n\n');

    final chapters = <SourceChapter>[];
    for (final raw in rawChapters) {
      final c = asMap(raw);
      final url = asString(c['url']);
      final name = clean(asString(c['name']));
      if (url == null || name.isEmpty) continue;
      chapters.add(SourceChapter(
        url: _abs(url),
        name: name,
        number: parseChapterNumber(name),
        uploadedAt: DateTime.tryParse(asString(c['updated_at']) ?? '')?.toLocal(),
      ));
    }

    return SourceMangaDetails(
      url: mangaUrl,
      title: clean(asString(m['name'])),
      thumbnailUrl: asString(m['cover']),
      author: nonPlaceholder(_names(m['authors'])),
      artist: nonPlaceholder(_names(m['artists'])),
      description: description.isEmpty ? null : description,
      genres: unique,
      status: switch (asString(m['status'])?.toLowerCase()) {
        'ongoing' => SourceMangaStatus.ongoing,
        'completed' => SourceMangaStatus.completed,
        'cancelled' => SourceMangaStatus.cancelled,
        'hiatus' => SourceMangaStatus.hiatus,
        _ => SourceMangaStatus.unknown,
      },
      chapters: chapters,
    );
  }

  // =========================== Halaman ===========================

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    return parsePages(res.body);
  }

  List<String> parsePages(String html) {
    final images = asList(asMap(pageProps(html)['initialChapter'])['images']);
    if (images.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    return [
      for (final i in images)
        if (asString(i) case final url?) url,
    ];
  }
}
