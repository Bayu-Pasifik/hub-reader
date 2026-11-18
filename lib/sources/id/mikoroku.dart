// Port Dart dari extension MikoRoku milik keiyoushi/extensions-source
// (Apache-2.0): src/id/mikoroku.
//
// Katalog dari JSON di GitHub, detail/bab dari Firestore (bila kuota ada) dan
// feed Blogger (mikodrive / yomidays) sebagai cadangan sekaligus sumber gambar.

import 'package:html/parser.dart' as html_parser;

import '../../core/i18n/strings.dart';
import '../../core/utils/json.dart';
import '../filters.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class MikoRokuSource extends HttpSource {
  MikoRokuSource({super.dio});

  @override
  String get id => 'id.mikoroku';
  @override
  String get name => 'MikoRoku';
  @override
  String get lang => 'id';
  @override
  String get defaultBaseUrl => 'https://mikoroku.com';
  @override
  ContentWarning get contentWarning => ContentWarning.nsfw;

  static const _catalogUrl = 'https://raw.githubusercontent.com/moemaomao/mymangadata/main/all-manga.json';
  static const _fs = 'https://firestore.googleapis.com/v1/projects/mikoroku/databases/(default)/documents/manga';
  static const _bloggers = [
    'https://www.mikodrive.my.id/feeds/posts/default',
    'https://www.yomidays.my.id/feeds/posts/default',
  ];

  static final _chapterRe = RegExp(r'Chapter\s+(\d+(?:\.\d+)?)', caseSensitive: false);
  static final _postIdRe = RegExp(r'post-(\d+)');
  static final _chapterUrlRe = RegExp(r'/manga/([^/]+)/chapter/([^/]+)');
  static final _postUrlRe = RegExp(r'/manga/([^/]+)/post/([^/]+)');

  static const _romans = [
    ['viii', '8'], ['vii', '7'], ['iii', '3'], ['ii', '2'], ['ix', '9'],
    ['iv', '4'], ['vi', '6'], ['v', '5'], ['x', '10'], ['i', '1'],
  ];

  String _deroman(String text) {
    var s = text.toLowerCase();
    for (final r in _romans) {
      s = s.replaceAll(RegExp('\\b${r[0]}\\b'), r[1]);
    }
    return s;
  }

  String _norm(String text) => _deroman(text).replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

  List<String> _words(String text) =>
      _deroman(text).split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toList();

  bool _wordsMatch(String post, String manga) {
    final mw = _words(manga);
    if (mw.isEmpty) return false;
    final pw = _words(post).toSet();
    final matched = mw.where(pw.contains).length;
    return mw.length <= 2 ? matched == mw.length : matched >= (mw.length * 0.7).floor();
  }

  String? _label(String text) => _chapterRe.firstMatch(text)?.group(0);
  double _number(String text) => double.tryParse(_chapterRe.firstMatch(text)?.group(1) ?? '') ?? -1;

  // ---- katalog ----

  List<JsonMap>? _catalog;

  Future<List<JsonMap>> _fetchCatalog() async {
    return _catalog ??= [
      for (final e in asList(await fetchJson(Uri.parse(_catalogUrl)))) asMap(e),
    ];
  }

  SourceManga _card(JsonMap e) => SourceManga(
        url: '$baseUrl/detail.html?slug=${e['slug']}',
        title: clean(asString(e['title'])),
        thumbnailUrl: (asString(e['img']) ?? '').isEmpty ? null : asString(e['img']),
      );

  @override
  bool get supportsLatest => true;

  @override
  Future<MangaPage> popular(int page) async {
    if (page > 1) return const MangaPage([], hasNextPage: false);
    final list = [...await _fetchCatalog()]
      ..sort((a, b) => (asDouble(b['rating']) ?? 0).compareTo(asDouble(a['rating']) ?? 0));
    return MangaPage([for (final e in list) _card(e)], hasNextPage: false);
  }

  @override
  Future<MangaPage> latest(int page) async {
    if (page > 1) return const MangaPage([], hasNextPage: false);
    return MangaPage([for (final e in await _fetchCatalog()) _card(e)], hasNextPage: false);
  }

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    if (page > 1) return const MangaPage([], hasNextPage: false);
    final q = _norm(query);
    if (q.isEmpty) return latest(page);
    final list = [
      for (final e in await _fetchCatalog())
        if (_norm(asString(e['title']) ?? '').contains(q) ||
            (asString(e['altTitle']) ?? '').split(';').any((a) => _norm(a).contains(q)))
          _card(e),
    ];
    return MangaPage(list, hasNextPage: false);
  }

  // ---- Firestore ----

  Future<JsonMap?> _firestore(String path) async {
    try {
      return asMap(await fetchJson(Uri.parse('$_fs/$path')));
    } catch (_) {
      return null;
    }
  }

  String? _fsString(Object? v) => asString(asMap(v)['stringValue']);
  List<String> _fsStrings(Object? v) => [
        for (final x in asList(asMap(asMap(v)['arrayValue'])['values']))
          if (_fsString(x) != null) _fsString(x)!,
      ];
  int? _fsInt(Object? v) => int.tryParse(asString(asMap(v)['integerValue']) ?? '');
  bool? _fsBool(Object? v) => asMap(v)['booleanValue'] as bool?;

  // ---- Blogger ----

  Future<List<JsonMap>> _blogger(String feed, String query, int max) async {
    Future<List<JsonMap>> run(String q) async {
      try {
        final json = asMap(await fetchJson(
          Uri.parse(feed).replace(queryParameters: {'alt': 'json', 'max-results': '$max', 'q': q}),
        ));
        return [for (final e in asList(asMap(json['feed'])['entry'])) asMap(e)];
      } catch (_) {
        return const [];
      }
    }

    var out = await run(query);
    if (out.isNotEmpty) return out;
    final stripped = query.replaceAll(RegExp(r'\s+(\d+|[ivxl]+)$', caseSensitive: false), '').trim();
    if (stripped.isNotEmpty && stripped != query) {
      out = await run(stripped);
      if (out.isNotEmpty) return out;
    }
    final words = query.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    for (final n in [4, 3]) {
      if (words.length > n) {
        out = await run(words.take(n).join(' '));
        if (out.isNotEmpty) return out;
      }
    }
    return const [];
  }

  String _t(Object? v) => asString(asMap(v)[r'$t']) ?? '';

  List<String> _images(JsonMap entry) {
    final doc = html_parser.parseFragment(_t(entry['content']));
    return {
      for (final img in doc.querySelectorAll('img'))
        if ((img.attributes['src'] ?? '').startsWith('http')) img.attributes['src']!,
    }.toList();
  }

  // ---- detail ----

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final slug = Uri.parse(mangaUrl).queryParameters['slug'];
    if (slug == null) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Judul seri tidak ditemukan.'));
    }
    final entry = (await _fetchCatalog()).where((e) => e['slug'] == slug).firstOrNull;
    final doc = await _firestore(slug);
    final f = asMap(doc?['fields']);
    String? pick(String key) {
      final a = _fsString(f[key]);
      if (a != null && a.trim().isNotEmpty) return a.trim();
      final b = asString(entry?[key]);
      return b == null || b.trim().isEmpty ? null : b.trim();
    }

    final title = pick('title');
    if (title == null) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Judul seri tidak ditemukan.'));
    }
    final descRaw = _fsString(f['desc']) ?? asString(entry?['desc']);
    final genres = _fsStrings(f['genres']).isNotEmpty ? _fsStrings(f['genres']) : asStringList(entry?['genres']);
    final author = [pick('author'), pick('artist')].whereType<String>().toSet().join(', ');
    return SourceMangaDetails(
      url: '$baseUrl/detail.html?slug=$slug',
      title: title,
      thumbnailUrl: pick('img'),
      author: author.isEmpty ? null : author,
      description: descRaw == null ? '' : clean(html_parser.parseFragment(descRaw).text),
      genres: genres,
      status: switch ((pick('status') ?? '').toLowerCase()) {
        'ongoing' => SourceMangaStatus.ongoing,
        'completed' => SourceMangaStatus.completed,
        'hiatus' => SourceMangaStatus.hiatus,
        'dropped' || 'cancelled' => SourceMangaStatus.cancelled,
        _ => SourceMangaStatus.unknown,
      },
      chapters: await _chapters(slug, doc, title),
    );
  }

  Future<List<SourceChapter>> _chapters(String slug, JsonMap? doc, String title) async {
    final out = <SourceChapter>[];
    final seen = <double>{};
    void add(SourceChapter c) {
      final n = _number(c.name);
      if (n >= 0 && !seen.add(n)) return;
      out.add(c);
    }

    // Firestore: subkoleksi chapters.
    final sub = await _firestore('$slug/chapters?pageSize=500');
    for (final d in asList(sub?['documents'])) {
      final dm = asMap(d);
      final fm = asMap(dm['fields']);
      if (_fsBool(fm['isDraft']) == true) continue;
      final t = _fsString(fm['title']);
      if (t == null || t.trim().isEmpty) continue;
      final key = (asString(dm['name']) ?? '').split('/').last;
      final date = _fsInt(fm['date']);
      add(SourceChapter(
        url: '$baseUrl/manga/$slug/chapter/$key',
        name: t.trim(),
        number: _number(t) < 0 ? null : _number(t),
        uploadedAt: date == null ? null : DateTime.fromMillisecondsSinceEpoch(date),
      ));
    }
    // Firestore: field "chapters.<key>" pada dokumen seri.
    final fields = asMap(doc?['fields']);
    for (final e in fields.entries) {
      if (!e.key.startsWith('chapters.')) continue;
      final cf = asMap(asMap(asMap(e.value)['mapValue'])['fields']);
      if (_fsBool(cf['isDraft']) == true) continue;
      final t = _fsString(cf['title']);
      if (t == null || t.trim().isEmpty) continue;
      final date = _fsInt(cf['date']);
      add(SourceChapter(
        url: '$baseUrl/manga/$slug/chapter/${e.key.substring('chapters.'.length)}',
        name: t.trim(),
        number: _number(t) < 0 ? null : _number(t),
        uploadedAt: date == null ? null : DateTime.fromMillisecondsSinceEpoch(date),
      ));
    }
    // Blogger.
    for (final feed in _bloggers) {
      for (final e in await _blogger(feed, title, 500)) {
        final postTitle = _t(e['title']);
        final matches = _norm(postTitle).contains(_norm(title)) || _wordsMatch(postTitle, title);
        final label = matches ? _label(postTitle) : null;
        final postId = _postIdRe.firstMatch(_t(e['id']))?.group(1);
        if (label == null || postId == null) continue;
        add(SourceChapter(
          url: '$baseUrl/manga/$slug/post/$postId',
          name: label,
          number: _number(label) < 0 ? null : _number(label),
          uploadedAt: DateTime.tryParse(_t(e['published'])),
        ));
      }
    }
    out.sort((a, b) => _number(b.name).compareTo(_number(a.name)));
    return out;
  }

  // ---- halaman ----

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    List<String> result = const [];
    final post = _postUrlRe.firstMatch(chapter.url);
    if (post != null) {
      result = await _postPages(post.group(2)!);
    } else {
      final m = _chapterUrlRe.firstMatch(chapter.url);
      if (m == null) {
        throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
      }
      final slug = m.group(1)!;
      final key = m.group(2)!;
      final sub = await _firestore('$slug/chapters/$key');
      result = _fsStrings(asMap(sub?['fields'])['images']);
      if (result.isEmpty) {
        final doc = await _firestore(slug);
        final cf = asMap(asMap(asMap(asMap(doc?['fields'])['chapters.$key'])['mapValue'])['fields']);
        result = _fsStrings(cf['images']);
      }
      if (result.isEmpty) {
        final title = (await _fetchCatalog()).where((e) => e['slug'] == slug).firstOrNull?['title'] as String?;
        final label = _label(chapter.name);
        if (title != null && label != null) {
          final number = _number(label);
          final hits = await _blogger(_bloggers.first, '$title $label', 5);
          for (final e in hits) {
            final pt = _t(e['title']);
            if ((_norm(pt).contains(_norm(title)) || _wordsMatch(pt, title)) && _number(pt) == number) {
              result = _images(e);
              break;
            }
          }
        }
      }
    }
    if (result.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    }
    return result;
  }

  Future<List<String>> _postPages(String postId) async {
    final json = asMap(await fetchJson(Uri.parse('${_bloggers.first}/$postId').replace(queryParameters: {'alt': 'json'})));
    return _images(asMap(json['entry']));
  }
}
