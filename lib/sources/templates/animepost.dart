// Template "AnimePost" (tema WordPress Komikindo/BacaKomik): kartu `div.animepost`,
// daftar bab `#chapter_list`, gambar `div.img-landmine`. Port dari BacaKomik dan
// KomikIndoID di keiyoushi/extensions-source (Apache-2.0).

import 'package:html/dom.dart';

import '../../core/i18n/strings.dart';
import '../html_utils.dart';
import '../filters.dart';
import '../models.dart';
import '../source_exception.dart';
import 'mangathemesia.dart';

class AnimePostSource extends MangaThemesiaSource {
  AnimePostSource({
    required super.id,
    required super.name,
    required super.baseUrl,
    required super.mangaUrlDirectory,
    super.lang,
    super.contentWarning,
    this.removeTitlePrefix = 'Komik',
    super.dio,
  });

  final String removeTitlePrefix;

  /// Halaman 2 dst memakai `/page/N/`, bukan `?page=N`.
  @override
  Uri searchUrl(int page, String query, {String? order, FilterValues filters = FilterValues.empty}) {
    final selectedOrder = filters.single('order') ?? order;
    return baseUri.replace(
      path: '$mangaUrlDirectory/${page > 1 ? 'page/$page/' : ''}',
      queryParameters: <String, dynamic>{
        if (query.isNotEmpty) 'title': query,
        if (filters.single('status') case final status?) 'status': status,
        if (filters.single('type') case final type?) 'type': type,
        if (selectedOrder != null) 'order': selectedOrder,
        if (filters.multi('genre').isNotEmpty) 'genre[]': filters.multi('genre'),
      },
    );
  }

  @override
  MangaPage parseMangaList(Document doc, Uri pageUrl) {
    final items = <SourceManga>[];
    for (final card in doc.querySelectorAll('div.animepost')) {
      final a = card.querySelector('div.animposx > a') ?? card.querySelector('a');
      final url = attrAbs(a, 'href', pageUrl);
      if (url == null) continue;
      var title = clean(card.querySelector('.tt h3, .tt h4, .tt')?.text);
      if (title.isEmpty) title = _stripPrefix(clean(a!.attributes['title']));
      final manga = SourceManga(
        url: url,
        title: title.isEmpty ? tr('Tanpa judul') : title,
        thumbnailUrl: imgAttr(card.querySelector('div.limit img') ?? card.querySelector('img'), pageUrl),
      );
      if (!items.contains(manga)) items.add(manga);
    }
    return MangaPage(items, hasNextPage: doc.querySelector('a.next.page-numbers') != null);
  }

  String _stripPrefix(String s) =>
      removeTitlePrefix.isNotEmpty && s.startsWith(removeTitlePrefix) ? s.substring(removeTitlePrefix.length).trim() : s;

  String? _spe(Document doc, String label) {
    for (final span in doc.querySelectorAll('.infox .spe span')) {
      final text = clean(span.text);
      if (text.toLowerCase().startsWith(label.toLowerCase())) {
        final value = clean(text.substring(label.length).replaceFirst(RegExp(r'^\s*:?\s*'), ''));
        if (value.isNotEmpty) return value;
      }
    }
    return null;
  }

  @override
  SourceMangaDetails parseDetails(Document doc, Uri pageUrl) {
    final title = _stripPrefix(clean(doc.querySelector('h1.entry-title')?.text));
    if (title.isEmpty) {
      throw SourceException(
        SourceErrorKind.parse,
        detail: tr('Judul seri tidak ditemukan; mungkin bukan halaman seri.'),
      );
    }
    final genres = <String>{
      for (final a in doc.querySelectorAll('.infox > .genre-info > a, .infox .spe span a'))
        if (clean(a.text).isNotEmpty) clean(a.text),
    };
    final desc = clean(doc.querySelector('div.desc .entry-content, .entry-content-single')?.text);
    final marker = desc.indexOf('bercerita tentang ');
    return SourceMangaDetails(
      url: pageUrl.toString(),
      title: title,
      thumbnailUrl: imgAttr(doc.querySelector('.thumb img'), pageUrl),
      author: _spe(doc, 'Author') ?? _spe(doc, 'Pengarang'),
      artist: _spe(doc, 'Artis') ?? _spe(doc, 'Artist'),
      description: desc.isEmpty ? null : (marker >= 0 ? desc.substring(marker + 18) : desc),
      genres: genres.toList(),
      status: parseStatus(_spe(doc, 'Status')),
      chapters: parseChapters(doc, pageUrl),
    );
  }

  @override
  List<SourceChapter> parseChapters(Document doc, Uri pageUrl) {
    final seen = <String>{};
    final chapters = <SourceChapter>[];
    for (final li in doc.querySelectorAll('#chapter_list li')) {
      final a = li.querySelector('.lchx a') ?? li.querySelector('a');
      final url = attrAbs(a, 'href', pageUrl);
      if (url == null || !seen.add(url)) continue;
      final name = clean(a!.text);
      chapters.add(SourceChapter(
        url: url,
        name: name.isEmpty ? tr('Bab') : name,
        number: parseChapterNumber(name),
        uploadedAt: parseLooseDate(li.querySelector('.dt a, .dt')?.text),
      ));
    }
    return chapters;
  }

  @override
  List<String> parsePages(Document doc, String body, Uri pageUrl) {
    final pages = <String>[];
    for (final img in doc.querySelectorAll('div.img-landmine img')) {
      if (img.parent?.localName == 'noscript') continue;
      final onError = img.attributes['onError'] ?? img.attributes['onerror'] ?? '';
      String? url;
      final m = RegExp(r"src='([^']+)'").firstMatch(onError);
      url = m != null ? m.group(1) : imgAttr(img, pageUrl);
      if (url != null && url.isNotEmpty) pages.add(url);
    }
    if (pages.isNotEmpty) return pages;
    // BacaKomik: gambar dalam div yang anak langsungnya img[alt*=Chapter].
    for (final img in doc.querySelectorAll('img[alt*="Chapter"]')) {
      if (img.parent?.localName == 'noscript') continue;
      final url = imgAttr(img, pageUrl);
      if (url != null && url.isNotEmpty) pages.add(url);
    }
    if (pages.isNotEmpty) return pages;
    return super.parsePages(doc, body, pageUrl);
  }
}
