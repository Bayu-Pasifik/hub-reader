// Port Dart dari extension Omicaso milik keiyoushi/extensions-source
// (Apache-2.0): src/id/omicaso.

import 'package:html/dom.dart';

import '../../core/i18n/strings.dart';
import '../../core/utils/json.dart';
import '../filters.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class OmicasoSource extends HttpSource {
  OmicasoSource({super.dio});

  @override
  String get id => 'id.omicaso';
  @override
  String get name => 'Omicaso';
  @override
  String get lang => 'id';
  @override
  String get defaultBaseUrl => 'https://omicaso.org';
  @override
  ContentWarning get contentWarning => ContentWarning.mixed;

  static const _pageSize = 20;

  SourceManga _manga(JsonMap m) => SourceManga(
        url: '$baseUrl/manga.php?slug=${m['slug']}',
        title: clean(asString(m['title'])),
        thumbnailUrl: asString(m['cover']),
      );

  Future<JsonMap> _catalog(Map<String, String> q) async =>
      asMap(await fetchJson(Uri.parse('$baseUrl/api/manga.php').replace(queryParameters: q)));

  @override
  Future<MangaPage> popular(int page) async {
    final json = await _catalog({'page': '1', 'limit': '1', 'mode': 'all'});
    final all = asList(asMap(asMap(json['sections'])['trending'])['all']);
    return MangaPage([for (final m in all) _manga(asMap(m))], hasNextPage: false);
  }

  Future<MangaPage> _list(int page, String query) async {
    final json = await _catalog({
      'page': '$page',
      'limit': '$_pageSize',
      'mode': 'all',
      'sort': 'updated',
      if (query.isNotEmpty) 'q': query,
    });
    return MangaPage(
      [for (final m in asList(json['items'])) _manga(asMap(m))],
      hasNextPage: json['has_more'] == true,
    );
  }

  @override
  Future<MangaPage> latest(int page) => _list(page, '');

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) =>
      _list(page, query.trim());

  String? _stat(Document doc, String label) {
    for (final div in doc.querySelectorAll('.detail-stat-grid div')) {
      final span = div.querySelector('span');
      if (span != null && clean(span.text) == label) {
        final v = clean(div.querySelector('strong')?.text);
        if (v.isNotEmpty) return v;
      }
    }
    return null;
  }

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final slug = Uri.parse(mangaUrl).queryParameters['slug'] ?? Uri.parse(mangaUrl).pathSegments.last;
    final res = await fetchHtml(Uri.parse('$baseUrl/manga.php?slug=$slug&order=desc'));
    final doc = res.document;
    final title = clean(doc.querySelector('h1')?.text);
    if (title.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Judul seri tidak ditemukan.'));
    }
    final alt = clean(doc.querySelector('.detail-alt-title')?.nodes.whereType<Text>().map((t) => t.text).join());
    final synopsis = clean(doc.querySelector('.synopsis-box p')?.text);
    final chapters = <SourceChapter>[];
    for (final a in doc.querySelectorAll('a.chapter-row')) {
      final href = attrAbs(a, 'href', res.url);
      if (href == null) continue;
      final name = clean(a.querySelector('strong')?.text);
      chapters.add(SourceChapter(
        url: href,
        name: name.isEmpty ? tr('Bab') : name,
        number: parseChapterNumber(name),
        uploadedAt: DateTime.tryParse((a.querySelector('time')?.attributes['datetime'] ?? '').replaceFirst(' ', 'T') + 'Z')
            ?.subtract(const Duration(hours: 7))
            .toLocal(),
      ));
    }
    return SourceMangaDetails(
      url: mangaUrl,
      title: title,
      thumbnailUrl: imgAttr(doc.querySelector('.detail-poster img'), res.url),
      author: _stat(doc, 'Author'),
      artist: _stat(doc, 'Artist'),
      description: [
        if (synopsis.isNotEmpty) synopsis,
        if (alt.isNotEmpty) trp('Judul alternatif:\n- {alt}', {'alt': alt}),
      ].join('\n\n'),
      genres: [
        for (final a in doc.querySelectorAll('.detail-rating-line a')) clean(a.text),
        if (_stat(doc, 'Type') case final t?) t,
      ],
      status: switch (_stat(doc, 'Status')?.toLowerCase()) {
        'ongoing' => SourceMangaStatus.ongoing,
        'completed' => SourceMangaStatus.completed,
        'hiatus' => SourceMangaStatus.hiatus,
        _ => SourceMangaStatus.unknown,
      },
      chapters: chapters,
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    final pages = [
      for (final img in res.document.querySelectorAll('img[data-reader-image]'))
        if (imgAttr(img, res.url) case final u?) u,
    ];
    if (pages.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    }
    return pages;
  }
}
