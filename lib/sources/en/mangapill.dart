// Port Dart dari extension MangaPill milik keiyoushi/extensions-source
// (Apache-2.0): src/en/mangapill.

import 'package:html/dom.dart';

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';
import '../../core/i18n/strings.dart';

class MangaPillSource extends HttpSource {
  MangaPillSource({super.dio});

  @override
  String get id => 'en.mangapill';
  @override
  String get name => 'MangaPill';
  @override
  String get lang => 'en';
  @override
  String get defaultBaseUrl => 'https://mangapill.com';
  @override
  ContentWarning get contentWarning => ContentWarning.mixed;

  /// Populer = bagian "Trending" di beranda (tanpa halaman berikutnya).
  @override
  Future<MangaPage> popular(int page) async {
    if (page > 1) return const MangaPage([], hasNextPage: false);
    final res = await fetchHtml(Uri.parse('$baseUrl/'));
    Element? grid;
    for (final h in res.document.querySelectorAll('h4')) {
      if (h.text.contains('Trending')) {
        grid = h.parent?.querySelector(':scope > .grid');
        if (grid != null) break;
      }
    }
    return MangaPage(_cards(grid ?? res.document.documentElement!, res.url), hasNextPage: false);
  }

  @override
  Future<MangaPage> latest(int page) async {
    if (page > 1) return const MangaPage([], hasNextPage: false);
    final res = await fetchHtml(Uri.parse('$baseUrl/chapters'));
    return MangaPage(_cards(res.document.documentElement!, res.url), hasNextPage: false);
  }

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    final params = <String, List<String>>{
      'page': ['$page'],
      'q': [query.trim()],
      if (filters.single('status') case final v?) 'status': [v],
      if (filters.single('type') case final v?) 'type': [v],
      if (filters.multi('genre').isNotEmpty) 'genre': filters.multi('genre'),
    };
    final res = await fetchHtml(Uri.parse('$baseUrl/search').replace(queryParameters: params));
    return MangaPage(_cards(res.document.documentElement!, res.url),
        hasNextPage: res.document.querySelector('a.btn.btn-sm') != null);
  }

  List<SourceManga> _cards(Element root, Uri pageUrl) {
    final items = <SourceManga>[];
    for (final card in root.querySelectorAll('.grid > div:not([class])')) {
      final a = card.querySelector("a[href^='/manga/']");
      final title = clean(card.querySelector('div.line-clamp-2')?.text);
      final url = attrAbs(a, 'href', pageUrl);
      if (url == null || title.isEmpty) continue;
      final img = card.querySelector('img');
      final manga = SourceManga(
        url: url,
        title: title,
        thumbnailUrl: absUrl(pageUrl, img?.attributes['data-src'] ?? img?.attributes['src']),
      );
      if (!items.contains(manga)) items.add(manga);
    }
    return items;
  }

  @override
  Future<List<FilterDef>> filters() async => const [
        SelectFilterDef('status', 'Status (ignored with text search)', [
          FilterOption('All', ''),
          FilterOption('Publishing', 'publishing'),
          FilterOption('Finished', 'finished'),
          FilterOption('On Hiatus', 'on hiatus'),
          FilterOption('Discontinued', 'discontinued'),
          FilterOption('Not yet Published', 'not yet published'),
        ]),
        SelectFilterDef('type', 'Type', [
          FilterOption('All', ''),
          FilterOption('Manga', 'manga'),
          FilterOption('Novel', 'novel'),
          FilterOption('One-Shot', 'one-shot'),
          FilterOption('Doujinshi', 'doujinshi'),
          FilterOption('Manhwa', 'manhwa'),
          FilterOption('Manhua', 'manhua'),
          FilterOption('Oel', 'oel'),
        ]),
        MultiSelectFilterDef('genre', 'Genres', [
          FilterOption('Action', 'Action'),
          FilterOption('Adventure', 'Adventure'),
          FilterOption('Comedy', 'Comedy'),
          FilterOption('Drama', 'Drama'),
          FilterOption('Ecchi', 'Ecchi'),
          FilterOption('Fantasy', 'Fantasy'),
          FilterOption('Gender Bender', 'Gender Bender'),
          FilterOption('Harem', 'Harem'),
          FilterOption('Historical', 'Historical'),
          FilterOption('Horror', 'Horror'),
          FilterOption('Isekai', 'Isekai'),
          FilterOption('Josei', 'Josei'),
          FilterOption('Martial Arts', 'Martial Arts'),
          FilterOption('Mecha', 'Mecha'),
          FilterOption('Mystery', 'Mystery'),
          FilterOption('Psychological', 'Psychological'),
          FilterOption('Romance', 'Romance'),
          FilterOption('School Life', 'School Life'),
          FilterOption('Sci-Fi', 'Sci-Fi'),
          FilterOption('Seinen', 'Seinen'),
          FilterOption('Shoujo', 'Shoujo'),
          FilterOption('Shounen', 'Shounen'),
          FilterOption('Slice of Life', 'Slice of Life'),
          FilterOption('Sports', 'Sports'),
          FilterOption('Supernatural', 'Supernatural'),
          FilterOption('Tragedy', 'Tragedy'),
        ]),
      ];

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    return parseDetails(res.document, res.url, mangaUrl);
  }

  SourceMangaDetails parseDetails(Document doc, Uri pageUrl, String mangaUrl) {
    final title = clean(doc.querySelector('h1')?.text);
    if (title.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Judul tidak ditemukan.'));
    final statusText = clean(doc
            .querySelector('div.container > div:first-child > div:last-child > div:nth-child(3) > div:nth-child(2) > div')
            ?.text)
        .toLowerCase();
    final img = doc.querySelector('div.container > div:first-child > div:first-child > img');
    final genres = <String>{
      for (final g in doc.querySelectorAll('a[href*=genre]'))
        if (clean(g.text).isNotEmpty) clean(g.text),
    };
    return SourceMangaDetails(
      url: mangaUrl,
      title: title,
      description:
          nonPlaceholder(doc.querySelector('div.container > div:first-child > div:last-child > div:nth-child(2) > p')?.text),
      thumbnailUrl: absUrl(pageUrl, img?.attributes['data-src'] ?? img?.attributes['src']),
      status: statusText.contains('publishing')
          ? SourceMangaStatus.ongoing
          : statusText.contains('finished')
              ? SourceMangaStatus.completed
              : SourceMangaStatus.unknown,
      genres: genres.toList(),
      chapters: [
        for (final a in doc.querySelectorAll('#chapters > div > a'))
          if (attrAbs(a, 'href', pageUrl) case final href?)
            SourceChapter(url: href, name: clean(a.text), number: parseChapterNumber(clean(a.text))),
      ],
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    final pages = [
      for (final img in res.document.querySelectorAll('picture img'))
        if (absUrl(res.url, img.attributes['data-src'] ?? img.attributes['src']) case final url?) url,
    ];
    if (pages.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    return pages;
  }

  /// Gambar MangaPill ditolak tanpa Referer situs sendiri.
  @override
  Map<String, String> imageHeaders({String? referer}) => super.imageHeaders(referer: '$baseUrl/');
}
