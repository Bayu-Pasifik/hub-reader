// Port Dart dari extension Mangalay milik keiyoushi/extensions-source
// (Apache-2.0): src/id/mangalay. Blogspot; satu daftar tanpa pencarian server.

import '../../core/i18n/strings.dart';
import '../filters.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class MangalaySource extends HttpSource {
  MangalaySource({super.dio});

  @override
  String get id => 'id.mangalay';
  @override
  String get name => 'Mangalay';
  @override
  String get lang => 'id';
  @override
  String get defaultBaseUrl => 'https://mangalay.blogspot.com';
  @override
  ContentWarning get contentWarning => ContentWarning.safe;

  @override
  Future<MangaPage> popular(int page) async {
    if (page > 1) return const MangaPage([], hasNextPage: false);
    final res = await fetchHtml(baseUri.replace(path: '/2013/04/daftar-baca-komik_20.html'));
    final items = <SourceManga>[];
    for (final table in res.document.querySelectorAll('.post-body table')) {
      final href = attrAbs(table.querySelector('a'), 'href', res.url);
      if (href == null) continue;
      items.add(SourceManga(
        url: href,
        title: clean(table.querySelector('.tr-caption')?.text),
        thumbnailUrl: attrAbs(table.querySelector('img'), 'src', res.url),
      ));
    }
    return MangaPage(items, hasNextPage: false);
  }

  @override
  Future<MangaPage> latest(int page) => popular(page);

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    final q = query.trim().toLowerCase();
    final all = await popular(page);
    return MangaPage([
      for (final m in all.items)
        if (m.title.toLowerCase().contains(q)) m,
    ], hasNextPage: false);
  }

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    final chapters = <SourceChapter>[];
    for (final a in res.document.querySelectorAll('.post-body span > a')) {
      final href = attrAbs(a, 'href', res.url);
      if (href == null) continue;
      final name = clean(a.querySelector('b')?.text);
      if (name.isEmpty) continue;
      chapters.add(SourceChapter(url: href, name: name, number: parseChapterNumber(name)));
    }
    final title = clean(res.document.querySelector('h3.post-title, h1.post-title')?.text);
    return SourceMangaDetails(
      url: mangaUrl,
      title: title.isEmpty ? tr('Tanpa judul') : title,
      chapters: chapters,
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    final imgs = res.document.querySelectorAll('.separator img').toList();
    if (imgs.isNotEmpty) imgs.removeLast();
    final pages = [
      for (final img in imgs)
        if (attrAbs(img, 'src', res.url) case final u?) u,
    ];
    if (pages.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    }
    return pages;
  }
}
