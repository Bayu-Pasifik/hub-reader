// Situs katalog (bagian H), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0): mangayi.

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import 'fn_source.dart';

List<MangaSource> webcomicsH() => [
      // MangaYi
      FnSource(
        id: 'en.mangayi',
        name: 'MangaYi',
        baseUrl: 'https://mangayi.com',
        popularFn: (s, page) => _yi(s, page, {'p': page, 't': 1}),
        searchFn: (s, page, q) => _yi(s, page, {'p': page, 's': q}),
        detailsFn: (s, url) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/read/$url/'));
          final doc = res.document;
          final out = <SourceChapter>[];
          for (final a in doc.querySelectorAll('div.chapters-list a.c')) {
            if (a.classes.contains('unreleased')) continue;
            final href = attrAbs(a, 'href', res.url);
            if (href == null) continue;
            final name = clean(a.querySelector('.t')?.text);
            out.add(SourceChapter(
              url: href,
              name: name,
              number: parseChapterNumber(name),
              uploadedAt: parseLooseDate(clean(a.querySelector('.chapter-d')?.text)),
            ));
          }
          return SourceMangaDetails(
            url: url,
            title: clean(doc.querySelector('h1.m-title')?.text),
            author: clean(doc.querySelector('.m-authors')?.text),
            genres: [for (final p in doc.querySelectorAll('.m-genres .pill')) clean(p.text)],
            thumbnailUrl: attrAbs(doc.querySelector('.cover-wrap img.cover-image'), 'src', res.url),
            chapters: out,
          );
        },
        pagesFn: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse(ch.url));
          return [
            for (final img in res.document.querySelectorAll('div.c-images img'))
              if (attrAbs(img, 'src', res.url) case final u?) u,
          ];
        },
      ),
    ];

int _yiSize = 24;

Future<MangaPage> _yi(FnSource s, int page, Map<String, Object> payload) async {
  final j = await s.postJson(Uri.parse('${s.baseUrl}/api/search'), payload) as Map;
  final results = (j['results'] as List).cast<Map>();
  if (results.length > _yiSize) _yiSize = results.length;
  return MangaPage([
    for (final m in results)
      SourceManga(
        url: '${m['i']}',
        title: '${m['t']}',
        thumbnailUrl: 'https://scp.keterfoundation.com/cover/${m['i']}.jpg',
      ),
  ], hasNextPage: page * _yiSize < ((j['total'] as num?)?.toInt() ?? 0));
}
