// Port Dart dari template Liliana milik keiyoushi/extensions-source
// (Apache-2.0): lib-multisrc/liliana.
//
// Daftar `/ranking/week/N`, terbaru `/all-manga/N/?sort=last_update`, pencarian
// `/search?keyword=` atau `/filter?...`, detail & bab dalam satu halaman, gambar dari
// AJAX `/ajax/image/list/chap/<id>` (JSON berisi HTML).

import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../core/i18n/strings.dart';
import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class LilianaSource extends HttpSource {
  LilianaSource({
    required this.id,
    required this.name,
    required String baseUrl,
    required this.lang,
    this.contentWarning = ContentWarning.safe,
    this.vals = const {},
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

  bool get usesPostSearch => vals['usesPostSearch'] == true;

  // =========================== Daftar ===========================

  @override
  Future<MangaPage> popular(int page) => _list('$baseUrl/ranking/week/$page');

  @override
  Future<MangaPage> latest(int page) => _list('$baseUrl/all-manga/$page/?sort=last_update&status=0');

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    final q = query.trim();
    if (q.isNotEmpty && usesPostSearch) return _postSearch(q);
    if (q.isNotEmpty) {
      return _list(Uri.parse('$baseUrl/search/$page/').replace(queryParameters: {'keyword': q}).toString());
    }
    final params = <String, String>{
      if (filters.multi('genres').isNotEmpty) 'genres': filters.multi('genres').join(','),
      for (final key in const ['chapter_count', 'status', 'sex', 'sort'])
        if (filters.single(key) case final v?) key: v,
    };
    return _list(Uri.parse('$baseUrl/filter/$page/').replace(queryParameters: params.isEmpty ? null : params).toString());
  }

  Future<MangaPage> _postSearch(String query) async {
    final res = await postHtml(
      Uri.parse('$baseUrl/ajax/search'),
      {'search': query},
      headers: {'Accept': 'application/json, text/javascript, */*; q=0.01', 'X-Requested-With': 'XMLHttpRequest'},
    );
    return parsePostSearch(res.body);
  }

  MangaPage parsePostSearch(String body) {
    final json = asMap(_decode(body));
    final items = <SourceManga>[];
    for (final raw in asList(json['list'])) {
      final m = asMap(raw);
      final url = absUrl(baseUri, asString(m['url']));
      final title = clean(asString(m['name']));
      if (url == null || title.isEmpty) continue;
      items.add(SourceManga(url: url, title: title, thumbnailUrl: '$baseUrl${asString(m['cover']) ?? ''}'));
    }
    return MangaPage(items, hasNextPage: false);
  }

  static Object? _decode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      throw SourceException(SourceErrorKind.parse, detail: tr('Respons API bukan JSON.'));
    }
  }

  Future<MangaPage> _list(String url) async {
    final res = await fetchHtml(Uri.parse(url));
    return parseList(res.document, res.url);
  }

  MangaPage parseList(Document doc, Uri base) {
    final items = <SourceManga>[];
    for (final el in doc.querySelectorAll('div#main div.grid > div')) {
      final a = el.querySelector('.text-center a');
      final url = absUrl(base, a?.attributes['href']);
      final title = clean(a?.text);
      if (url == null || title.isEmpty) continue;
      items.add(SourceManga(url: url, title: title, thumbnailUrl: _img(el.querySelector('img'), base)));
    }
    return MangaPage(items, hasNextPage: doc.querySelector('.blog-pager > span.pagecurrent + span') != null);
  }

  static String? _img(Element? img, Uri base) {
    if (img == null) return null;
    for (final attr in const ['data-lazy-src', 'data-src', 'src']) {
      final v = img.attributes[attr];
      if (v != null && v.trim().isNotEmpty) return absUrl(base, v.trim());
    }
    return null;
  }

  // =========================== Filter ===========================

  @override
  Future<List<FilterDef>> filters() async {
    try {
      final res = await fetchHtml(Uri.parse('$baseUrl/filter'));
      final doc = res.document;
      List<FilterOption> options(String id) => [
            for (final o in doc.querySelectorAll('#$id > option')) FilterOption(clean(o.text), o.attributes['value'] ?? ''),
          ];
      String label(String cls, String fallback) => clean(doc.querySelector('.select-div > label.$cls')?.text).ifEmpty(fallback);
      final genres = [
        for (final g in doc.querySelectorAll('div.advanced-genres > div > .advance-item'))
          if (g.querySelector('span')?.attributes['data-genre'] case final id?) FilterOption(clean(g.text), id),
      ];
      return [
        if (genres.isNotEmpty)
          MultiSelectFilterDef('genres', clean(doc.querySelector('div.advanced-genres > h3')?.text).ifEmpty('Genres'), genres),
        for (final (key, id, cls, fallback) in const [
          ('chapter_count', 'select-count', 'select-count', 'Chapters'),
          ('status', 'select-status', 'select-status', 'Status'),
          ('sex', 'select-gender', 'select-gender', 'Gender'),
          ('sort', 'select-sort', 'select-sort', 'Sort'),
        ])
          if (options(id).isNotEmpty) SelectFilterDef(key, label(cls, fallback), options(id)),
      ];
    } catch (_) {
      return const [];
    }
  }

  // =========================== Detail ===========================

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    return parseDetails(res.document, res.url);
  }

  static SourceMangaStatus _status(String? raw) => switch ((raw ?? '').toLowerCase()) {
        'ongoing' || 'đang tiến hành' || '進行中' => SourceMangaStatus.ongoing,
        'completed' || 'hoàn thành' || '完了' => SourceMangaStatus.completed,
        'on-hold' || 'tạm ngưng' || '保留' => SourceMangaStatus.hiatus,
        'canceled' || 'đã huỷ' || 'キャンセル' => SourceMangaStatus.cancelled,
        _ => SourceMangaStatus.unknown,
      };

  SourceMangaDetails parseDetails(Document doc, Uri base) {
    final title = clean(doc.querySelector('.a2 header h1')?.text);
    if (title.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Detail seri tidak ditemukan.'));
    final author = clean(doc.querySelector('div.y6x11p i.fas.fa-user + span.dt')?.text);
    final chapters = <SourceChapter>[];
    for (final el in doc.querySelectorAll('ul > li.chapter')) {
      final a = el.querySelector('a');
      final url = absUrl(base, a?.attributes['href']);
      final name = clean(a?.text);
      if (url == null || name.isEmpty) continue;
      final seconds = int.tryParse(el.querySelector('time[datetime]')?.attributes['datetime'] ?? '');
      chapters.add(SourceChapter(
        url: url,
        name: name,
        number: parseChapterNumber(name),
        uploadedAt: seconds == null ? null : DateTime.fromMillisecondsSinceEpoch(seconds * 1000),
      ));
    }
    final description = clean(doc.querySelector('div#syn-target')?.text);
    return SourceMangaDetails(
      url: base.toString(),
      title: title,
      thumbnailUrl: _img(doc.querySelector('.a1 > figure img'), base),
      author: author.isEmpty || author.toLowerCase() == 'updating' ? null : author,
      description: description.isEmpty ? null : description,
      genres: [
        for (final g in doc.querySelectorAll(".a2 div > a[rel='tag'].label"))
          if (clean(g.text).isNotEmpty) clean(g.text),
      ],
      status: _status(doc.querySelector('div.y6x11p i.fas.fa-rss + span.dt')?.text),
      chapters: chapters,
    );
  }

  // =========================== Halaman ===========================

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    final script = res.document.querySelectorAll('script').where((s) => s.text.contains('const CHAPTER_ID')).firstOrNull;
    final chapterId = script == null ? null : RegExp(r'const CHAPTER_ID\s*=\s*(\d+)').firstMatch(script.text)?.group(1);
    if (chapterId == null) throw SourceException(SourceErrorKind.parse, detail: tr('ID bab tidak ditemukan.'));
    final json = asMap(await fetchJson(
      Uri.parse('$baseUrl/ajax/image/list/chap/$chapterId'),
      headers: {
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Referer': chapter.url,
        'X-Requested-With': 'XMLHttpRequest',
      },
    ));
    if (json['status'] != true) {
      throw SourceException(SourceErrorKind.parse, detail: asString(json['msg']) ?? tr('Gambar bab tidak ditemukan.'));
    }
    return parsePages(asString(json['html']) ?? '', Uri.parse(chapter.url));
  }

  List<String> parsePages(String html, Uri base) {
    final frag = html_parser.parseFragment(html);
    bool isImage(String url) {
      final lower = url.toLowerCase();
      final path = lower.split('?').first.split('#').first;
      return !path.endsWith('.svg') && !lower.contains('loading_comments');
    }

    final seps = frag.querySelectorAll('div.separator[data-index]');
    final pairs = <(int, String)>[];
    if (seps.isEmpty) {
      var i = 0;
      for (final s in frag.querySelectorAll('div.separator')) {
        final url = absUrl(base, s.querySelector('a')?.attributes['href']);
        if (url != null && isImage(url)) pairs.add((i++, url));
      }
    } else {
      for (final s in seps) {
        final url = absUrl(base, s.querySelector('a')?.attributes['href']);
        if (url != null && isImage(url)) pairs.add((int.tryParse(s.attributes['data-index'] ?? '') ?? 0, url));
      }
      pairs.sort((a, b) => a.$1.compareTo(b.$1));
    }
    if (pairs.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    return [for (final (_, url) in pairs) url];
  }

  /// Situs ini menolak gambar yang membawa Referer.
  @override
  Map<String, String> imageHeaders({String? referer}) =>
      {...super.imageHeaders(referer: referer)}..remove('Referer');
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
