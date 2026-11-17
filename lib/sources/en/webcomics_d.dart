// Webcomic bersumber tetap (bagian D), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0): imanevilgod, oots, randowiz,
// reallifecomics, sabrinaonline, saturdaymorningbreakfastcomics.

import 'package:html/dom.dart';

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import 'multi_series.dart';

List<MangaSource> webcomicsD() => [
      // I'm An Evil God
      MultiSeriesSource(
        id: 'en.imanevilgod',
        name: "I'm An Evil God",
        baseUrl: 'https://imanevilgod.com',
        series: [
          SeriesDef(
            key: 'main',
            title: "I'm An Evil God",
            status: SourceMangaStatus.unknown,
            loadCover: wcOgImage,
            loadChapters: (s) async {
              final res = await wcGet(s, '/');
              final out = <SourceChapter>[];
              for (final a in res.document.querySelectorAll('p.has-medium-font-size a')) {
                final href = attrAbs(a, 'href', res.url);
                if (href == null || !href.contains('imanevilgod.com')) continue;
                out.add(SourceChapter(url: href, name: clean(a.text), number: out.length.toDouble()));
              }
              return out;
            },
            loadPages: wcImgs('div.entry-content img'),
          ),
        ],
      ),
      // The Order of the Stick
      MultiSeriesSource(
        id: 'en.oots',
        name: 'oots',
        baseUrl: 'https://www.giantitp.com',
        series: [
          SeriesDef(
            key: 'oots',
            title: 'The Order Of The Stick',
            author: 'Rich Burlew',
            cover: 'https://i.giantitp.com/redesign/Icon_Comics_OOTS.gif',
            loadChapters: (s) async {
              final res = await wcGet(s, '/comics/oots.html');
              final seen = <String>{};
              final out = <SourceChapter>[];
              for (final a in res.document.querySelectorAll('p.ComicList a')) {
                final href = a.attributes['href'];
                if (href == null || !seen.add(href)) continue;
                out.add(SourceChapter(
                  url: href,
                  name: clean(a.text),
                  number: double.tryParse(RegExp(r'oots(\d+)\.html').firstMatch(href)?[1] ?? ''),
                ));
              }
              return out;
            },
            loadPages: wcImgs("td[align='center'] > img"),
          ),
        ],
      ),
      // Randowiz
      MultiSeriesSource(
        id: 'en.randowiz',
        name: 'Randowiz',
        baseUrl: 'https://randowis.com',
        series: [
          for (final (key, title, path, cover) in const [
            (
              'mmo',
              'Randowiz: We live in an MMO!?',
              '/category/we-live-in-an-mmo/',
              'https://i0.wp.com/randowis.com/wp-content/uploads/2016/02/MMO_CHP_001_CSP_000.jpg?resize=800%2C800&ssl=1',
            ),
            (
              'short',
              'Randowiz: Short comics',
              '/category/short-comics/',
              'https://i0.wp.com/randowis.com/wp-content/uploads/2021/10/Images_PNGs_Site_BOT-SUPPORT.png',
            ),
            (
              'art',
              'Randowiz: Illustations',
              '/category/art/',
              'https://i0.wp.com/randowis.com/wp-content/uploads/2021/05/colour-studies-021-post.jpg',
            ),
          ])
            SeriesDef(
              key: key,
              title: title,
              author: 'Randowiz',
              cover: cover,
              loadChapters: (s) async {
                final out = <SourceChapter>[];
                Uri? next = wcUri(s, path);
                for (var i = 0; next != null && i < 60; i++) {
                  final res = await s.fetchHtml(next);
                  for (final el in res.document.querySelectorAll('.has-post-thumbnail')) {
                    final a = el.querySelector('.elementor-post__title a');
                    final href = attrAbs(a, 'href', res.url);
                    if (a == null || href == null) continue;
                    out.add(SourceChapter(
                      url: href,
                      name: clean(a.text),
                      uploadedAt: _dmy(clean(el.querySelector('.elementor-post-date')?.text)),
                    ));
                  }
                  final nx = attrAbs(res.document.querySelector('.next'), 'href', res.url);
                  next = nx == null ? null : Uri.parse(nx);
                }
                return [
                  for (var i = 0; i < out.length; i++)
                    SourceChapter(
                      url: out[i].url,
                      name: out[i].name,
                      number: (out.length - i).toDouble(),
                      uploadedAt: out[i].uploadedAt,
                    ),
                ];
              },
              loadPages: wcImgs('.elementor-widget-theme-post-content img'),
            ),
        ],
      ),
      // Real Life Comics (satu seri per tahun)
      MultiSeriesSource(
        id: 'en.reallifecomics',
        name: 'Real Life Comics',
        baseUrl: 'https://reallifecomics.com',
        series: [
          for (var year = 2025; year >= 1999; year--)
            if (year < 2016 || year > 2017)
              SeriesDef(
                key: 'y$year',
                title: 'Real Life Comics ($year)',
                author: 'Maelyn Dean',
                cover: 'https://reallifecomics.com/images/logo.png',
                status: year == 2025 ? SourceMangaStatus.ongoing : SourceMangaStatus.completed,
                loadChapters: (s) async {
                  final res = await wcGet(s, '/archivepage.php?year=$year');
                  final seen = <String>{};
                  final out = <SourceChapter>[];
                  for (final a in res.document.querySelectorAll('.calendar tbody tr td a')) {
                    final href = a.attributes['href'];
                    if (href == null || !seen.add(href)) continue;
                    final cal = _closest(a, 'calendar');
                    Element? prev = cal?.previousElementSibling;
                    String month = '';
                    while (prev != null) {
                      if (prev.localName == 'h4' && prev.classes.contains('month')) {
                        month = clean(prev.text);
                        break;
                      }
                      prev = prev.previousElementSibling;
                    }
                    final date = '$month ${clean(a.text)}'.trim();
                    final parsed = parseLooseDate(date);
                    out.add(SourceChapter(url: href, name: date, number: out.length.toDouble(), uploadedAt: parsed));
                  }
                  return out.reversed.toList();
                },
                loadPages: wcImgs('.comic img'),
              ),
        ],
      ),
      // Sabrina Online
      MultiSeriesSource(
        id: 'en.sabrinaonline',
        name: 'Sabrina Online',
        baseUrl: 'https://www.sabrina-online.com',
        series: [
          SeriesDef(
            key: 'main',
            title: 'Sabrina Online',
            author: 'Eric W. Schwartz',
            cover: 'https://dummyimage.com/768x994/000/ffffff.jpg&text=Sabrina%20Online',
            status: SourceMangaStatus.unknown,
            loadChapters: (s) async {
              final res = await wcGet(s, '/archive.html');
              final rows = res.document.querySelectorAll('center table tr');
              final out = <SourceChapter>[];
              void fromRow(Element tr, List<String> sections) {
                var i = 0;
                for (final td in tr.querySelectorAll('td')) {
                  for (final a in td.querySelectorAll('a')) {
                    final ch = clean(a.text);
                    final href = attrAbs(a, 'href', res.url);
                    if (ch.isEmpty || href == null) continue;
                    final sec = i < sections.length ? sections[i] : '';
                    final hasYear = sec.isNotEmpty && RegExp(r'^\d').hasMatch(sec);
                    out.add(SourceChapter(url: href, name: hasYear ? '$sec $ch' : ch));
                  }
                  i++;
                }
              }

              for (var i = 0; i < rows.length; i += 2) {
                if (i + 1 >= rows.length) {
                  fromRow(rows[i], const []);
                } else {
                  final sections = [for (final td in rows[i].querySelectorAll('td')) clean(td.text)];
                  if (sections.isNotEmpty) {
                    fromRow(rows[i + 1], sections);
                  } else {
                    fromRow(rows[i + 1], const []);
                    fromRow(rows[i], const []);
                  }
                }
              }
              return out;
            },
            loadPages: (s, ch) async {
              final res = await wcGet(s, ch.url);
              final out = <String>[];
              for (final img in res.document.querySelectorAll('center img')) {
                final src = img.attributes['src'] ?? '';
                if (!(src.contains('strips/') || src.contains('pages/'))) continue;
                final parent = img.parent;
                final u = parent?.localName == 'a' && (parent!.attributes['href'] ?? '').isNotEmpty
                    ? attrAbs(parent, 'href', res.url)
                    : attrAbs(img, 'src', res.url);
                if (u != null) out.add(u);
              }
              return out;
            },
          ),
        ],
      ),
      // Saturday Morning Breakfast Comics
      MultiSeriesSource(
        id: 'en.smbc',
        name: 'Saturday Morning Breakfast Comics',
        baseUrl: 'https://smbc-comics.com',
        series: [
          SeriesDef(
            key: 'smbc',
            title: 'Saturday Morning Breakfast Comics',
            author: 'Zach Weinersmith',
            cover: 'https://www.smbc-comics.com/images/smbc-logo.png',
            loadChapters: (s) async {
              final res = await wcGetLoose(s, '/comic/archive');
              final out = <SourceChapter>[];
              for (final o in res.document.querySelectorAll('option')) {
                final v = o.attributes['value'] ?? '';
                if (!v.contains('comic/')) continue;
                final parts = clean(o.text).split(' - ');
                out.add(SourceChapter(
                  url: '/$v',
                  name: parts.length > 1 ? parts.sublist(1).join(' - ') : parts.first,
                  number: (out.length + 1).toDouble(),
                  uploadedAt: parseLooseDate(parts.first),
                ));
              }
              return out.reversed.toList();
            },
            loadPages: (s, ch) async {
              final res = await wcGetLoose(s, ch.url);
              final out = <String>[];
              final main = attrAbs(res.document.querySelector('img#cc-comic'), 'src', res.url);
              if (main != null) out.add(main);
              final after = attrAbs(res.document.querySelector('#aftercomic > img'), 'src', res.url);
              if (after != null) out.add(after);
              return out;
            },
          ),
        ],
      ),
    ];

Element? _closest(Element el, String cls) {
  Element? cur = el.parent;
  while (cur != null) {
    if (cur.classes.contains(cls)) return cur;
    cur = cur.parent;
  }
  return null;
}

DateTime? _dmy(String s) {
  final m = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(s);
  if (m == null) return null;
  return DateTime.tryParse('${m[3]}-${m[2]!.padLeft(2, '0')}-${m[1]!.padLeft(2, '0')}');
}
