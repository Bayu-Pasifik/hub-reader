// Port Dart dari extension Mangafreak milik keiyoushi/extensions-source
// (Apache-2.0): src/en/mangafreak.

import 'package:html/dom.dart';

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';
import '../../core/i18n/strings.dart';

class MangafreakSource extends HttpSource {
  MangafreakSource({super.dio});

  @override
  String get id => 'en.mangafreak';
  @override
  String get name => 'Mangafreak';
  @override
  String get lang => 'en';
  @override
  String get defaultBaseUrl => 'https://ww3.mangafreak.me';
  @override
  ContentWarning get contentWarning => ContentWarning.mixed;

  static const _genres = [
    'Act', 'Adult', 'Adventure', 'Ancients', 'Animated', 'Comedy', 'Demons', 'Drama', 'Ecchi', 'Fantasy',
    'Gender Bender', 'Harem', 'Horror', 'Josei', 'Magic', 'Martial Arts', 'Mature', 'Mecha', 'Military',
    'Mystery', 'One Shot', 'Psychological', 'Romance', 'School Life', 'Sci Fi', 'Seinen', 'Shoujo', 'Shoujoai',
    'Shounen', 'Shounenai', 'Slice Of Life', 'Smut', 'Sports', 'Super Power', 'Supernatural', 'Tragedy',
    'Vampire', 'Yaoi', 'Yuri',
  ];

  @override
  Future<MangaPage> popular(int page) async {
    final res = await fetchHtml(Uri.parse('$baseUrl/Genre/All/$page'));
    return MangaPage(_cards(res.document.querySelectorAll('div.ranking_item'), res.url, 'a'),
        hasNextPage: res.document.querySelector('a.next_p') != null);
  }

  @override
  Future<MangaPage> latest(int page) async {
    final res = await fetchHtml(Uri.parse(page == 1 ? '$baseUrl/Latest_Releases' : '$baseUrl/Latest_Releases/$page'));
    final items = _cards(res.document.querySelectorAll('div.latest_releases_item'), res.url, 'a', fixThumb: true);
    return MangaPage(items, hasNextPage: res.document.querySelector('a.next_p') != null);
  }

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    final segments = <String>[];
    final q = query.trim();
    if (q.isNotEmpty) segments.addAll(['Find', q]);
    final picked = filters.multi('genre');
    if (picked.isNotEmpty) segments.addAll(['Genre', _genres.map((g) => picked.contains(g) ? '1' : '0').join()]);
    if (filters.single('type') case final v?) segments.addAll(['Type', v]);
    if (filters.single('status') case final v?) segments.addAll(['Status', v]);
    if (segments.isEmpty) return popular(page);
    final res = await fetchHtml(baseUri.replace(pathSegments: segments));
    return MangaPage(_cards(res.document.querySelectorAll('div.manga_search_item, div.mangaka_search_item'), res.url, 'h3 a, h5 a'),
        hasNextPage: false);
  }

  List<SourceManga> _cards(Iterable<Element> elements, Uri pageUrl, String linkSelector, {bool fixThumb = false}) {
    final items = <SourceManga>[];
    for (final e in elements) {
      final a = e.querySelector(linkSelector);
      final url = attrAbs(a, 'href', pageUrl);
      final title = clean(a?.text);
      if (url == null || title.isEmpty) continue;
      var thumb = attrAbs(e.querySelector('img'), 'src', pageUrl);
      if (fixThumb && thumb != null) {
        final u = Uri.parse(thumb);
        if (u.pathSegments.length >= 2 && u.pathSegments.first == 'mini_images') {
          thumb = u.replace(pathSegments: ['manga_images', '${u.pathSegments[1]}.jpg']).toString();
        }
      }
      final manga = SourceManga(url: url, title: title, thumbnailUrl: thumb);
      if (!items.contains(manga)) items.add(manga);
    }
    return items;
  }

  @override
  Future<List<FilterDef>> filters() async => [
        MultiSelectFilterDef('genre', 'Genres (needs a search text or filter)', [
          for (final g in _genres) FilterOption(g, g),
        ]),
        const SelectFilterDef('type', 'Manga Type', [
          FilterOption('Both', ''),
          FilterOption('Manga', '2'),
          FilterOption('Manhwa', '1'),
        ]),
        const SelectFilterDef('status', 'Manga Status', [
          FilterOption('Both', ''),
          FilterOption('Completed', '1'),
          FilterOption('Ongoing', '2'),
        ]),
      ];

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    return parseDetails(res.document, res.url, mangaUrl);
  }

  static final _number = RegExp(r'(\d+)(\.\d+|[a-i]+\b)?');
  static final _date = RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2})$');

  static double? _chapterNumber(String name) {
    final m = _number.firstMatch(name);
    if (m == null) return null;
    final suffix = m.group(2);
    if (suffix == null || suffix.isEmpty || suffix.startsWith('.')) return double.tryParse(m.group(0)!);
    final fraction = suffix.codeUnits.map((c) => c - 'a'.codeUnitAt(0) + 1).join();
    return (double.tryParse(m.group(1)!) ?? 0) + (double.tryParse('0.$fraction') ?? 0);
  }

  SourceMangaDetails parseDetails(Document doc, Uri pageUrl, String mangaUrl) {
    final data = doc.querySelector('div.manga_series_data');
    final title = clean(data?.querySelector('h1, h5')?.text);
    if (title.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Judul tidak ditemukan.'));
    final divs = [for (final d in data!.children) if (d.localName == 'div') clean(d.text)];
    String? labeled(String prefix) {
      for (final d in divs) {
        if (d.toLowerCase().startsWith(prefix)) return nonPlaceholder(d.substring(prefix.length).replaceFirst(RegExp(r'^s*:?s*'), ''));
      }
      return null;
    }

    final statusLine = divs.firstWhere((d) => d.toLowerCase().startsWith('this is'), orElse: () => '');
    final rows = <SourceChapter>[];
    for (final tr in doc.querySelectorAll('div.manga_series_list tr')) {
      final a = tr.querySelector('a');
      final href = attrAbs(a, 'href', pageUrl);
      if (href == null) continue;
      final name = clean(tr.querySelector('td')?.text);
      final date = _date.firstMatch(clean(tr.querySelectorAll('td').elementAtOrNull(1)?.text));
      rows.add(SourceChapter(
        url: href,
        name: name,
        number: _chapterNumber(name),
        uploadedAt: date == null
            ? null
            : DateTime.utc(int.parse(date.group(1)!), int.parse(date.group(2)!), int.parse(date.group(3)!)),
      ));
    }
    return SourceMangaDetails(
      url: mangaUrl,
      title: title,
      author: labeled('written by'),
      artist: labeled('illustrated by'),
      description: nonPlaceholder(doc.querySelector('div.manga_series_description p')?.text),
      thumbnailUrl: attrAbs(doc.querySelector('div.manga_series_image img'), 'src', pageUrl),
      status: parseStatus(statusLine.replaceFirst(RegExp('^this is', caseSensitive: false), '').replaceAll('series', '')),
      genres: [for (final g in doc.querySelectorAll('div.series_sub_genre_list a')) clean(g.text)],
      chapters: rows.reversed.toList(),
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    final pages = [
      for (final img in res.document.querySelectorAll('img#gohere[src]'))
        if (attrAbs(img, 'src', res.url) case final src?) src,
    ];
    if (pages.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    return pages;
  }
}
