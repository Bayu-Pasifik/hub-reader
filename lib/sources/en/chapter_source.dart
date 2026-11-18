// Template seri-bab berbasis selector: daftar kartu -> halaman seri (daftar bab)
// -> halaman bab berisi gambar. Dipakai sumber dewasa dari keiyoushi/extensions-source
// (Apache-2.0) yang strukturnya HTML statis tanpa tema umum.

import 'package:html/dom.dart';

import '../../core/i18n/strings.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class ChapterSource extends HttpSource {
  ChapterSource({
    required this.id,
    required this.name,
    required String baseUrl,
    required this.popularUrl,
    required this.searchUrl,
    required this.cardSel,
    required this.chapterSel,
    required this.imagesOf,
    this.latestUrl,
    this.cardLinkSel = 'a[href]',
    this.cardTitleSel,
    this.cardThumbSel = 'img',
    this.nextSel = 'a[rel=next], a.next',
    this.titleSel = 'h1',
    this.coverSel,
    this.descSel,
    this.tagSel,
    this.authorSel,
    this.statusSel,
    this.chapterNameSel,
    this.reverseChapters = false,
    this.thumbFromUrl,
    this.cleanTitle,
    this.localSearch = false,
    this.contentWarning = ContentWarning.nsfw,
    this.lang = 'en',
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
  @override
  bool get supportsLatest => latestUrl != null;

  final String Function(String base, int page) popularUrl;
  final String Function(String base, int page)? latestUrl;
  final String? Function(String base, int page, String query) searchUrl;
  final String cardSel;
  final String cardLinkSel;
  final String? cardTitleSel;
  final String cardThumbSel;
  final String nextSel;
  final String titleSel;
  final String? coverSel;
  final String? descSel;
  final String? tagSel;
  final String? authorSel;
  final String? statusSel;

  /// Selector tautan bab (elemen `a`, atau pembungkus yang berisi `a`).
  final String chapterSel;
  final String? chapterNameSel;

  /// Balik urutan bila situs menampilkan bab dari yang terlama.
  final bool reverseChapters;

  /// Sampul daftar bila kartu tidak memuat gambar: dibangun dari URL seri.
  final String? Function(String seriesUrl)? thumbFromUrl;

  /// Rapikan judul seri di halaman detail (mis. buang awalan SEO).
  final String Function(String title)? cleanTitle;

  /// Situs tidak punya pencarian sisi server: saring daftar populer di klien.
  final bool localSearch;
  final List<String> Function(Document doc, Uri base) imagesOf;

  Future<MangaPage> _list(String url) async {
    final res = await fetchHtml(Uri.parse(url));
    final items = <SourceManga>[];
    final seen = <String>{};
    for (final card in res.document.querySelectorAll(cardSel)) {
      final link = card.localName == 'a' && card.attributes.containsKey('href') ? card : card.querySelector(cardLinkSel);
      final href = attrAbs(link, 'href', res.url);
      if (link == null || href == null || !seen.add(href)) continue;
      final title = clean(cardTitleSel == null
          ? (link.attributes['title'] ?? link.attributes['aria-label'] ?? (link.text.trim().isEmpty ? card.querySelector('img')?.attributes['alt'] : link.text))
          : _text(card.querySelector(cardTitleSel!)));
      final shown = cleanTitle == null ? title : cleanTitle!(title);
      if (shown.isEmpty) continue;
      items.add(SourceManga(url: href, title: shown, thumbnailUrl: _thumb(card.querySelector(cardThumbSel), res.url) ?? thumbFromUrl?.call(href)));
    }
    return MangaPage(items, hasNextPage: res.document.querySelector(nextSel) != null);
  }

  @override
  Future<MangaPage> popular(int page) => _list(popularUrl(baseUrl, page));

  @override
  Future<MangaPage> latest(int page) => _list(latestUrl!(baseUrl, page));

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    final q = query.trim();
    if (q.isEmpty) return popular(page);
    if (localSearch) {
      final all = await popular(page);
      final lq = q.toLowerCase();
      return MangaPage([for (final m in all.items) if (m.title.toLowerCase().contains(lq)) m], hasNextPage: false);
    }
    final url = searchUrl(baseUrl, page, q);
    if (url == null) return const MangaPage([], hasNextPage: false);
    return _list(url);
  }

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    final doc = res.document;
    final rawTitle = _text(doc.querySelector(titleSel));
    final title = cleanTitle == null ? rawTitle : cleanTitle!(rawTitle);
    if (title.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Judul seri tidak ditemukan.'));
    }
    final chapters = <SourceChapter>[];
    final seen = <String>{};
    for (final el in doc.querySelectorAll(chapterSel)) {
      final a = el.localName == 'a' ? el : el.querySelector('a[href]');
      final href = attrAbs(a, 'href', res.url);
      if (a == null || href == null || !seen.add(href)) continue;
      final label = clean(chapterNameSel == null ? el.text : el.querySelector(chapterNameSel!)?.text ?? a.text);
      chapters.add(SourceChapter(url: href, name: label.isEmpty ? href.split('/').last : label, number: _number(label, href)));
    }
    final ordered = reverseChapters ? chapters.reversed.toList() : chapters;
    final statusText = statusSel == null ? '' : clean(doc.querySelector(statusSel!)?.text).toLowerCase();
    return SourceMangaDetails(
      url: mangaUrl,
      title: title,
      thumbnailUrl: coverSel == null ? null : _thumb(doc.querySelector(coverSel!), res.url),
      description: descSel == null ? null : clean(doc.querySelector(descSel!)?.text),
      author: authorSel == null ? null : clean(doc.querySelector(authorSel!)?.text),
      genres: tagSel == null
          ? const []
          : [for (final a in doc.querySelectorAll(tagSel!)) clean(a.text)].where((e) => e.isNotEmpty).toSet().toList(),
      status: statusText.contains('complet') || statusText.contains('end')
          ? SourceMangaStatus.completed
          : statusText.contains('ongoing')
              ? SourceMangaStatus.ongoing
              : SourceMangaStatus.unknown,
      chapters: ordered,
    );
  }

  static String _text(Element? el) =>
      clean(el == null ? null : (el.attributes['content'] ?? (el.localName == 'img' ? el.attributes['alt'] : el.text)));

  /// Gambar dari <img>, <meta content>, atau `background-image: url(...)`.
  static String? _thumb(Element? el, Uri base) {
    if (el == null) return null;
    final meta = el.attributes['content'];
    if (meta != null) return absUrl(base, meta);
    final img = imgAttr(el, base);
    if (img != null) return img;
    final m = RegExp(r'''url\(['"]?([^'")]+)''').firstMatch(el.attributes['style'] ?? '');
    return m == null ? null : absUrl(base, m[1]);
  }

  static double? _number(String label, String href) {
    final m = RegExp(r'(\d+(?:\.\d+)?)').allMatches('$label ${href.split('/').last}');
    if (m.isEmpty) return null;
    return double.tryParse(m.first.group(1)!);
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    final images = imagesOf(res.document, res.url);
    if (images.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    }
    return images;
  }
}
