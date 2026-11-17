// Port Dart dari extension MG Komik milik keiyoushi/extensions-source
// (Apache-2.0): src/id/mgkomik.

import 'package:html/dom.dart';

import '../../core/i18n/strings.dart';
import '../filters.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class MgKomikSource extends HttpSource {
  MgKomikSource({super.dio});

  @override
  String get id => 'id.mgkomik';
  @override
  String get name => 'MG Komik';
  @override
  String get lang => 'id';
  @override
  String get defaultBaseUrl => 'https://web1.mgkomik.cc';
  @override
  ContentWarning get contentWarning => ContentWarning.safe;

  Future<MangaPage> _list(Uri url) async {
    final res = await fetchHtml(url);
    final items = <SourceManga>[];
    final seen = <String>{};
    for (final card in res.document.querySelectorAll('.manga-card')) {
      final link = card.localName == 'a' ? card : card.querySelector('a[href]');
      final href = attrAbs(link, 'href', res.url);
      if (href == null || !seen.add(href)) continue;
      final img = card.querySelector('img.manga-cover');
      final title = clean(img?.attributes['alt'] ?? card.querySelector('.manga-title')?.text);
      if (title.isEmpty) continue;
      items.add(SourceManga(url: href, title: title, thumbnailUrl: attrAbs(img, 'src', res.url)));
    }
    final hasNext = res.document
        .querySelectorAll('.pagination a.page-link')
        .any((a) => a.text.toLowerCase().contains('next'));
    return MangaPage(items, hasNextPage: hasNext);
  }

  Uri _browse(int page, String order) =>
      Uri.parse('$baseUrl/komik/').replace(queryParameters: {'filter': '', 'order_by': order, 'page': '$page'});

  @override
  Future<MangaPage> popular(int page) => _list(_browse(page, 'trending'));

  @override
  Future<MangaPage> latest(int page) => _list(_browse(page, 'latest'));

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) {
    final q = query.trim();
    if (q.isEmpty) return latest(page);
    return _list(Uri.parse('$baseUrl/search/').replace(queryParameters: {'q': q, 'page': '$page'}));
  }

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    final doc = res.document;
    final title = clean(doc.querySelector('.manga-title')?.text);
    if (title.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Judul seri tidak ditemukan.'));
    }
    final chapters = <SourceChapter>[];
    for (final item in doc.querySelectorAll('#chapterList .chapter-list-item')) {
      final a = item.querySelector('a.chapter-link');
      final href = attrAbs(a, 'href', res.url);
      if (a == null || href == null) continue;
      final name = clean(a.querySelector('.chapter-number')?.text ?? a.text);
      chapters.add(SourceChapter(
        url: href,
        name: name,
        number: parseChapterNumber(name),
        uploadedAt: parseLooseDate(clean(a.querySelector('.chapter-date')?.text)),
      ));
    }
    final Element? desc = doc.querySelector('#sinopsisContainer p, .manga-description .sinopsis-wrapper p');
    return SourceMangaDetails(
      url: mangaUrl,
      title: title,
      thumbnailUrl: attrAbs(doc.querySelector('img.manga-cover-large'), 'src', res.url),
      description: clean(desc?.text),
      genres: [for (final g in doc.querySelectorAll('.genre-tag')) clean(g.text)],
      status: doc.querySelector('.status-Ongoing, .status-ongoing') != null
          ? SourceMangaStatus.ongoing
          : doc.querySelector('.status-Completed, .status-completed') != null
              ? SourceMangaStatus.completed
              : SourceMangaStatus.unknown,
      chapters: chapters,
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    final pages = [
      for (final img in res.document.querySelectorAll('.reading-content img[src]'))
        if (attrAbs(img, 'src', res.url) case final u?) u,
    ];
    if (pages.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    }
    return pages;
  }
}
