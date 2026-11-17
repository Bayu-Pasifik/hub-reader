// Webcomic bersumber tetap (bagian B), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0): patchfriday, questionablecontent,
// grrlpower, keenspot (TwoKinds), killsixbilliondemons.

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import 'multi_series.dart';

/// Ambil [urls] berurutan dalam kelompok kecil, hasil tetap berurutan.
Future<List<T>> _batched<T>(
    List<String> urls, Future<T> Function(String url) fn,
    {int size = 6}) async {
  final out = <T>[];
  for (var i = 0; i < urls.length; i += size) {
    out.addAll(await Future.wait(urls
        .sublist(i, i + size > urls.length ? urls.length : i + size)
        .map(fn)));
  }
  return out;
}

List<MangaSource> webcomicsB() => [
      // Patch Friday
      MultiSeriesSource(
        id: 'en.patchfriday',
        name: 'Patch Friday',
        baseUrl: 'https://patchfriday.com',
        series: [
          SeriesDef(
            key: 'pf',
            title: 'Patch Friday',
            author: 'Patch Friday',
            cover: 'https://patchfriday.com/patches/68.png',
            description: 'The IT security webcomic',
            loadChapters: (s) async {
              final out = <SourceChapter>[];
              var res = await wcGet(s, '/search/?search=');
              final first = res.document.querySelector('#gallery_item a');
              var page = int.tryParse((first?.attributes['href'] ?? '')
                      .replaceAll(RegExp(r'[^0-9]'), '')) ??
                  0;
              for (var guard = 0; page > 0 && guard < 120; guard++) {
                for (final a
                    in res.document.querySelectorAll('#gallery_item a')) {
                  final href = a.attributes['href'] ?? '';
                  final n =
                      int.tryParse(href.replaceAll(RegExp(r'[^0-9]'), ''));
                  if (n == null) continue;
                  out.add(SourceChapter(
                      url: '/$n/',
                      name: '#$n - ${clean(a.text)}',
                      number: n.toDouble()));
                }
                page -= 10;
                res = await wcGet(s, '/search/?search=&id=$page');
              }
              out.add(const SourceChapter(
                  url: '/1/', name: '#1 - The One', number: 1));
              final seen = <String>{};
              return out.where((c) => seen.add(c.url)).toList();
            },
            loadPages: wcImgs('div#strip_image img'),
          ),
        ],
      ),
      // Questionable Content
      MultiSeriesSource(
        id: 'en.questionablecontent',
        name: 'Questionable Content',
        baseUrl: 'https://www.questionablecontent.net',
        series: [
          SeriesDef(
            key: 'qc',
            title: 'Questionable Content',
            author: 'Jeph Jacques',
            cover: 'https://i.ibb.co/ZVL9ncS/qc-teh.png',
            description: 'An internet comic strip about romance and robots',
            loadChapters: (s) async {
              final doc = (await wcGet(s, '/archive.php')).document;
              final seen = <String>{};
              final out = <SourceChapter>[];
              for (final a in doc.querySelectorAll('div#container a')) {
                final href = a.attributes['href'] ?? '';
                final m = RegExp(r'^view\.php\?comic=(.*)$').firstMatch(href);
                if (m == null || !seen.add(href)) continue;
                final text = clean(a.text);
                final t = RegExp(r'^See #(\d+): "(.*)" with newspost$')
                    .firstMatch(text);
                out.add(SourceChapter(
                  url: '/$href',
                  name: t == null ? text : '${t[1]}: ${t[2]}',
                  number: double.tryParse(m[1]!),
                ));
              }
              return out;
            },
            loadPages: wcImgs('#strip'),
          ),
        ],
      ),
      // Grrl Power
      MultiSeriesSource(
        id: 'en.grrlpower',
        name: 'Grrl Power Comic',
        baseUrl: 'https://www.grrlpowercomic.com',
        series: [
          SeriesDef(
            key: 'gp',
            title: 'Grrl Power',
            author: 'David Barrack',
            cover:
                'https://static.tvtropes.org/pmwiki/pub/images/rsz_grrl_power.png',
            genres: const ['Superhero', 'Humor', 'Action'],
            loadChapters: (s) async {
              final out = <SourceChapter>[];
              for (var year = DateTime.now().year; year >= 2010; year--) {
                final res = await wcGet(s, '/archive/?archive_year=$year');
                for (final d
                    in res.document.querySelectorAll('.archive-date')) {
                  final link = d.nextElementSibling?.children.firstOrNull;
                  final href = attrAbs(link, 'href', res.url);
                  if (link == null || href == null) continue;
                  out.add(SourceChapter(
                    url: href,
                    name: clean(link.text),
                    uploadedAt: parseLooseDate('${clean(d.text)} $year'),
                  ));
                }
              }
              return out;
            },
            loadPages: wcImgs('div#comic img'),
          ),
        ],
      ),
      // TwoKinds (Keenspot)
      MultiSeriesSource(
        id: 'en.keenspot',
        name: 'keenspot',
        baseUrl: 'https://twokinds.keenspot.com',
        series: [
          for (final (key, title, size) in const [
            ('p1', 'TwoKinds (1 page per chapter)', 1),
            ('p20', 'TwoKinds (20 pages per chapter)', 20)
          ])
            SeriesDef(
              key: key,
              title: title,
              author: 'Tom Fischbach',
              cover:
                  'https://dummyimage.com/768x994/000/ffffff.jpg&text=${Uri.encodeComponent(title)}',
              status: SourceMangaStatus.unknown,
              loadChapters: (s) async {
                final res = await wcGet(s, '/archive/');
                final pages = <(String, String)>[];
                for (final season
                    in res.document.querySelectorAll('.chapter-links')) {
                  for (final a
                      in season.children.where((e) => e.localName == 'a')) {
                    final parts = (a.attributes['href'] ?? '').split('/');
                    if (parts.length < 3) continue;
                    pages.add((parts[2], clean(a.querySelector('span')?.text)));
                  }
                }
                final out = <SourceChapter>[];
                for (var i = 0; i < pages.length; i += size) {
                  final last =
                      (i + size > pages.length ? pages.length : i + size) - 1;
                  out.add(SourceChapter(
                    url: '${pages[i].$1}-${pages[last].$1}',
                    name: size == 1
                        ? 'Page ${pages[i].$2}'
                        : 'Pages ${pages[i].$2}-${pages[last].$2}',
                  ));
                }
                return out.reversed.toList();
              },
              loadPages: (s, ch) async {
                final ids = ch.url.split('-');
                final res = await wcGet(s, '/archive/');
                final all = <String>[];
                for (final season
                    in res.document.querySelectorAll('.chapter-links')) {
                  for (final a
                      in season.children.where((e) => e.localName == 'a')) {
                    final parts = (a.attributes['href'] ?? '').split('/');
                    if (parts.length >= 3) all.add(parts[2]);
                  }
                }
                final from = all.indexOf(ids.first);
                final to = all.indexOf(ids.last);
                if (from < 0 || to < from) return [];
                final imgs =
                    await _batched(all.sublist(from, to + 1), (id) async {
                  final r = await wcGet(s, '/comic/$id/');
                  return imgAttr(
                      r.document.querySelector('#content article img'), r.url);
                });
                return imgs.whereType<String>().toList();
              },
            ),
        ],
      ),
      // Kill Six Billion Demons
      MultiSeriesSource(
        id: 'en.killsixbilliondemons',
        name: 'Kill Six Billion Demons',
        baseUrl: 'https://killsixbilliondemons.com',
        series: [
          SeriesDef(
            key: 'ksbd',
            title: 'Kill Six Billion Demons',
            author: 'Abbadon',
            cover:
                'https://killsixbilliondemons.com/wp-content/uploads/2013/04/ksbd-logo-header.png',
            description:
                'A webcomic in graphic novel style, meant to be read in large chunks.',
            loadChapters: (s) async {
              final doc = (await wcGet(s, '/')).document;
              final out = <SourceChapter>[];
              var n = 0;
              for (final o in doc.querySelectorAll('#chapter option')) {
                final v = o.attributes['value'] ?? '';
                final text = clean(o.text);
                if (v == '0' ||
                    v.isEmpty ||
                    text.toLowerCase() == 'select chapter') continue;
                final label = text.split(' (').first.trim();
                if (double.tryParse(label) == null) continue; // judul buku
                out.add(SourceChapter(
                    url: v, name: 'Chapter $label', number: (++n).toDouble()));
              }
              return out.reversed.toList();
            },
            loadPages: (s, ch) async {
              var res = await s.fetchHtml(Uri.parse('${ch.url}?order=asc'));
              final posts = <String>[];
              for (var i = 0; i < 80; i++) {
                for (final a in res.document
                    .querySelectorAll('.comic-thumbnail-in-archive a')) {
                  final href = attrAbs(a, 'href', res.url);
                  if (href != null) posts.add(href);
                }
                final next = attrAbs(
                    res.document.querySelector('.paginav-next a'),
                    'href',
                    res.url);
                if (next == null) break;
                res = await s.fetchHtml(Uri.parse(next));
              }
              if (posts.isEmpty) {
                return [
                  for (final img
                      in res.document.querySelectorAll('#comic img[src]'))
                    if (imgAttr(img, res.url) case final u?)
                      u.replaceAll(RegExp(r'-\d+x\d+(?=\.\w+$)'), ''),
                ];
              }
              final lists = await _batched(posts, (u) async {
                final r = await s.fetchHtml(Uri.parse(u));
                return [
                  for (final img
                      in r.document.querySelectorAll('#comic img[src]'))
                    if (imgAttr(img, r.url) case final x?)
                      x.replaceAll(RegExp(r'-\d+x\d+(?=\.\w+$)'), ''),
                ];
              });
              return [for (final l in lists) ...l];
            },
          ),
        ],
      ),
    ];
