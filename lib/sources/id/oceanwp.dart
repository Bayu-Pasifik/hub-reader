// Port Dart dari template OceanWP milik keiyoushi/extensions-source
// (Apache-2.0): lib-multisrc/oceanwp. Dipakai Hentai Crot & Pix Hentai.
// Setiap entri = satu "bab" tunggal (galeri satu halaman).

import 'package:html/dom.dart';

import '../../core/i18n/strings.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class OceanWpSource extends HttpSource {
  OceanWpSource({required this.id, required this.name, required String baseUrl, super.dio})
      : defaultBaseUrl = baseUrl;

  @override
  final String id;
  @override
  final String name;
  @override
  final String defaultBaseUrl;
  @override
  String get lang => 'id';
  @override
  ContentWarning get contentWarning => ContentWarning.nsfw;
  @override
  bool get supportsLatest => false;

  Uri _page(int page, [Map<String, String>? q]) =>
      Uri.parse(page > 1 ? '$baseUrl/page/$page/' : '$baseUrl/').replace(queryParameters: q);

  MangaPage _parse(HtmlResponse res, String itemSel) {
    final items = <SourceManga>[];
    for (final el in res.document.querySelectorAll(itemSel)) {
      final a = el.querySelector('h2.blog-entry-title a, h2.search-entry-title a');
      final href = attrAbs(a, 'href', res.url);
      if (a == null || href == null) continue;
      items.add(SourceManga(
        url: href,
        title: clean(a.text),
        thumbnailUrl: imgAttr(el.querySelector('div.thumbnail img'), res.url),
      ));
    }
    return MangaPage(items, hasNextPage: res.document.querySelector('ul.page-numbers li a.next') != null);
  }

  @override
  Future<MangaPage> popular(int page) async => _parse(await fetchHtml(_page(page)), 'article.blog-entry');

  @override
  Future<MangaPage> latest(int page) => popular(page);

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    if (query.trim().isEmpty) return popular(page);
    final res = await fetchHtml(_page(page, {'s': query.trim()}));
    return _parse(res, 'article');
  }

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    final content = res.document.querySelector('div#content') ?? res.document.documentElement!;
    final title = clean(content.querySelector('.entry-title')?.text);
    if (title.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Judul seri tidak ditemukan.'));
    }
    return SourceMangaDetails(
      url: mangaUrl,
      title: title,
      thumbnailUrl: imgAttr(content.querySelector('div.thumbnail img'), res.url),
      description: clean(content.querySelector('div.entry-content')?.text),
      genres: [for (final a in content.querySelectorAll('li.meta-cat a, li.meta-category a')) clean(a.text)],
      status: SourceMangaStatus.completed,
      chapters: [SourceChapter(url: mangaUrl, name: tr('Bab'), number: 1)],
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    final pages = [
      for (final Element img in res.document.querySelectorAll('div.entry-content img'))
        if (imgAttr(img, res.url) case final u?) u,
    ];
    if (pages.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    }
    return pages;
  }
}
