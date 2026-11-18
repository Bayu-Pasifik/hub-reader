// Template galeri satu-bab berbasis selector: daftar kartu -> halaman galeri
// berisi gambar. Dipakai sumber dewasa dari keiyoushi/extensions-source
// (Apache-2.0) yang strukturnya sama (satu entri = satu bab "Oneshot").

import 'package:html/dom.dart';

import '../../core/i18n/strings.dart';
import '../filters.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class GallerySource extends HttpSource {
  GallerySource({
    required this.id,
    required this.name,
    required String baseUrl,
    required this.popularUrl,
    required this.searchUrl,
    required this.cardSel,
    required this.imagesOf,
    this.latestUrl,
    this.cardLinkSel = 'a[href]',
    this.cardTitleSel,
    this.cardThumbSel = 'img',
    this.nextSel = 'a[rel=next], a.next, a.nextp',
    this.titleSel = 'h1',
    this.tagSel = 'a[rel=tag]',
    this.descSel,
    this.coverFromImages = true,
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

  /// URL absolut halaman daftar populer/terbaru untuk halaman ke-[page].
  final String Function(String base, int page) popularUrl;
  final String Function(String base, int page)? latestUrl;

  /// URL pencarian, atau null bila situs tidak mendukungnya.
  final String? Function(String base, int page, String query) searchUrl;

  final String cardSel;
  final String cardLinkSel;
  final String? cardTitleSel;
  final String cardThumbSel;
  final String nextSel;
  final String titleSel;
  final String tagSel;
  final String? descSel;
  final bool coverFromImages;

  /// Daftar URL gambar dari halaman galeri.
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
          ? (link.attributes['title'] ?? link.attributes['aria-label'] ?? (link.text.trim().isEmpty ? link.querySelector('img')?.attributes['alt'] : link.text))
          : card.querySelector(cardTitleSel!)?.text);
      if (title.isEmpty) continue;
      items.add(SourceManga(url: href, title: title, thumbnailUrl: imgAttr(card.querySelector(cardThumbSel), res.url)));
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
    final url = searchUrl(baseUrl, page, q);
    if (url == null) return const MangaPage([], hasNextPage: false);
    return _list(url);
  }

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    final doc = res.document;
    final titleEl = doc.querySelector(titleSel);
    final title = clean(titleEl?.attributes['content'] ?? titleEl?.text);
    if (title.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Judul seri tidak ditemukan.'));
    }
    final images = imagesOf(doc, res.url);
    return SourceMangaDetails(
      url: mangaUrl,
      title: title,
      thumbnailUrl: images.isEmpty ? null : images.first,
      description: descSel == null ? null : clean(doc.querySelector(descSel!)?.text),
      genres: [for (final a in doc.querySelectorAll(tagSel)) clean(a.text)].where((e) => e.isNotEmpty).toSet().toList(),
      status: SourceMangaStatus.completed,
      chapters: [SourceChapter(url: mangaUrl, name: 'Oneshot', number: 1)],
    );
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

/// Gambar dari kumpulan elemen: atribut pertama yang berisi URL.
List<String> imagesFrom(Document doc, Uri base, String selector, List<String> attrs) {
  final out = <String>[];
  for (final el in doc.querySelectorAll(selector)) {
    for (final a in attrs) {
      final u = attrAbs(el, a, base);
      if (u != null) {
        out.add(u);
        break;
      }
    }
  }
  return out;
}
