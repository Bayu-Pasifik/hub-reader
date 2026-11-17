// Webcomic bersumber tetap (bagian E), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0): solarandsundry, supermega,
// swordscomic, thepropertyofhate, thedrawplay,
// schlockmercenary.

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import 'multi_series.dart';

/// Ambil [items] berurutan dalam kelompok kecil, hasil tetap berurutan.
Future<List<T>> _batched<T, E>(List<E> items, Future<T> Function(E item) fn, {int size = 6}) async {
  final out = <T>[];
  for (var i = 0; i < items.length; i += size) {
    out.addAll(await Future.wait(items.sublist(i, i + size > items.length ? items.length : i + size).map(fn)));
  }
  return out;
}

String _ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

List<MangaSource> webcomicsE() => [
      // Solar and Sundry
      MultiSeriesSource(
        id: 'en.solarandsundry',
        name: 'Solar and Sundry',
        baseUrl: 'https://sas-api.fly.dev',
        series: [
          SeriesDef(
            key: 'sas',
            title: 'Solar and Sundry',
            author: 'Ewan Breakey',
            cover: 'https://imagedelivery.net/zthi1l8fKrUGB5ig08mq-Q/de292ba7-f164-4f43-ec17-1876a7a44600/public',
            loadChapters: (s) async {
              final list = await s.fetchJson(wcUri(s, '/page')) as List;
              return [
                for (final p in list.reversed)
                  SourceChapter(
                    url: '/page/${(p as Map)['page_number']}',
                    name: '${p['name']}',
                    number: (p['page_number'] as num).toDouble(),
                    uploadedAt: DateTime.tryParse('${p['published_at']}'),
                  ),
              ];
            },
            loadPages: (s, ch) async {
              final p = await s.fetchJson(wcUri(s, ch.url)) as Map;
              return ['${p['image_url']}'];
            },
          ),
        ],
      ),
      // SUPER MEGA
      MultiSeriesSource(
        id: 'en.supermega',
        name: 'SUPER MEGA',
        baseUrl: 'https://www.supermegacomics.com',
        series: [
          SeriesDef(
            key: 'sm',
            title: 'SUPER MEGA',
            author: 'JohnnySmash',
            cover: 'https://www.supermegacomics.com/runningman.png',
            loadChapters: (s) async {
              final res = await wcGet(s, '/');
              final href = res.document.querySelector("[name='bigbuttonprevious']")?.parent?.attributes['href'] ?? '';
              final last = (int.tryParse(Uri.tryParse(href)?.queryParameters['i'] ?? '') ?? 0) + 1;
              return [for (var i = last; i >= 1; i--) SourceChapter(url: '/?i=$i', name: '$i', number: i.toDouble())];
            },
            loadPages: wcImgs("img[border='4']"),
          ),
        ],
      ),
      // Swords Comic
      MultiSeriesSource(
        id: 'en.swordscomic',
        name: 'Swords Comic',
        baseUrl: 'https://swordscomic.com',
        series: [
          SeriesDef(
            key: 'sw',
            title: 'Swords Comic',
            author: 'Matthew Wills',
            cover: 'https://swordscomic.com/media/ArgoksEdgeEmote.png',
            loadChapters: (s) async {
              final res = await wcGet(s, '/archive/pages/');
              return [
                for (final a in res.document.querySelectorAll('a.archive-tile'))
                  if (attrAbs(a, 'href', res.url) case final href?)
                    SourceChapter(
                      url: href,
                      name: clean(a.querySelector('strong')?.text),
                      uploadedAt: parseLooseDate(clean(a.querySelector('small')?.text)),
                    ),
              ];
            },
            loadPages: wcImgs('img#comic-image'),
          ),
        ],
      ),
      // The Property of Hate
      MultiSeriesSource(
        id: 'en.thepropertyofhate',
        name: 'The Property of Hate',
        baseUrl: 'https://jolleycomics.com',
        series: [
          SeriesDef(
            key: 'tpoh',
            title: 'The Property of Hate',
            author: 'Sarah Jolley',
            cover: 'https://jolleycomics.com/images/Index/tpoh.png',
            loadChapters: (s) async {
              final res = await wcGet(s, '/TPoH/');
              final out = <SourceChapter>[];
              var added = false;
              var n = 1;
              for (final o in res.document.querySelectorAll('select.jumpbox option')) {
                final v = o.attributes['value'] ?? '';
                if (v == '-1') continue;
                final bold = (o.attributes['style'] ?? '').contains('bold');
                if (bold) {
                  final href = absUrl(res.url, v);
                  if (href != null) out.add(SourceChapter(url: href, name: '#$n - ${clean(o.text)}', number: (n++).toDouble()));
                } else if (!added) {
                  final base = v.substring(0, v.lastIndexOf('/') + 1);
                  final href = absUrl(res.url, base);
                  final name = clean(o.text).split(' : Page').first.trim();
                  if (href != null) out.add(SourceChapter(url: href, name: '#$n - $name', number: (n++).toDouble()));
                  added = true;
                }
              }
              return out.reversed.toList();
            },
            loadPages: (s, ch) async {
              final res = await wcGet(s, ch.url);
              final pages = <String>[];
              for (final o in res.document.querySelectorAll('select.jumpbox option')) {
                final v = o.attributes['value'] ?? '';
                if (v == '-1' || (o.attributes['style'] ?? '').contains('bold')) continue;
                final href = absUrl(res.url, v);
                if (href != null) pages.add(href);
              }
              final imgs = await _batched(pages, (u) async {
                final r = await s.fetchHtml(Uri.parse(u));
                return imgAttr(r.document.querySelector('.comic_comic > img'), r.url);
              });
              return imgs.whereType<String>().toList();
            },
          ),
        ],
      ),
      // The Draw Play
      MultiSeriesSource(
        id: 'en.thedrawplay',
        name: 'The Draw Play',
        baseUrl: 'https://www.thedrawplay.com',
        series: [
          SeriesDef(
            key: 'dp',
            title: 'The Draw Play',
            author: 'Dave Rappoccio',
            cover: 'https://www.thedrawplay.com/wp-content/uploads/2025/09/cropped-SiteLogo.png',
            loadChapters: (s) async {
              final res = await wcGet(s, '/archive/');
              var year = '';
              final out = <SourceChapter>[];
              for (final e in res.document.querySelectorAll('h3.year-title, tr')) {
                if (e.localName == 'h3') {
                  year = clean(e.text);
                  continue;
                }
                final link = e.querySelector('td.archive-title > a');
                final href = attrAbs(link, 'href', res.url);
                if (link == null || href == null) continue;
                final date = clean(e.querySelector('td.archive-date')?.text);
                out.add(SourceChapter(
                  url: href,
                  name: clean(link.text),
                  uploadedAt: date.isEmpty ? null : parseLooseDate('$date $year'),
                ));
              }
              return out;
            },
            loadPages: wcImgs('#comic img'),
          ),
        ],
      ),
      // Schlock Mercenary
      MultiSeriesSource(
        id: 'en.schlockmercenary',
        name: 'Schlock Mercenary',
        baseUrl: 'https://www.schlockmercenary.com',
        series: [
          SeriesDef(
            key: 'sm',
            title: 'Schlock Mercenary',
            author: 'Howard Tayler',
            cover: 'https://www.schlockmercenary.com/static/img/logo.b6dacbb8.jpg',
            loadChapters: (s) async {
              final res = await wcGet(s, '/archives/');
              final out = <SourceChapter>[];
              for (final book in res.document.querySelectorAll('div.archive-book')) {
                final bookName = clean(book.querySelector('h4 > a')?.text);
                final ul = book.querySelector('ul.chapters');
                if (ul == null) continue;
                for (final li in ul.children.where((e) => e.localName == 'li')) {
                  final a = li.children.where((e) => e.localName == 'a').firstOrNull;
                  final href = a?.attributes['href'];
                  if (a == null || href == null || href.length < 10) continue;
                  final date = href.substring(href.length - 10);
                  out.add(SourceChapter(
                    url: href,
                    name: '$bookName - ${clean(a.text)}',
                    uploadedAt: DateTime.tryParse(date),
                  ));
                }
              }
              return out.reversed.toList();
            },
            loadPages: (s, ch) async {
              final start = DateTime.tryParse(ch.url.substring(ch.url.length - 10));
              if (start == null) return [];
              final res = await wcGet(s, '/archives/');
              final hrefs = [
                for (final a in res.document.querySelectorAll('ul.chapters > li > a'))
                  if ((a.attributes['href'] ?? '').length >= 10) a.attributes['href']!,
              ];
              final idx = hrefs.indexOf(ch.url);
              var end = start.add(const Duration(days: 1));
              if (idx >= 0 && idx + 1 < hrefs.length) {
                end = DateTime.tryParse(hrefs[idx + 1].substring(hrefs[idx + 1].length - 10)) ?? end;
              }
              final days = <String>[];
              for (var d = start; d.isBefore(end) && days.length < 120; d = d.add(const Duration(days: 1))) {
                days.add(_ymd(d));
              }
              final lists = await _batched(days, (day) async {
                final r = await wcGet(s, '/$day');
                return [
                  for (final img in r.document.querySelectorAll('div#strip-$day > img'))
                    if (imgAttr(img, r.url) case final u?) u,
                ];
              });
              return [for (final l in lists) ...l];
            },
          ),
        ],
      ),
    ];
