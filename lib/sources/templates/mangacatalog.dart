// Port Dart dari template MangaCatalog milik keiyoushi/extensions-source
// (Apache-2.0): lib-multisrc/mangacatalog, plus override situs
// ReadBerserk/ReadOPM (tabel bab) dan Tower of God (gambar Blogger).
//
// Jaringan situs "satu franchise" (readonepiece.com, readsnk.com, dst.).
// Tiap situs hanya punya beberapa judul yang daftarnya ditulis tangan di
// Kotlin; generator katalog menyalinnya ke `options.titles`.

import 'package:html/dom.dart';

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

enum MangaCatalogLayout { grid, table, blogger }

MangaCatalogLayout mangaCatalogLayoutFrom(String? raw) => switch (raw) {
      'table' => MangaCatalogLayout.table,
      'blogger' => MangaCatalogLayout.blogger,
      _ => MangaCatalogLayout.grid,
    };

class MangaCatalogSource extends HttpSource {
  MangaCatalogSource({
    required this.id,
    required this.name,
    required String baseUrl,
    required this.lang,
    required this.titles,
    this.contentWarning = ContentWarning.safe,
    this.layout = MangaCatalogLayout.grid,
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

  /// (judul, path relatif baseUrl), mis. ("One Piece", "/manga/one-piece/").
  final List<(String, String)> titles;

  final MangaCatalogLayout layout;

  @override
  bool get supportsLatest => false;

  List<SourceManga> get _all {
    final seen = <String>{};
    final items = [
      for (final (title, path) in titles)
        if (seen.add(path)) SourceManga(url: '$baseUrl$path', title: title),
    ]..sort((a, b) => a.title.compareTo(b.title));
    return items;
  }

  @override
  Future<MangaPage> popular(int page) async => MangaPage(page == 1 ? _all : const [], hasNextPage: false);

  @override
  Future<MangaPage> latest(int page) => popular(page);

  /// Judul romaji sering hanya ada di slug, jadi slug ikut dicocokkan.
  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    if (page > 1) return const MangaPage([], hasNextPage: false);
    final q = query.trim().toLowerCase();
    final slugQuery = q.replaceAll(' ', '-');
    return MangaPage([
      for (final m in _all)
        if (m.title.toLowerCase().contains(q) || Uri.parse(m.url).path.toLowerCase().contains(slugQuery)) m,
    ], hasNextPage: false);
  }

  String? _titleFor(Uri url) {
    String norm(String p) => p.endsWith('/') ? p.substring(0, p.length - 1) : p;
    final path = norm(url.path);
    for (final (title, p) in titles) {
      if (norm(Uri.parse('$baseUrl$p').path) == path) return title;
    }
    return null;
  }

  // =========================== Detail ===========================

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    return parseDetails(res.document, Uri.parse(mangaUrl));
  }

  SourceMangaDetails parseDetails(Document doc, Uri mangaUrl) {
    String? description;
    String? thumb;
    String? title;
    switch (layout) {
      case MangaCatalogLayout.table:
        title = clean(doc.querySelector('h2 > span')?.text);
        description = nonPlaceholder(doc.querySelectorAll('div.card-body > p').map((p) => p.text).join(' '));
        thumb = attrAbs(doc.querySelector('.card-img-right'), 'src', mangaUrl);
      case MangaCatalogLayout.blogger:
        description = nonPlaceholder(doc.querySelector('meta[property="og:description"]')?.attributes['content']);
        thumb = doc.querySelector('meta[property="og:image"]')?.attributes['content'];
      case MangaCatalogLayout.grid:
        // Label "Description" lalu teksnya di elemen saudara berikutnya.
        final label = doc
            .querySelectorAll('div')
            .where((d) => d.children.isEmpty && clean(d.text) == 'Description')
            .firstOrNull;
        description = nonPlaceholder(label?.nextElementSibling?.text);
        thumb = attrAbs(doc.querySelector('div.flex > img'), 'src', mangaUrl);
        title = clean(doc.querySelector('div.container > h1')?.text);
    }
    final chapters = parseChapters(doc, mangaUrl);
    return SourceMangaDetails(
      url: mangaUrl.toString(),
      title: _titleFor(mangaUrl) ?? (title == null || title.isEmpty ? name : title),
      thumbnailUrl: thumb,
      description: description,
      chapters: chapters,
    );
  }

  static final _togChapter = RegExp(r'chapter-(\d+)');

  List<SourceChapter> parseChapters(Document doc, Uri pageUrl) {
    final chapters = <SourceChapter>[];
    void add(String? url, String name, {DateTime? date, double? number}) {
      if (url == null || name.isEmpty || chapters.any((c) => c.url == url)) return;
      chapters.add(SourceChapter(url: url, name: name, number: number ?? parseChapterNumber(name), uploadedAt: date));
    }

    switch (layout) {
      case MangaCatalogLayout.table:
        for (final row in doc.querySelectorAll('tbody > tr')) {
          final cells = row.querySelectorAll('td');
          if (cells.isEmpty) continue;
          add(attrAbs(row.querySelector('a.btn-primary'), 'href', pageUrl), clean(cells.first.text),
              date: cells.length > 1 ? parseLooseDate(cells[1].text) : null);
        }
      case MangaCatalogLayout.blogger:
        for (final a in doc.querySelectorAll('a[href*="/manga/tower-of-god-chapter-"]')) {
          final url = attrAbs(a, 'href', pageUrl);
          final n = _togChapter.firstMatch(url ?? '')?.group(1);
          if (n != null) add(url, 'Chapter $n', number: double.parse(n));
        }
      case MangaCatalogLayout.grid:
        for (final row in doc.querySelectorAll('div.bg-bg-secondary > div.grid')) {
          final link = row.querySelector('.col-span-4 > a') ?? row.querySelector('a[href]');
          if (link == null) continue;
          final subtitle = clean(row.querySelector('div.text-xs')?.text);
          final text = clean(link.text);
          add(attrAbs(link, 'href', pageUrl), subtitle.isEmpty ? text : '$text - $subtitle');
        }
    }
    return chapters;
  }

  // =========================== Halaman ===========================

  static final _blogger = RegExp(r'blogger\.googleusercontent\.com|bp\.blogspot\.com');

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    final pages = parsePages(res.document, res.url);
    if (pages.isEmpty) throw const SourceException(SourceErrorKind.parse, detail: 'Gambar bab tidak ditemukan.');
    return pages;
  }

  List<String> parsePages(Document doc, Uri pageUrl) {
    final seen = <String>{};
    if (layout == MangaCatalogLayout.blogger) {
      return [
        for (final img in doc.querySelectorAll('img'))
          for (final attr in const ['data-src', 'src'])
            if (absUrl(pageUrl, img.attributes[attr]) case final url?
                when _blogger.hasMatch(url) && seen.add(url))
              url,
      ];
    }
    return [
      for (final img in doc.querySelectorAll('img.js-page, img.pages__img'))
        // Halaman pertama di src, sisanya lazy-load di data-src.
        if (absUrl(pageUrl, img.attributes['data-src']) ?? absUrl(pageUrl, img.attributes['src']) case final url?
            when !url.startsWith('data:') && seen.add(url))
          url,
    ];
  }
}
