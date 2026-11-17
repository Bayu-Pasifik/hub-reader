// Port Dart dari extension TCB Scans milik keiyoushi/extensions-source
// (Apache-2.0): src/en/tcbscans.

import 'package:html/dom.dart';

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';
import '../../core/i18n/strings.dart';

class TcbScansSource extends HttpSource {
  TcbScansSource({super.dio});

  @override
  String get id => 'en.tcbscans';
  @override
  String get name => 'TCB Scans';
  @override
  String get lang => 'en';
  @override
  String get defaultBaseUrl => 'https://tcbonepiecechapters.com';
  @override
  ContentWarning get contentWarning => ContentWarning.safe;
  @override
  bool get supportsLatest => false;

  /// Situs ini hanya punya satu halaman daftar proyek.
  @override
  Future<MangaPage> popular(int page) async {
    if (page > 1) return const MangaPage([], hasNextPage: false);
    final res = await fetchHtml(Uri.parse('$baseUrl/projects'));
    return MangaPage(parseList(res.document, res.url), hasNextPage: false);
  }

  @override
  Future<MangaPage> latest(int page) => popular(page);

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    final all = await popular(page);
    final q = query.trim().toLowerCase();
    return MangaPage([
      for (final m in all.items)
        if (m.title.toLowerCase().contains(q)) m,
    ], hasNextPage: false);
  }

  List<SourceManga> parseList(Document doc, Uri pageUrl) {
    final items = <SourceManga>[];
    for (final card in doc.querySelectorAll('div.bg-card')) {
      final a = card.querySelector('a[href].text-white');
      final url = attrAbs(a, 'href', pageUrl);
      final title = clean(a?.text);
      if (url == null || title.isEmpty) continue;
      items.add(SourceManga(url: url, title: title, thumbnailUrl: attrAbs(card.querySelector('img'), 'src', pageUrl)));
    }
    return items;
  }

  static final _trailingNumber = RegExp(r'\d+.?\d+$');

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    return parseDetails(res.document, res.url, mangaUrl);
  }

  SourceMangaDetails parseDetails(Document doc, Uri pageUrl, String mangaUrl) {
    final head = doc.querySelector('div.order-1');
    final title = clean(head?.querySelector('h1')?.text);
    if (title.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Judul tidak ditemukan.'));
    final chapters = <SourceChapter>[];
    for (final a in doc.querySelectorAll('div.grid a')) {
      final href = attrAbs(a, 'href', pageUrl);
      if (href == null) continue;
      final heading = clean(a
          .querySelectorAll('div.font-bold')
          .where((e) => !e.classes.contains('flex'))
          .map((e) => e.text)
          .join(' '));
      final sub = clean(a.querySelector('.text-gray-500')?.text);
      final number = _trailingNumber.firstMatch(heading)?.group(0);
      final base = number != null ? 'Chapter $number' : heading;
      chapters.add(SourceChapter(
        url: href,
        name: sub.isEmpty ? base : '$base: $sub',
        number: number != null ? double.tryParse(number) : parseChapterNumber(heading),
      ));
    }
    return SourceMangaDetails(
      url: mangaUrl,
      title: title,
      description: nonPlaceholder(head?.querySelector('p')?.text),
      thumbnailUrl: attrAbs(head?.querySelector('img'), 'src', pageUrl),
      status: SourceMangaStatus.unknown,
      genres: const [],
      chapters: chapters,
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    final pages = [
      for (final img in res.document.querySelectorAll('picture img, .image-container img'))
        if (attrAbs(img, 'src', res.url) case final url?) url,
    ];
    if (pages.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    return pages;
  }
}
