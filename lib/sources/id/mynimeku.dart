// Port Dart dari extension MyNimeku milik keiyoushi/extensions-source
// (Apache-2.0): src/id/mynimeku.

import 'package:html/dom.dart';

import '../../core/i18n/strings.dart';
import '../filters.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class MyNimekuSource extends HttpSource {
  MyNimekuSource({super.dio});

  @override
  String get id => 'id.mynimeku';
  @override
  String get name => 'MyNimeku';
  @override
  String get lang => 'id';
  @override
  String get defaultBaseUrl => 'https://www.mynimeku.com';
  @override
  ContentWarning get contentWarning => ContentWarning.mixed;
  @override
  int get requestsPerSecond => 3;

  static const _types = 'DOUJINSHI,MANGA,MANHUA,MANHWA,ONE-SHOT';

  Uri _fullList(int page, List<String> segments) => baseUri.replace(pathSegments: [
        'full-list',
        'mix',
        segments.join('~'),
        if (page > 1) ...['page', '$page'],
        '',
      ]);

  @override
  Future<MangaPage> popular(int page) => _list(_fullList(page, ['o:popular', 't:$_types']));

  @override
  Future<MangaPage> latest(int page) => _list(baseUri.replace(pathSegments: [
        'latest-komik',
        if (page > 1) ...['page', '$page'],
        '',
      ]));

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) {
    final q = query.trim();
    return _list(_fullList(page, [if (q.isNotEmpty) 'j:$q', 'o:popular', 't:$_types']));
  }

  Future<MangaPage> _list(Uri url) async {
    final res = await fetchHtml(url);
    final items = <SourceManga>[];
    for (final item in res.document
        .querySelectorAll('article.mynimeku-update-feed__item, article.mynimeku-mix-feed__item')) {
      final link = item.querySelector('a[class\$=__series-title]');
      final href = attrAbs(link, 'href', res.url);
      if (href == null) continue;
      items.add(SourceManga(
        url: href,
        title: clean(link!.text),
        thumbnailUrl: _img(item.querySelector('a[class\$=__cover] img'), res.url),
      ));
    }
    final next =
        res.document.querySelectorAll('a.is-arrow').any((a) => clean(a.text).toLowerCase().startsWith('next'));
    return MangaPage(items, hasNextPage: next);
  }

  String? _img(Element? img, Uri base) {
    final lazy = img?.attributes['data-lazy-src'];
    if (lazy != null && lazy.isNotEmpty) return absUrl(base, lazy);
    return imgAttr(img, base);
  }

  String? _table(Document doc, String label) {
    for (final row in doc.querySelectorAll('table.komik-series-table tr')) {
      if (clean(row.querySelector('th')?.text) == label) {
        final v = clean(row.querySelector('td')?.text);
        if (v.isNotEmpty) return v;
      }
    }
    return null;
  }

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    final doc = res.document;
    final title = clean(doc.querySelector('h1.komik-series-hero__title')?.text);
    if (title.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Judul seri tidak ditemukan.'));
    }
    final alts = <String>{
      for (final l in ['Japanese', 'English', 'Synonyms'])
        if (_table(doc, l) case final v?) v,
    }..remove(title);
    final desc = clean(doc.querySelector('.komik-series-entry')?.text);
    final chapters = <SourceChapter>[];
    for (final row in doc.querySelectorAll('div.komik-series-chapter-row')) {
      final link = row.querySelector('a.komik-series-chapter-item');
      final href = attrAbs(link, 'href', res.url);
      if (href == null) continue;
      final name = clean(link!.querySelector('.komik-series-chapter-item__title')?.text)
          .replaceFirst(RegExp(r' Bahasa Indonesia$'), '');
      chapters.add(SourceChapter(
        url: href,
        name: name.isEmpty ? tr('Bab') : name,
        number: double.tryParse(row.attributes['data-chapter-number'] ?? '') ?? parseChapterNumber(name),
        uploadedAt: parseLooseDate(link.querySelector('.komik-series-chapter-item__date')?.text),
      ));
    }
    return SourceMangaDetails(
      url: mangaUrl,
      title: title,
      thumbnailUrl: _img(doc.querySelector('.komik-series-hero__cover img'), res.url),
      author: _table(doc, 'Author'),
      description: [
        if (desc.isNotEmpty) desc,
        if (alts.isNotEmpty) trp('Judul alternatif:\n{names}', {'names': alts.map((a) => '- $a').join('\n')}),
      ].join('\n\n'),
      genres: [
        for (final a in doc.querySelectorAll('.komik-series-taxonomy__terms a')) clean(a.text),
        if (_table(doc, 'Type') case final t?) t,
      ],
      status: switch (_table(doc, 'Status')?.toLowerCase()) {
        'on-going' => SourceMangaStatus.ongoing,
        'completed' => SourceMangaStatus.completed,
        _ => SourceMangaStatus.unknown,
      },
      chapters: chapters,
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    final pages = [
      for (final img in res.document.querySelectorAll('div.komik-reader-content[data-reader-content] img[src]'))
        if (absUrl(res.url, img.attributes['src'] ?? '') case final u?) u,
    ];
    if (pages.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    }
    return pages;
  }
}
