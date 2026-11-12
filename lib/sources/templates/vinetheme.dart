// Port Dart dari template VineTheme milik keiyoushi/extensions-source
// (Apache-2.0): lib-multisrc/vinetheme.
//
// Daftar & pencarian lewat API JSON `/api/series`. Detail, daftar bab, dan
// gambar halaman diambil dari payload Next.js RSC (request dengan header
// `rsc: 1`), yang memuat objek JSON yang sama dengan yang dirender halaman.

import 'dart:convert';

import 'package:html/parser.dart' as html_parser;

import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

/// Semua objek JSON di payload RSC Next.js, dicari secara rekursif sampai
/// [test] cocok. Baris payload berbentuk `<id hex>:<json>`; baris lain
/// (teks, modul) diabaikan.
JsonMap? findInNextRsc(String payload, bool Function(JsonMap node) test) {
  // Id boleh kosong: baris petunjuk seperti `:HL[...]` juga awal baris baru.
  final starts = RegExp(r'(?:^|\n)([0-9a-f]*):').allMatches(payload).toList();
  for (var i = 0; i < starts.length; i++) {
    final end = i + 1 < starts.length ? starts[i + 1].start : payload.length;
    final row = payload.substring(starts[i].end, end).trim();
    if (row.isEmpty || (row[0] != '[' && row[0] != '{')) continue;
    Object? json;
    try {
      json = jsonDecode(row);
    } catch (_) {
      // Baris berikutnya tidak berbentuk `<id>:`; coba sampai akhir baris.
      final firstLine = row.split('\n').first;
      try {
        json = jsonDecode(firstLine);
      } catch (_) {
        continue;
      }
    }
    final found = _walk(json, test);
    if (found != null) return found;
  }
  return null;
}

JsonMap? _walk(Object? node, bool Function(JsonMap node) test) {
  if (node is Map) {
    final map = asMap(node);
    if (test(map)) return map;
    for (final child in map.values) {
      final found = _walk(child, test);
      if (found != null) return found;
    }
  } else if (node is List) {
    for (final child in node) {
      final found = _walk(child, test);
      if (found != null) return found;
    }
  }
  return null;
}

/// Nilai khusus React Flight: `$D<iso>` untuk tanggal, `$$` untuk `$` literal.
String? _flightString(Object? value) {
  final s = asString(value);
  if (s == null || s == r'$undefined') return null;
  if (s.startsWith(r'$D')) return s.substring(2);
  if (s.startsWith(r'$$')) return s.substring(1);
  return s;
}

