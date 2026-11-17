// Port Dart dari template MangaTaro milik keiyoushi/extensions-source
// (Apache-2.0): lib-multisrc/mangataro.
//
// WordPress + API khusus: `wp-json/manga/v1/load` (daftar, POST), `auth/search`
// (pencarian cepat, POST), `wp-json/wp/v2/manga/<id>` (detail), `auth/manga-chapters`
// (bab, butuh token MD5 berbasis jam server) dan `auth/chapter-content` (gambar).
// Varian grup (library per grup scanlation) belum didukung.

import 'dart:convert';
import 'dart:io' show HttpDate;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:pointycastle/export.dart';

import '../../core/i18n/strings.dart';
import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class MangaTaroSource extends HttpSource {
  MangaTaroSource({
    required this.id,
    required this.name,
    required String baseUrl,
    required this.lang,
    this.contentWarning = ContentWarning.safe,
    this.vals = const {},
    this.tags = const [],
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

  final JsonMap vals;

  /// Tag per situs: (label, id).
  final List<(String, String)> tags;

  /// >1: daftar menggabungkan beberapa halaman API (situs yang menyelipkan entri kosong).
  int get aggregatePages => asInt(vals['aggregatePages']) ?? 1;

  static const _pageSize = 24;

  // =========================== Daftar ===========================

  @override
  Future<MangaPage> popular(int page) => _browse(page, '', sort: 'popular_desc');

  @override
  Future<MangaPage> latest(int page) => _browse(page, '', sort: 'post_desc');

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) {
    final q = query.trim();
    if (q.isNotEmpty && filters.isEmpty && aggregatePages == 1) return _quickSearch(q);
    final sort = '${filters.single('sort') ?? 'post'}_${filters.single('order') ?? 'desc'}';
    return _browse(
      page,
      q,
      sort: sort,
      years: filters.single('year') == null ? const [] : [int.parse(filters.single('year')!)],
      types: [if (filters.single('type') case final t?) t],
      statuses: [if (filters.single('status') case final s?) s],
      genres: filters.multi('tags').map(int.parse).toList(),
      matchAll: filters.single('match') == 'all',
    );
  }

  Future<MangaPage> _quickSearch(String query) async {
    final json = asMap(await postJson(Uri.parse('$baseUrl/auth/search'), {'query': query, 'limit': 25}));
    return parseQuickSearch(json);
  }

  MangaPage parseQuickSearch(JsonMap json) {
    final items = <SourceManga>[];
    for (final raw in asList(json['results'])) {
      final r = asMap(raw);
      if (asString(r['type']) == 'Novel') continue;
      final id = asString(r['id']) ?? asInt(r['id'])?.toString();
      final slug = asString(r['slug']);
      final title = _unescape(asString(r['title']) ?? '');
      if (id == null || slug == null || title.isEmpty) continue;
      items.add(SourceManga(url: '$baseUrl/manga/$slug#$id', title: title, thumbnailUrl: asString(r['thumbnail'])));
    }
    return MangaPage(items, hasNextPage: false);
  }

  Future<List<Object?>> _fetchBrowsePage(
    int page,
    String query, {
    required String sort,
    List<int> years = const [],
    List<String> types = const [],
    List<String> statuses = const [],
    List<int> genres = const [],
    bool matchAll = false,
  }) async {
    final json = await postJson(Uri.parse('$baseUrl/wp-json/manga/v1/load'), {
      'page': page,
      'search': query,
      'years': jsonEncode(years),
      'genres': jsonEncode(genres),
      'types': jsonEncode(types),
      'statuses': jsonEncode(statuses),
      'sort': sort,
      'genreMatchMode': matchAll ? 'all' : 'any',
    });
    return asList(json);
  }

  Future<MangaPage> _browse(
    int page,
    String query, {
    required String sort,
    List<int> years = const [],
    List<String> types = const [],
    List<String> statuses = const [],
    List<int> genres = const [],
    bool matchAll = false,
  }) async {
    final n = aggregatePages;
    final start = (page - 1) * n + 1;
    final items = <SourceManga>[];
    final seen = <String>{};
    var lastSize = 0;
    for (var apiPage = start; apiPage < start + n; apiPage++) {
      final data = await _fetchBrowsePage(apiPage, query,
          sort: sort, years: years, types: types, statuses: statuses, genres: genres, matchAll: matchAll);
      lastSize = data.length;
      for (final m in parseBrowse(data)) {
        if (seen.add(m.url)) items.add(m);
      }
      if (data.length < _pageSize) break;
    }
    return MangaPage(items, hasNextPage: lastSize == _pageSize);
  }

  /// Entri bertipe novel atau tanpa URL (entri bab) dilewati.
  List<SourceManga> parseBrowse(List<Object?> data) {
    final out = <SourceManga>[];
    for (final raw in data) {
      final m = asMap(raw);
      if (asString(m['type']) == 'Novel') continue;
      final url = asString(m['url']) ?? '';
      final id = asString(m['id']) ?? asInt(m['id'])?.toString();
      final title = _unescape(asString(m['title']) ?? '');
      if (url.isEmpty || id == null || title.isEmpty) continue;
      final slug = _slug(url);
      if (slug == null) continue;
      out.add(SourceManga(url: '$baseUrl/manga/$slug#$id', title: title, thumbnailUrl: asString(m['cover'])));
    }
    return out;
  }

  /// `/manga/<slug>` atau `/read/<slug>/<bab>`.
  static String? _slug(String url) {
    final path = Uri.tryParse(url)?.pathSegments.where((s) => s.isNotEmpty).toList() ?? const [];
    if ((path.length == 2 && path[0] == 'manga') || (path.length == 3 && path[0] == 'read')) return path[1];
    return null;
  }

  static String _unescape(String raw) {
    var decoded = raw;
    for (var i = 0; i < 5; i++) {
      final next = html_parser.parseFragment(decoded).text ?? decoded;
      if (next == decoded) break;
      decoded = next;
    }
    return clean(decoded);
  }

  // =========================== Filter ===========================

  @override
  Future<List<FilterDef>> filters() async {
    final year = DateTime.now().year;
    return [
      const SelectFilterDef('sort', 'Sort', [
        FilterOption('Latest Updates', 'post'),
        FilterOption('Release Date', 'release'),
        FilterOption('Title A-Z', 'title'),
        FilterOption('Popular', 'popular'),
      ]),
      const SelectFilterDef('order', 'Direction', [
        FilterOption('Descending', 'desc'),
        FilterOption('Ascending', 'asc'),
      ]),
      const SelectFilterDef('type', 'Type', [
        FilterOption('All', ''),
        FilterOption('Manga', 'Manga'),
        FilterOption('Manhwa', 'Manhwa'),
        FilterOption('Manhua', 'Manhua'),
      ]),
      const SelectFilterDef('status', 'Status', [
        FilterOption('All', ''),
        FilterOption('Completed', 'Completed'),
        FilterOption('Ongoing', 'Ongoing'),
      ]),
      SelectFilterDef('year', 'Year', [
        const FilterOption('All', ''),
        for (var y = year; y >= 1949; y--) FilterOption('$y', '$y'),
      ]),
      if (tags.isNotEmpty) MultiSelectFilterDef('tags', 'Tags', [for (final (l, v) in tags) FilterOption(l, v)]),
      const SelectFilterDef('match', 'Tag Match', [
        FilterOption('Any', 'any'),
        FilterOption('All', 'all'),
      ]),
    ];
  }

  // =========================== Detail ===========================

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final uri = Uri.parse(mangaUrl);
    var mangaId = uri.fragment;
    final slug = uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull;
    if (slug == null) throw SourceException(SourceErrorKind.parse, detail: tr('URL seri tidak dikenali.'));

    // Status hanya ada di halaman seri (API detail tidak punya); id juga dari sana bila hilang.
    var status = SourceMangaStatus.unknown;
    try {
      final page = await fetchHtml(Uri.parse('$baseUrl/manga/$slug'));
      if (mangaId.isEmpty) mangaId = page.document.body?.attributes['data-manga-id'] ?? '';
      for (final el in page.document.querySelectorAll('.capitalize')) {
        final t = clean(el.text).toLowerCase();
        if (t == 'ongoing') status = SourceMangaStatus.ongoing;
        if (t == 'completed') status = SourceMangaStatus.completed;
      }
    } catch (_) {
      // Status dilewati.
    }
    if (mangaId.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Detail seri tidak ditemukan.'));

    final json = asMap(await fetchJson(Uri.parse('$baseUrl/wp-json/wp/v2/manga/$mangaId').replace(query: '_embed')));
    final chapters = await _fetchChapters(mangaId);
    return parseDetails(json, status, chapters, '$baseUrl/manga/$slug#$mangaId');
  }

  static List<String> _terms(JsonMap embedded, String taxonomy) {
    for (final group in asList(embedded['wp:term'])) {
      final list = asList(group);
      if (list.isNotEmpty && asString(asMap(list.first)['taxonomy']) == taxonomy) {
        return [
          for (final t in list)
            if (clean(asString(asMap(t)['name'])) case final n when n.isNotEmpty) n,
        ];
      }
    }
    return const [];
  }

  SourceMangaDetails parseDetails(JsonMap data, SourceMangaStatus status, List<SourceChapter> chapters, String url) {
    final embedded = asMap(data['_embedded']);
    final tagNames = <String>{..._terms(embedded, 'post_tag')};
    final type = asString(data['type']);
    if (type != null && !const ['Manhwa', 'Manhua', 'Manga'].any(tagNames.contains)) tagNames.add(type);
    final media = asList(embedded['wp:featuredmedia']);
    final content = html_parser.parseFragment(asString(asMap(data['content'])['rendered']) ?? '');
    return SourceMangaDetails(
      url: url,
      title: _unescape(asString(asMap(data['title'])['rendered']) ?? ''),
      thumbnailUrl: media.isEmpty ? null : asString(asMap(media.first)['source_url']),
      author: _terms(embedded, 'manga_author').join(', ').nullIfEmpty,
      description: _unescape2(content.text ?? '').nullIfEmpty,
      genres: tagNames.toList(),
      status: status,
      chapters: chapters,
    );
  }

  /// Seperti [_unescape] tapi mempertahankan baris baru.
  static String _unescape2(String raw) => raw.trim();

  // =========================== Bab ===========================

  /// Selisih jam server (ms); token bab hanya diterima dalam ±1 menit dari jam server.
  int _serverOffsetMs = 0;

  static String _md5(String input) {
    final d = MD5Digest().process(Uint8List.fromList(utf8.encode(input)));
    return d.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Uri _chapterUrl(String mangaId, int offset) {
    final now = DateTime.fromMillisecondsSinceEpoch(DateTime.now().millisecondsSinceEpoch + _serverOffsetMs, isUtc: true);
    final seconds = now.millisecondsSinceEpoch ~/ 1000;
    String two(int v) => v.toString().padLeft(2, '0');
    final iso = '${now.year.toString().padLeft(4, '0')}${two(now.month)}${two(now.day)}${two(now.hour)}';
    final token = _md5('${seconds}mng_ch_$iso').substring(0, 16);
    return Uri.parse('$baseUrl/auth/manga-chapters').replace(queryParameters: {
      'manga_id': mangaId,
      'offset': '$offset',
      'limit': '500',
      'order': 'DESC',
      '_t': token,
      '_ts': '$seconds',
    });
  }

  Future<JsonMap> _chapterPage(String mangaId, int offset) async {
    Future<Response<String>> get() => dio.getUri<String>(
          _chapterUrl(mangaId, offset),
          options: Options(headers: {'Accept': 'application/json'}, validateStatus: (_) => true),
        );
    try {
      var res = await get();
      if (res.statusCode == 403) {
        final date = res.headers.value('date');
        if (date == null) throw SourceException(SourceErrorKind.parse, detail: tr('Jam server tidak diketahui.'));
        _serverOffsetMs = HttpDate.parse(date).millisecondsSinceEpoch - DateTime.now().millisecondsSinceEpoch;
        res = await get();
      }
      final code = res.statusCode ?? 0;
      if (code < 200 || code >= 300) {
        throw DioException.badResponse(statusCode: code, requestOptions: res.requestOptions, response: res);
      }
      return asMap(jsonDecode(res.data ?? '{}'));
    } on SourceException {
      rethrow;
    } on FormatException {
      throw SourceException(SourceErrorKind.parse, detail: tr('Respons API bukan JSON.'));
    } catch (error) {
      throw toSourceException(error);
    }
  }

  Future<List<SourceChapter>> _fetchChapters(String mangaId) async {
    final raw = <Object?>[];
    var page = await _chapterPage(mangaId, 0);
    raw.addAll(asList(page['chapters']));
    // Server membatasi 500 bab per respons.
    while (page['has_more'] == true && asList(page['chapters']).isNotEmpty) {
      page = await _chapterPage(mangaId, raw.length);
      raw.addAll(asList(page['chapters']));
    }
    return parseChapters(raw);
  }

  List<SourceChapter> parseChapters(List<Object?> raw, {DateTime? now}) {
    const placeholders = {'', 'N/A', '—'};
    final out = <SourceChapter>[];
    for (final r in raw) {
      final c = asMap(r);
      if ((asString(c['language']) ?? '').toLowerCase() != lang.toLowerCase()) continue;
      final url = asString(c['url']);
      if (url == null || url.isEmpty) continue;
      final number = asString(c['chapter']) ?? '';
      final title = asString(c['title']);
      final group = asString(c['group_name']);
      out.add(SourceChapter(
        url: url,
        name: 'Chapter $number${title == null || placeholders.contains(title) ? '' : ': ${_unescape(title)}'}',
        number: double.tryParse(number),
        scanlator: group == null || placeholders.contains(group) ? null : group,
        uploadedAt: parseLooseDate(asString(c['date']), now: now),
      ));
    }
    return out;
  }

  // =========================== Halaman ===========================

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final segs = Uri.parse(chapter.url).pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.length < 3) throw SourceException(SourceErrorKind.parse, detail: tr('Muat ulang daftar bab.'));
    final chapterId = segs.last.split('-').last;
    final json = asMap(await fetchJson(
        Uri.parse('$baseUrl/auth/chapter-content').replace(queryParameters: {'chapter_id': chapterId})));
    final images = [
      for (final i in asList(json['images']))
        if (asString(i) case final url?) url,
    ];
    if (images.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    return images;
  }
}

extension on String {
  String? get nullIfEmpty => trim().isEmpty ? null : trim();
}
