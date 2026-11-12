// Port Dart dari extension KomikNextGOnline milik keiyoushi/extensions-source
// (Apache-2.0): src/id/komiknextgonline.

import 'package:html/dom.dart';

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

/// Komik edukasi; tiap judul hanya satu "bab" (halaman komik itu sendiri).
class KomikNextGOnlineSource extends HttpSource {
  KomikNextGOnlineSource({super.dio});

  @override
  String get id => 'id.komiknextgonline';
  @override
  String get name => 'Komik Next G Online';
  @override
  String get lang => 'id';
  @override
  String get defaultBaseUrl => 'https://komiknextgonline.com';
  @override
  ContentWarning get contentWarning => ContentWarning.safe;
  @override
  bool get supportsLatest => false;

  static final _coverSuffix = RegExp(r'\s+cover$', caseSensitive: false);
  static final _titlePrefix = RegExp(r'^#\d+\.\s*');

  @override
  Future<MangaPage> popular(int page) async {
    final res = await fetchHtml(Uri.parse('$baseUrl/comic/page/$page/'));
    final items = <SourceManga>[
      for (final el in res.document.querySelectorAll('span.comic-thumbnail-wrapper'))
        if (attrAbs(el.querySelector('a'), 'href', res.url) case final url?)
          SourceManga(
            url: url,
            title: clean(el.querySelector('img')?.attributes['alt']).replaceFirst(_coverSuffix, ''),
            thumbnailUrl: attrAbs(el.querySelector('img'), 'src', res.url),
          ),
    ];
    return MangaPage(items, hasNextPage: res.document.querySelector('.nav-previous a') != null);
  }

  @override
  Future<MangaPage> latest(int page) => popular(page);

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    final Uri url;
    if (query.trim().isNotEmpty) {
      url = Uri.parse(page > 1 ? '$baseUrl/page/$page/' : '$baseUrl/').replace(queryParameters: {'s': query.trim()});
    } else {
      final category = filters.single('category');
      url = Uri.parse(category == null ? '$baseUrl/' : '$baseUrl/$category')
          .replace(queryParameters: {if (page > 1) 'comics_paged': '$page'});
    }
    final res = await fetchHtml(url);
    return MangaPage(
      [
        for (final el in res.document.querySelectorAll('#left-content ul#comic-list li.comic, #left-content article.comic'))
          if (attrAbs(el.querySelector('a'), 'href', res.url) case final href?)
            SourceManga(
              url: href,
              title: clean(el.querySelector('.comic-title, .entry-title')?.text).replaceFirst(_titlePrefix, ''),
              thumbnailUrl: attrAbs(el.querySelector('img'), 'src', res.url),
            ),
      ],
      hasNextPage: res.document.querySelector('a.next.page-numbers') != null,
    );
  }

  @override
  Future<List<FilterDef>> filters() async => const [
        SelectFilterDef('category', 'Kategori', [
          FilterOption('Semua', ''),
          FilterOption('Pendidikan', 'pendidikan'),
          FilterOption('Persahabatan', 'persahabatan'),
          FilterOption('Anak Islami', 'anak-islami'),
          FilterOption('Horor dan Misteri', 'horor-dan-misteri'),
        ]),
      ];

  String? _meta(Document doc, String property) => doc.querySelector('meta[property="$property"]')?.attributes['content'];

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    final doc = res.document;
    final title = (_meta(doc, 'og:title') ?? '').split(' - ').first.trim();
    if (title.isEmpty) throw const SourceException(SourceErrorKind.parse, detail: 'Judul tidak ditemukan.');
    return SourceMangaDetails(
      url: res.url.toString(),
      title: title,
      description: nonPlaceholder(_meta(doc, 'og:description')),
      thumbnailUrl: absUrl(res.url, _meta(doc, 'og:image')),
      status: SourceMangaStatus.completed,
      chapters: [
        SourceChapter(
          url: absUrl(res.url, _meta(doc, 'og:url')) ?? res.url.toString(),
          name: 'Chapter 1',
          number: 1,
          uploadedAt: DateTime.tryParse(_meta(doc, 'article:published_time') ?? '')?.toLocal(),
        ),
      ],
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    final pages = [
      for (final img in res.document.querySelectorAll('div#spliced-comic img'))
        if (imgAttr(img, res.url) case final url?) url,
    ];
    if (pages.isEmpty) throw const SourceException(SourceErrorKind.parse, detail: 'Gambar tidak ditemukan.');
    return pages;
  }
}