class VineThemeSource extends HttpSource {
  VineThemeSource({
    required this.id,
    required this.name,
    required String baseUrl,
    required this.lang,
    this.contentWarning = ContentWarning.safe,
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

  /// Batas halaman daftar bab yang diambil (100 bab per halaman).
  static const _maxChapterPages = 30;

  static const _rscHeaders = {'rsc': '1', 'Accept': '*/*'};

  // =========================== Daftar ===========================

  @override
  Future<MangaPage> popular(int page) => _list(page, sort: 'popular');

  @override
  Future<MangaPage> latest(int page) => _list(page, sort: 'updated');

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) => _list(
        page,
        query: query,
        sort: filters.single('sort'),
        params: {
          for (final key in const ['genre', 'type', 'status', 'origin'])
            if (filters.multi(key).isNotEmpty) key: filters.multi(key).join(','),
        },
      );

  Future<MangaPage> _list(int page, {String? query, String? sort, Map<String, String> params = const {}}) async {
    final url = Uri.parse('$baseUrl/api/series').replace(queryParameters: {
      'limit': '24',
      'contentMode': 'comics',
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (sort != null) 'sort': sort,
      ...params,
      'page': '$page',
    });
    final json = asMap(await fetchJson(url));
    return parseList(json);
  }

  MangaPage parseList(JsonMap json) => MangaPage(
        [
          for (final item in asList(json['data']))
            if (toManga(asMap(item)) case final manga?) manga,
        ],
        hasNextPage: asBool(asMap(json['meta'])['hasMore']),
      );

  String? _abs(Object? path) => _flightString(path) == null ? null : absUrl(baseUri, _flightString(path));

  static String _slug(JsonMap m) =>
      [asString(m['urlSlug']), asString(m['slug'])].firstWhere((s) => s != null && s.isNotEmpty, orElse: () => '')!;

  SourceManga? toManga(JsonMap m) {
    final slug = _slug(m);
    final title = clean(asString(m['title']));
    if (slug.isEmpty || title.isEmpty) return null;
    return SourceManga(url: '$baseUrl/series/comic/$slug', title: title, thumbnailUrl: _abs(m['coverImage']));
  }

  // =========================== Filter ===========================

  @override
  Future<List<FilterDef>> filters() async {
    final genres = await _genres().catchError((Object _) => const <FilterOption>[]);
    return [
      const SelectFilterDef('sort', 'Sort', [
        FilterOption('Recently Updated', 'updated'),
        FilterOption('Most Bookmarked', 'popular'),
        FilterOption('Most Viewed', 'views'),
        FilterOption('Longest', 'longest'),
        FilterOption('Trending', 'trending'),
        FilterOption('Top Rated', 'rating'),
        FilterOption('Newest', 'newest'),
      ]),
      if (genres.isNotEmpty) MultiSelectFilterDef('genre', 'Genres', genres),
      const MultiSelectFilterDef('type', 'Type', [
        FilterOption('Manhwa', 'Manhwa'),
        FilterOption('Manhua', 'Manhua'),
        FilterOption('Manga', 'Manga'),
        FilterOption('Webtoon', 'Webtoon'),
      ]),
      const MultiSelectFilterDef('status', 'Status', [
        FilterOption('Ongoing', 'Ongoing'),
        FilterOption('Completed', 'Completed'),
        FilterOption('Hiatus', 'Hiatus'),
        FilterOption('Dropped', 'Dropped'),
        FilterOption('Discontinued', 'Discontinued'),
        FilterOption('Upcoming', 'Upcoming'),
      ]),
      const MultiSelectFilterDef('origin', 'Origin', [
        FilterOption('Korean', 'KOREAN'),
        FilterOption('Japanese', 'JAPANESE'),
        FilterOption('Chinese', 'CHINESE'),
        FilterOption('Other', 'OTHER'),
      ]),
    ];
  }

  Future<List<FilterOption>> _genres() async {
    final payload = await fetchText(Uri.parse('$baseUrl/series'), headers: _rscHeaders);
    final data = findInNextRsc(payload, (m) => m.containsKey('tagTotal'));
    return [
      for (final g in asList(data?['genres']))
        if (asString(asMap(g)['slug']) case final slug? when asInt(asMap(g)['count']) != 0)
          FilterOption(clean(asString(asMap(g)['name']) ?? slug), slug),
    ];
  }

  // =========================== Detail ===========================

  static bool _isDetail(JsonMap m) => m.containsKey('series') && m.containsKey('chapters');

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final url = Uri.parse(mangaUrl);
    Uri pageUrl(int page) => url.replace(queryParameters: {'sort': 'desc', if (page > 1) 'page': '$page'});
    final detail = findInNextRsc(await fetchText(pageUrl(1), headers: _rscHeaders), _isDetail);
    if (detail == null) throw const SourceException(SourceErrorKind.parse, detail: 'Data seri tidak ditemukan.');

    final rawChapters = [...asList(detail['chapters'])];
    final totalPages = (asInt(detail['totalPages']) ?? 1).clamp(1, _maxChapterPages);
    if (totalPages > 1) {
      final rest = await Future.wait([
        for (var page = 2; page <= totalPages; page++)
          fetchText(pageUrl(page), headers: _rscHeaders).then((p) => asList(findInNextRsc(p, _isDetail)?['chapters'])),
      ]);
      for (final chunk in rest) {
        rawChapters.addAll(chunk);
      }
    }
    return parseDetails(asMap(detail['series']), rawChapters, url);
  }

  static String _number(num n) => n == n.truncate() ? '${n.toInt()}' : '$n';

