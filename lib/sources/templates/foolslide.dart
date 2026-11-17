// Port Dart dari template FoolSlide milik keiyoushi/extensions-source
// (Apache-2.0): lib-multisrc/foolslide.
//
// Pembaca scanlation lama: daftar `/directory/N/`, `/latest/N/`, cari lewat
// POST `/search/`, detail & bab di halaman `/series/...`, gambar di variabel JS
// `var pages = [...]`. Halaman dewasa dibuka dengan POST `adult=true`.

import 'dart:convert';

import 'package:html/dom.dart';

import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';
import '../../core/i18n/strings.dart';

class FoolSlideSource extends HttpSource {
  FoolSlideSource({
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

  /// Awalan jalur situs (`/slide`, `/lector`).
  String get urlModifier => asString(vals['urlModifier']) ?? '';

  @override
  bool get supportsLatest => vals['supportsLatest'] != false;

  // =========================== Daftar ===========================

  @override
  Future<MangaPage> popular(int page) => _list('$baseUrl$urlModifier/directory/$page/');

  @override
  Future<MangaPage> latest(int page) => _list('$baseUrl$urlModifier/latest/$page/');

  Future<MangaPage> _list(String url) async {
    final res = await fetchHtml(Uri.parse(url));
    return parseList(res.document, res.url);
  }

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    final res = await postHtml(Uri.parse('$baseUrl$urlModifier/search/'), {'search': query.trim()});
    return parseList(res.document, res.url, searchPage: true);
  }

  MangaPage parseList(Document doc, Uri base, {bool searchPage = false}) {
    final items = <SourceManga>[];
    for (final group in doc.querySelectorAll('div.group')) {
      final link = group.querySelector('a[title]');
      final url = absUrl(base, link?.attributes['href']);
      final title = clean(link?.text);
      if (url == null || title.isEmpty) continue;
      final img = group.querySelector('img')?.attributes['src'];
      items.add(SourceManga(
        url: url,
        title: title,
        thumbnailUrl: img == null ? null : absUrl(base, img)?.replaceAll('/thumb_', '/'),
      ));
    }
    final next = searchPage ? doc.querySelector('a span.next') : doc.querySelector('div.next');
    return MangaPage(items, hasNextPage: next != null);
  }

  // =========================== Detail ===========================

  /// Halaman dewasa butuh POST `adult=true`; yang lain GET biasa.
  Future<HtmlResponse> _open(Uri url) async {
    try {
      return await postHtml(url, {'adult': 'true'}, headers: {'Origin': baseUrl});
    } on SourceException {
      return fetchHtml(url);
    }
  }

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await _open(Uri.parse(mangaUrl));
    var cover = _cover(res.document, res.url);
    final chapters = parseChapters(res.document, res.url);
    // Tanpa sampul di halaman seri: pakai halaman pertama bab pertama.
    if (cover == null && chapters.isNotEmpty) {
      try {
        final first = await _open(Uri.parse(chapters.last.url));
        cover = parsePages(first.document, first.url).firstOrNull;
      } catch (_) {
        // Sampul dilewati.
      }
    }
    return parseDetails(res.document, res.url, chapters, cover);
  }

  String? _cover(Document doc, Uri base) {
    final img = doc.querySelector('div.thumbnail img, table.thumb img');
    final src = absUrl(base, img?.attributes['src']);
    return src?.replaceAll('/thumb_', '/');
  }

  SourceMangaDetails parseDetails(Document doc, Uri base, List<SourceChapter> chapters, String? cover) {
    String? author, artist, description;
    final info = doc.querySelector('div.info');
    if (info != null) {
      for (final b in info.querySelectorAll('b')) {
        final label = clean(b.text).toLowerCase();
        final siblings = b.parent?.nodes ?? const <Node>[];
        final at = siblings.indexOf(b);
        final next = at >= 0 && at + 1 < siblings.length ? siblings[at + 1] : null;
        final value = next is Text ? next.text.trim().replaceFirst(RegExp(r'^:'), '').trim() : '';
        if (value.isEmpty) continue;
        if (label.contains('author') || label.contains('autore')) {
          author = value;
        } else if (label.contains('artist')) {
          artist = value;
        } else if (label.contains('synopsis') || label.contains('description') || label.contains('trama')) {
          description = value;
        }
      }
    }
    final title = clean(doc.querySelector('h1.title')?.text);
    return SourceMangaDetails(
      url: base.toString(),
      title: title.isEmpty ? clean(base.pathSegments.where((s) => s.isNotEmpty).lastOrNull) : title,
      thumbnailUrl: cover,
      author: author,
      artist: artist,
      description: description,
      chapters: chapters,
    );
  }

  List<SourceChapter> parseChapters(Document doc, Uri base) {
    final out = <SourceChapter>[];
    for (final el in doc.querySelectorAll('div.group div.element, div.list div.element')) {
      final link = el.querySelector('a[title]');
      final url = absUrl(base, link?.attributes['href']);
      final name = clean(link?.text);
      if (url == null || name.isEmpty) continue;
      final meta = clean(el.querySelector('div.meta_r')?.text);
      final comma = meta.indexOf(', ');
      out.add(SourceChapter(
        url: url,
        name: name,
        number: parseChapterNumber(name),
        uploadedAt: parseChapterDate(comma >= 0 ? meta.substring(comma + 2) : meta),
      ));
    }
    return out;
  }

  static final _ordinal = RegExp(r'(\d+)(?:st|nd|rd|th)\b');

  /// "Today", "Yesterday", "3 days ago", "2025.10.09", "9th October, 2025".
  static DateTime? parseChapterDate(String raw, {DateTime? now}) {
    final text = raw.trim().toLowerCase();
    if (text.isEmpty) return null;
    final today = now ?? DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);
    if (text.startsWith('yesterday')) return midnight.subtract(const Duration(days: 1));
    if (text.startsWith('today')) return midnight;
    if (text.startsWith('tomorrow')) return midnight.add(const Duration(days: 1));
    final dotted = RegExp(r'^(\d{4})\.(\d{2})\.(\d{2})').firstMatch(text);
    if (dotted != null) return DateTime(int.parse(dotted[1]!), int.parse(dotted[2]!), int.parse(dotted[3]!));
    final normal = text.replaceAllMapped(_ordinal, (m) => m[1]!);
    return parseLooseDate(normal, now: today);
  }

  // =========================== Halaman ===========================

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await _open(Uri.parse(chapter.url));
    return parsePages(res.document, res.url);
  }

  List<String> parsePages(Document doc, Uri base) {
    final html = doc.outerHtml;
    final start = html.indexOf('var pages = ');
    if (start < 0) return const [];
    final end = html.indexOf(';', start);
    final json = html.substring(start + 'var pages = '.length, end < 0 ? html.length : end);
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      throw SourceException(SourceErrorKind.parse, detail: tr('Daftar gambar tidak terbaca.'));
    }
    return [
      for (final p in asList(decoded))
        if (absUrl(base, asString(asMap(p)['url'])) case final url?) url,
    ];
  }
}
