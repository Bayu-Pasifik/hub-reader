// Port Dart dari extension Weeb Central milik keiyoushi/extensions-source
// (Apache-2.0): src/en/weebcentral.

import 'package:html/dom.dart';

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';
import '../../core/i18n/strings.dart';

class WeebCentralSource extends HttpSource {
  WeebCentralSource({super.dio});

  @override
  String get id => 'en.weebcentral';
  @override
  String get name => 'Weeb Central';
  @override
  String get lang => 'en';
  @override
  String get defaultBaseUrl => 'https://weebcentral.com';
  @override
  ContentWarning get contentWarning => ContentWarning.mixed;
  @override
  int get requestsPerSecond => 1;

  /// Jumlah hasil per permintaan (parameter `limit` situs diabaikan).
  static const fetchLimit = 32;

  @override
  Future<MangaPage> popular(int page) => _search(page, '', const {'sort': 'Popularity'});

  @override
  Future<MangaPage> latest(int page) => _search(page, '', const {'sort': 'Latest Updates'});

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) => _search(page, query, {
        for (final key in const ['sort', 'order', 'official', 'anime', 'adult'])
          if (filters.single(key) case final v?) key: v,
      }, filters: filters);

  static final _excluded = RegExp(r'[!#:(),-]');

  Future<MangaPage> _search(int page, String query, Map<String, String> params,
      {FilterValues filters = FilterValues.empty}) async {
    final pairs = <String>[
      'text=${Uri.encodeQueryComponent(query.replaceAll(_excluded, ' ').trim())}',
      'sort=${Uri.encodeQueryComponent(params['sort'] ?? 'Best Match')}',
      'order=${Uri.encodeQueryComponent(params['order'] ?? 'Descending')}',
      'official=${params['official'] ?? 'Any'}',
      'anime=${params['anime'] ?? 'Any'}',
      'adult=${params['adult'] ?? 'Any'}',
      for (final v in filters.multi('status')) 'included_status=${Uri.encodeQueryComponent(v)}',
      for (final v in filters.multi('type')) 'included_type=${Uri.encodeQueryComponent(v)}',
      for (final v in filters.multi('tag')) 'included_tag=${Uri.encodeQueryComponent(v)}',
      'limit=$fetchLimit',
      'offset=${(page - 1) * fetchLimit}',
      'display_mode=${Uri.encodeQueryComponent('Full Display')}',
    ];
    final res = await fetchHtml(Uri.parse('$baseUrl/search/data?${pairs.join('&')}'));
    return parseList(res.document, res.url);
  }

  MangaPage parseList(Document doc, Uri pageUrl) {
    final items = <SourceManga>[];
    for (final a in doc.querySelectorAll('article > section > a')) {
      final url = attrAbs(a, 'href', pageUrl);
      if (url == null) continue;
      String? title;
      for (final d in a.querySelectorAll('div')) {
        if (!d.attributes.containsKey('class') && clean(d.text).isNotEmpty) title = clean(d.text);
      }
      title ??= clean(a.querySelector('img')?.attributes['alt']?.replaceAll(RegExp(r'\s*cover$'), ''));
      if (title.isEmpty) continue;
      final manga = SourceManga(url: url, title: title, thumbnailUrl: _cover(a, pageUrl));
      if (!items.contains(manga)) items.add(manga);
    }
    return MangaPage(items, hasNextPage: doc.querySelector('button') != null);
  }

  String? _cover(Element e, Uri base) {
    final img = e.querySelector('img');
    final src = img?.attributes['src'];
    if (src != null && src.isNotEmpty) return absUrl(base, src);
    return absUrl(base, e.querySelector('source')?.attributes['srcset']);
  }

  @override
  Future<List<FilterDef>> filters() async => [
        const SelectFilterDef('sort', 'Sort', [
          FilterOption('Best Match', 'Best Match'),
          FilterOption('Alphabet', 'Alphabet'),
          FilterOption('Popularity', 'Popularity'),
          FilterOption('Subscribers', 'Subscribers'),
          FilterOption('Recently Added', 'Recently Added'),
          FilterOption('Latest Updates', 'Latest Updates'),
        ]),
        const SelectFilterDef('order', 'Sort Order', [
          FilterOption('Descending', 'Descending'),
          FilterOption('Ascending', 'Ascending'),
        ]),
        const SelectFilterDef('official', 'Official Translation', [
          FilterOption('Any', 'Any'),
          FilterOption('True', 'True'),
          FilterOption('False', 'False'),
        ]),
        const SelectFilterDef('anime', 'Anime Adaptation', [
          FilterOption('Any', 'Any'),
          FilterOption('True', 'True'),
          FilterOption('False', 'False'),
        ]),
        const SelectFilterDef('adult', 'Adult Content', [
          FilterOption('Any', 'Any'),
          FilterOption('True', 'True'),
          FilterOption('False', 'False'),
        ]),
        const MultiSelectFilterDef('status', 'Series Status', [
          FilterOption('Ongoing', 'Ongoing'),
          FilterOption('Complete', 'Complete'),
          FilterOption('Hiatus', 'Hiatus'),
          FilterOption('Canceled', 'Canceled'),
        ]),
        const MultiSelectFilterDef('type', 'Series Type', [
          FilterOption('Manga', 'Manga'),
          FilterOption('Manhwa', 'Manhwa'),
          FilterOption('Manhua', 'Manhua'),
          FilterOption('OEL', 'OEL'),
        ]),
        MultiSelectFilterDef('tag', 'Tags', [
          for (final t in _tags) FilterOption(t, t),
        ]),
      ];

  static const _tags = [
    'Action', 'Adventure', 'Comedy', 'Doujinshi', 'Drama', 'Ecchi', 'Fantasy', 'Gender Bender', 'Harem',
    'Historical', 'Horror', 'Isekai', 'Josei', 'Martial Arts', 'Mature', 'Mecha', 'Mystery', 'Psychological',
    'Romance', 'School Life', 'Sci-fi', 'Seinen', 'Shoujo', 'Shoujo Ai', 'Shounen', 'Shounen Ai',
    'Slice of Life', 'Sports', 'Supernatural', 'Tragedy', 'Yaoi', 'Yuri', 'Other',
  ];

  /// `<li>` yang `<strong>`-nya memuat [label] (padanan `li:has(strong:contains(x))`).
  static Iterable<Element> _items(Element root, String label) =>
      root.querySelectorAll('li').where((li) => li.querySelectorAll('strong').any((s) => s.text.contains(label)));

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final url = Uri.parse(mangaUrl);
    final segments = url.pathSegments;
    final seriesId = segments.length > 1 ? segments[1] : '';
    final res = await fetchHtml(url);
    final chaptersRes = await fetchHtml(Uri.parse('$baseUrl/series/$seriesId/full-chapter-list'));
    return parseDetails(res.document, chaptersRes.document, res.url, mangaUrl);
  }

  SourceMangaDetails parseDetails(Document doc, Document chaptersDoc, Uri pageUrl, String mangaUrl) {
    final sections = doc.querySelectorAll('section[x-data] > section');
    if (sections.length < 2) throw SourceException(SourceErrorKind.parse, detail: tr('Judul tidak ditemukan.'));
    final left = sections[0];
    final right = sections[1];
    final title = clean(right.querySelector('h1')?.text);
    if (title.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Judul tidak ditemukan.'));

    final description = StringBuffer();
    final about = _items(right, 'Description').firstOrNull?.querySelector('p');
    if (about != null) description.write(clean(about.text));
    final alt = _items(right, 'Associated Name').firstOrNull?.querySelectorAll('li') ?? const [];
    if (alt.isNotEmpty) {
      description.write('${description.isEmpty ? '' : '\n\n'}Associated Name(s):');
      for (final a in alt) {
        description.write('\n- ${clean(a.text)}');
      }
    }

    final statusText = clean(_items(left, 'Status').firstOrNull?.querySelector('a')?.text).toLowerCase();
    final chapterLinks = chaptersDoc.querySelectorAll('div[x-data] > a');
    final seasonRegex = RegExp(r'(Season|S)\s*\d+', caseSensitive: false);
    var indexed = false;
    final chapters = <SourceChapter>[];
    for (var i = 0; i < chapterLinks.length; i++) {
      final a = chapterLinks[i];
      final href = attrAbs(a, 'href', pageUrl);
      if (href == null) continue;
      final nm = clean(a.querySelector('span.flex > span')?.text);
      if (seasonRegex.hasMatch(nm)) indexed = true;
      final official = a.querySelectorAll('img').any((img) => (img.attributes['src'] ?? '').toLowerCase().contains('official'));
      chapters.add(SourceChapter(
        url: href,
        name: nm,
        number: indexed ? (chapterLinks.length - i).toDouble() : parseChapterNumber(nm),
        scanlator: official ? 'Official' : null,
        uploadedAt: DateTime.tryParse(a.querySelector('time[datetime]')?.attributes['datetime'] ?? '')?.toLocal(),
      ));
    }

    return SourceMangaDetails(
      url: mangaUrl,
      title: title,
      author: nonPlaceholder(
          _items(left, 'Author').firstOrNull?.querySelectorAll('a').map((e) => clean(e.text)).join(', ')),
      description: description.isEmpty ? null : description.toString(),
      thumbnailUrl: _cover(left, pageUrl),
      status: statusText == 'ongoing'
          ? SourceMangaStatus.ongoing
          : statusText == 'complete'
              ? SourceMangaStatus.completed
              : statusText == 'hiatus'
                  ? SourceMangaStatus.hiatus
                  : statusText == 'canceled'
                      ? SourceMangaStatus.cancelled
                      : SourceMangaStatus.unknown,
      genres: [
        for (final li in left.querySelectorAll('li'))
          if (li.querySelectorAll('strong').any((s) => s.text.contains('Tag') || s.text.contains('Type')))
            for (final a in li.querySelectorAll('a')) clean(a.text),
      ],
      chapters: chapters,
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final url = Uri.parse(chapter.url);
    final imagesUrl = url.replace(
      pathSegments: [...url.pathSegments.where((s) => s.isNotEmpty), 'images'],
      queryParameters: {'is_prev': 'False', 'reading_style': 'long_strip'},
    );
    final res = await fetchHtml(imagesUrl);
    final pages = [
      for (final img in res.document.querySelectorAll('section#chapter-images > img, section[x-data] > img'))
        if (attrAbs(img, 'src', res.url) case final src?) src,
    ];
    if (pages.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    return pages;
  }
}