  static SourceMangaStatus _status(String? raw) => switch (raw) {
        'ONGOING' || 'UPCOMING' => SourceMangaStatus.ongoing,
        'COMPLETED' => SourceMangaStatus.completed,
        'HIATUS' => SourceMangaStatus.hiatus,
        'DROPPED' || 'CANCELLED' || 'DISCONTINUED' => SourceMangaStatus.cancelled,
        _ => SourceMangaStatus.unknown,
      };

  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  static String? _htmlToText(String? html) {
    if (html == null || html.trim().isEmpty) return null;
    final withBreaks = html.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n').replaceAll(
          RegExp(r'</p>', caseSensitive: false),
          '\n\n',
        );
    final text = html_parser.parseFragment(withBreaks).text ?? '';
    return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  SourceMangaDetails parseDetails(JsonMap series, List<Object?> rawChapters, Uri mangaUrl) {
    final slug = _slug(series).isNotEmpty ? _slug(series) : mangaUrl.pathSegments.last;
    final title = clean(asString(series['title']));
    final type = asString(series['type']);
    final origin = asString(series['origin']);
    String? genreName(Object? g) => asString(asMap(g)['name']) ?? asString(asMap(asMap(g)['genre'])['slug']);
    final genres = <String>{
      if (type != null) _capitalize(type),
      if (origin != null) _capitalize(origin),
      if (series['isMature'] == true) 'Mature',
      for (final g in [...asList(series['genres']), ...asList(series['tags'])])
        if (genreName(g) case final name?) clean(name),
    }.toList();

    final altTitles = <String>{
      for (final t in [series['originalTitle'], ...asList(series['aliases'])])
        if (clean(asString(t)).isNotEmpty && clean(asString(t)).toLowerCase() != title.toLowerCase()) clean(asString(t)),
    };
    final description = [
      if (_htmlToText(asString(series['description'])) case final d? when d.isNotEmpty) d,
      if (altTitles.isNotEmpty) 'Alternative titles:\n${altTitles.map((t) => '- $t').join('\n')}',
    ].join('\n\n');

    final seen = <String>{};
    final chapters = <(double, SourceChapter)>[];
    for (final raw in rawChapters) {
      final c = asMap(raw);
      // Bab terkunci (butuh koin) disembunyikan, seperti setelan bawaan Kotlin.
      if (c['isLocked'] == true) continue;
      final number = asDouble(c['number']);
      if (number == null) continue;
      final numberText = _number(number);
      if (!seen.add(numberText)) continue;
      final chapterTitle = clean(asString(c['title']));
      final name =
          chapterTitle.isEmpty || chapterTitle == numberText ? 'Chapter $numberText' : chapterTitle;
      chapters.add((
        number,
        SourceChapter(
          url: '$baseUrl/series/comic/$slug/chapter/$numberText',
          name: name,
          number: number,
          uploadedAt: DateTime.tryParse(_flightString(c['publishedAt']) ?? '')?.toLocal(),
        ),
      ));
    }
    chapters.sort((a, b) => b.$1.compareTo(a.$1));

    return SourceMangaDetails(
      url: '$baseUrl/series/comic/$slug',
      title: title,
      thumbnailUrl: _abs(series['coverImage']),
      author: nonPlaceholder(asString(asMap(series['team'])['name'])),
      description: description.isEmpty ? null : description,
      genres: genres,
      status: _status(asString(series['status'])),
      chapters: [for (final c in chapters) c.$2],
    );
  }

  // =========================== Halaman ===========================

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final payload = await fetchText(Uri.parse(chapter.url), headers: _rscHeaders);
    return parsePages(payload);
  }

  List<String> parsePages(String payload) {
    final data = findInNextRsc(payload, (m) => m['chapter'] is Map && asMap(m['chapter']).containsKey('pages'));
    if (data == null) throw const SourceException(SourceErrorKind.parse, detail: 'Gambar bab tidak ditemukan.');
    final pages = [
      for (final p in asList(asMap(data['chapter'])['pages']))
        if (_abs(asMap(p)['imageUrl']) case final url?) url,
    ];
    if (pages.isEmpty) {
      throw const SourceException(SourceErrorKind.parse, detail: 'Bab terkunci atau tidak berisi gambar.');
    }
    return pages;
  }
}
