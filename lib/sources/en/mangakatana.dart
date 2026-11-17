// Port Dart dari extension MangaKatana milik keiyoushi/extensions-source
// (Apache-2.0): src/en/mangakatana.

import 'package:html/dom.dart';

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';
import '../../core/i18n/strings.dart';

class MangaKatanaSource extends HttpSource {
  MangaKatanaSource({super.dio});

  @override
  String get id => 'en.mangakatana';
  @override
  String get name => 'MangaKatana';
  @override
  String get lang => 'en';
  @override
  String get defaultBaseUrl => 'https://mangakatana.com';
  @override
  ContentWarning get contentWarning => ContentWarning.mixed;

  /// Daftar "populer" situs ini urut abjad; dipakai urutan jumlah bab.
  @override
  Future<MangaPage> popular(int page) =>
      _list(Uri.parse('$baseUrl/manga/page/$page').replace(queryParameters: {'filter': '1', 'order': 'numc'}));

  @override
  Future<MangaPage> latest(int page) => _list(Uri.parse('$baseUrl/page/$page'));

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    final q = query.trim();
    if (q.isNotEmpty) {
      return _list(Uri.parse('$baseUrl/page/$page').replace(queryParameters: {
        'search': q,
        'search_by': filters.single('search_by') ?? 'book_name',
      }));
    }
    final genres = filters.multi('genre');
    final status = filters.single('status');
    return _list(Uri.parse('$baseUrl/manga/page/$page').replace(queryParameters: {
      'filter': '1',
      if (genres.isNotEmpty) 'include': genres.join('_'),
      if (genres.isNotEmpty) 'include_mode': filters.single('include_mode') ?? 'and',
      'order': filters.single('order') ?? 'latest',
      if (status != null) 'status': status,
      'chapters': '1',
    }));
  }

  Future<MangaPage> _list(Uri url) async {
    final res = await fetchHtml(url);
    final path = res.url.pathSegments;
    // Pencarian dengan satu hasil langsung dialihkan ke halaman seri.
    if (path.length >= 2 && path[0] == 'manga' && path[1] != 'page') {
      final title = clean(res.document.querySelector('h1.heading')?.text);
      if (title.isNotEmpty) {
        return MangaPage([
          SourceManga(url: res.url.toString(), title: title, thumbnailUrl: _cover(res.document, res.url)),
        ], hasNextPage: false);
      }
    }
    return parseList(res.document, res.url);
  }

  MangaPage parseList(Document doc, Uri pageUrl) {
    final items = <SourceManga>[];
    for (final item in doc.querySelectorAll('div#book_list > div.item')) {
      final a = item.querySelector('div.text > h3 > a');
      final url = attrAbs(a, 'href', pageUrl);
      final title = clean(a == null ? null : ownText(a));
      if (url == null || title.isEmpty) continue;
      items.add(SourceManga(url: url, title: title, thumbnailUrl: attrAbs(item.querySelector('img'), 'src', pageUrl)));
    }
    return MangaPage(items, hasNextPage: doc.querySelector('a.next.page-numbers') != null);
  }

  String? _cover(Document doc, Uri base) => attrAbs(doc.querySelector('div.media div.cover img'), 'src', base);

  @override
  Future<List<FilterDef>> filters() async => const [
        SelectFilterDef('search_by', 'Text search by', [
          FilterOption('Title', 'book_name'),
          FilterOption('Author', 'author'),
        ]),
        MultiSelectFilterDef('genre', 'Genres (ignored with text search)', [
          FilterOption('4-koma', '4-koma'),
          FilterOption('Action', 'action'),
          FilterOption('Adult', 'adult'),
          FilterOption('Adventure', 'adventure'),
          FilterOption('Comedy', 'comedy'),
          FilterOption('Drama', 'drama'),
          FilterOption('Ecchi', 'ecchi'),
          FilterOption('Fantasy', 'fantasy'),
          FilterOption('Harem', 'harem'),
          FilterOption('Historical', 'historical'),
          FilterOption('Horror', 'horror'),
          FilterOption('Isekai', 'isekai'),
          FilterOption('Josei', 'josei'),
          FilterOption('Martial Arts', 'martial-arts'),
          FilterOption('Mecha', 'mecha'),
          FilterOption('Mystery', 'mystery'),
          FilterOption('Psychological', 'psychological'),
          FilterOption('Romance', 'romance'),
          FilterOption('School Life', 'school-life'),
          FilterOption('Sci-fi', 'sci-fi'),
          FilterOption('Seinen', 'seinen'),
          FilterOption('Shoujo', 'shoujo'),
          FilterOption('Shounen', 'shounen'),
          FilterOption('Slice of Life', 'slice-of-life'),
          FilterOption('Sports', 'sports'),
          FilterOption('Supernatural', 'supernatural'),
          FilterOption('Tragedy', 'tragedy'),
          FilterOption('Webtoon', 'webtoon'),
        ]),
        SelectFilterDef('include_mode', 'Genre inclusion mode', [
          FilterOption('And', 'and'),
          FilterOption('Or', 'or'),
        ]),
        SelectFilterDef('order', 'Sort by', [
          FilterOption('Latest update', 'latest'),
          FilterOption('New manga', 'new'),
          FilterOption('A-Z', 'az'),
          FilterOption('Number of chapters', 'numc'),
        ]),
        SelectFilterDef('status', 'Status', [
          FilterOption('All', ''),
          FilterOption('Ongoing', '1'),
          FilterOption('Completed', '2'),
          FilterOption('Cancelled', '0'),
        ]),
      ];

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    return parseDetails(res.document, res.url, mangaUrl);
  }

  static final _date = RegExp(r'^([A-Za-z]{3})-(\d{1,2})-(\d{4})$');
  static const _months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

  static DateTime? _parseDate(String? raw) {
    final m = _date.firstMatch(clean(raw));
    if (m == null) return parseLooseDate(raw);
    final month = _months.indexOf(m.group(1)!.toLowerCase());
    if (month < 0) return null;
    return DateTime(int.parse(m.group(3)!), month + 1, int.parse(m.group(2)!));
  }

  SourceMangaDetails parseDetails(Document doc, Uri pageUrl, String mangaUrl) {
    final title = clean(doc.querySelector('h1.heading')?.text);
    if (title.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Judul tidak ditemukan.'));
    final alt = clean(doc.querySelector('.alt_name')?.text);
    final summary = clean(doc.querySelector('.summary > p')?.text);
    final author = doc.querySelectorAll('.author').map((e) => clean(e.text)).where((e) => e.isNotEmpty).join(', ');
    final description = [if (summary.isNotEmpty) summary, if (alt.isNotEmpty) 'Alt name(s): $alt'].join('\n\n');
    return SourceMangaDetails(
      url: mangaUrl,
      title: title,
      author: author.isEmpty ? null : author,
      description: description.isEmpty ? null : description,
      thumbnailUrl: _cover(doc, pageUrl),
      status: parseStatus(doc.querySelector('.value.status')?.text),
      genres: [for (final g in doc.querySelectorAll('.genres > a')) clean(g.text)],
      chapters: [
        for (final row in doc.querySelectorAll('tr'))
          if (row.querySelector('.chapter') != null)
            if (attrAbs(row.querySelector('a'), 'href', pageUrl) case final href?)
              SourceChapter(
                url: href,
                name: clean(row.querySelector('a')?.text),
                number: parseChapterNumber(clean(row.querySelector('a')?.text)),
                uploadedAt: _parseDate(row.querySelector('.update_time')?.text),
              ),
      ],
    );
  }

  static final _arrayName = RegExp('data-src[\'"],\\s*(\\w+)');
  static final _url = RegExp("'([^']*)'");

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    final pages = parsePages(res.body);
    if (pages.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    return pages;
  }

  List<String> parsePages(String html) {
    final name = _arrayName.firstMatch(html)?.group(1);
    if (name == null) return const [];
    final array = RegExp('var $name=\\[([^\\[]*)\\]').firstMatch(html)?.group(1);
    if (array == null) return const [];
    return [for (final m in _url.allMatches(array)) m.group(1)!];
  }
}
