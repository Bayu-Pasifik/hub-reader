// Port Dart dari extension TheManga milik keiyoushi/extensions-source
// (Apache-2.0): src/id/themanga.

import 'package:html/dom.dart';

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class TheMangaSource extends HttpSource {
  TheMangaSource({super.dio});

  @override
  String get id => 'id.themanga';
  @override
  String get name => 'TheManga';
  @override
  String get lang => 'id';
  @override
  String get defaultBaseUrl => 'https://themanga.site';
  @override
  ContentWarning get contentWarning => ContentWarning.mixed;

  @override
  Future<MangaPage> popular(int page) =>
      _list(Uri.parse('$baseUrl/').replace(queryParameters: {'q': '', 'sort': 'popular', 'page': '$page'}));

  @override
  Future<MangaPage> latest(int page) =>
      _list(Uri.parse('$baseUrl/').replace(queryParameters: {'q': '', 'sort': 'latest_update', 'page': '$page'}));

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) => _list(
        Uri.parse('$baseUrl/explore').replace(queryParameters: {
          'q': query.trim(),
          'page': '$page',
          for (final key in const ['status', 'genre'])
            if (filters.single(key) case final v?) key: v,
        }),
      );

  Future<MangaPage> _list(Uri url) async {
    final res = await fetchHtml(url);
    return parseList(res.document, res.url);
  }

  MangaPage parseList(Document doc, Uri pageUrl) {
    final items = <SourceManga>[];
    for (final a in doc.querySelectorAll('a.card, a.manga-card')) {
      final title = clean(a.querySelector('.card-title')?.text);
      final url = attrAbs(a, 'href', pageUrl);
      if (title.isEmpty || url == null) continue;
      final manga = SourceManga(url: url, title: title, thumbnailUrl: attrAbs(a.querySelector('img'), 'src', pageUrl));
      if (!items.contains(manga)) items.add(manga);
    }
    final next = doc.querySelector('.explore-pagination__btn[rel=next], a[rel=next]') != null;
    return MangaPage(items, hasNextPage: next);
  }

  @override
  Future<List<FilterDef>> filters() async => const [
        SelectFilterDef('status', 'Status', [
          FilterOption('Semua', ''),
          FilterOption('Berjalan', 'ongoing'),
          FilterOption('Tamat', 'completed'),
        ]),
        SelectFilterDef('genre', 'Genre', [
          FilterOption('Semua', ''),
          FilterOption('Action', 'action'),
          FilterOption('Adventure', 'adventure'),
          FilterOption('Comedy', 'comedy'),
          FilterOption('Drama', 'drama'),
          FilterOption('Fantasy', 'fantasy'),
          FilterOption('Harem', 'harem'),
          FilterOption('Historical', 'historical'),
          FilterOption('Horror', 'horror'),
          FilterOption('Isekai', 'isekai'),
          FilterOption('Martial Arts', 'martial-arts'),
          FilterOption('Mystery', 'mystery'),
          FilterOption('Psychological', 'psychological'),
          FilterOption('Regression', 'regression'),
          FilterOption('Reincarnation', 'reincarnation'),
          FilterOption('Romance', 'romance'),
          FilterOption('School Life', 'school-life'),
          FilterOption('Sci-Fi', 'sci-fi'),
          FilterOption('Seinen', 'seinen'),
          FilterOption('Shounen', 'shounen'),
          FilterOption('Slice of Life', 'slice-of-life'),
          FilterOption('Sports', 'sports'),
          FilterOption('Supernatural', 'supernatural'),
          FilterOption('System', 'system'),
          FilterOption('Thriller', 'thriller'),
          FilterOption('Tragedy', 'tragedy'),
        ]),
      ];

  /// Padanan `.meta-item-label:matchesOwn(^Label$) + .meta-item-value`.
  static String? _meta(Document doc, String label) {
    for (final l in doc.querySelectorAll('.meta-item-label')) {
      if (ownText(l) == label) {
        final v = l.nextElementSibling;
        if (v != null && v.classes.contains('meta-item-value')) return nonPlaceholder(v.text);
      }
    }
    return null;
  }

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final url = Uri.parse(mangaUrl);
    final res = await fetchHtml(url.replace(queryParameters: {...url.queryParameters, 'all': '1'}));
    return parseDetails(res.document, url);
  }

  SourceMangaDetails parseDetails(Document doc, Uri mangaUrl) {
    final title = clean(doc.querySelector('.hero-title')?.text);
    if (title.isEmpty) throw const SourceException(SourceErrorKind.parse, detail: 'Judul tidak ditemukan.');
    final genres = [
      for (final p in doc.querySelectorAll('.meta-pill-row .meta-pill'))
        if (clean(p.text).isNotEmpty) clean(p.text),
      if (_meta(doc, 'Type') case final t?) t,
    ];
    return SourceMangaDetails(
      url: mangaUrl.toString(),
      title: title,
      author: _meta(doc, 'Author'),
      artist: _meta(doc, 'Artist'),
      description: nonPlaceholder(doc.querySelector('.synopsis-text')?.text),
      thumbnailUrl: attrAbs(doc.querySelector('.hero-cover img'), 'src', mangaUrl),
      status: switch (clean(doc.querySelector('.hero-status-badge')?.text).toLowerCase()) {
        'ongoing' => SourceMangaStatus.ongoing,
        'completed' => SourceMangaStatus.completed,
        _ => SourceMangaStatus.unknown,
      },
      genres: genres,
      chapters: [
        for (final row in doc.querySelectorAll('.chapter-row'))
          if (absUrl(mangaUrl, row.attributes['data-href']) case final href?)
            SourceChapter(
              url: href,
              name: clean(row.querySelector('.chapter-title')?.text),
              number: parseChapterNumber(clean(row.querySelector('.chapter-title')?.text)),
              uploadedAt: DateTime.tryParse(row.querySelector('[data-local-time]')?.attributes['data-local-time'] ?? '')
                  ?.toLocal(),
            ),
      ],
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    final pages = [
      for (final img in res.document.querySelectorAll('img.page-img'))
        if (imgAttr(img, res.url) case final url?) url,
    ];
    if (pages.isEmpty) throw const SourceException(SourceErrorKind.parse, detail: 'Gambar bab tidak ditemukan.');
    return pages;
  }
}
