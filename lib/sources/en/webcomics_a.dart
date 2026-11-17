// Webcomic bersumber tetap, port Dart dari extension keiyoushi/extensions-source
// (Apache-2.0): collectedcurios, explosm, darklegacycomics, darkscience,
// egscomics, elanschool, existentialcomics, gunnerkriggcourt, loadingartist.

import 'dart:convert';

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import 'multi_series.dart';

List<MangaSource> webcomicsA() => [
      // Collected Curios
      MultiSeriesSource(
        id: 'en.collectedcurios',
        name: 'Collected Curios',
        baseUrl: 'https://www.collectedcurios.com',
        series: [
          for (final (key, title, path, thumb, sel) in const [
            (
              'sequentialart',
              'Sequential Art',
              '/sequentialart.php',
              'CC_2011_Sequential_Art_Button.jpg',
              '.w3-image'
            ),
            (
              'battlebunnies',
              'Battle Bunnies',
              '/battlebunnies.php',
              'CC_2011_Battle_Bunnies_Button.jpg',
              '#strip'
            ),
            (
              'spiderandscorpion',
              'Spider and Scorpion',
              '/spiderandscorpion.php',
              'CC_2011_Spider_And_Scorpion_Button.jpg',
              '#strip',
            ),
          ])
            SeriesDef(
              key: key,
              title: title,
              author: 'Jolly Jack aka Phillip M Jackson',
              cover: 'https://www.collectedcurios.com/images/$thumb',
              description: '$title webcomic.',
              loadChapters: (s) async {
                final doc = (await wcGet(s, path)).document;
                int? last = int.tryParse((doc
                            .querySelector('img[title=Last]')
                            ?.parent
                            ?.attributes['href'] ??
                        '')
                    .split('=')
                    .last);
                last ??= int.tryParse(doc
                        .querySelector('input[title="Jump to number"]')
                        ?.attributes['value'] ??
                    '');
                final back = int.tryParse((doc
                            .querySelector('img[title="Back one"]')
                            ?.parent
                            ?.attributes['href'] ??
                        '')
                    .split('=')
                    .last);
                last ??= back == null ? null : back + 1;
                last ??= 1;
                return [
                  for (var i = last; i >= 1; i--)
                    SourceChapter(
                        url: '$path?s=$i',
                        name: 'Chapter - $i',
                        number: i.toDouble()),
                ];
              },
              loadPages: (s, ch) async {
                final res = await wcGet(s, ch.url);
                final u = imgAttr(res.document.querySelector(sel), res.url);
                return u == null ? <String>[] : [u];
              },
            ),
        ],
      ),
      // Cyanide & Happiness
      MultiSeriesSource(
        id: 'en.explosm',
        name: 'Cyanide & Happiness',
        baseUrl: 'https://explosm.net',
        series: [
          SeriesDef(
            key: 'ch',
            title: 'Cyanide & Happiness',
            author: 'Explosm.net',
            cover:
                'https://vhx.imgix.net/vitalyuncensored/assets/13ea3806-5ebf-4987-bcf1-82af2b689f77/S2E4_Still1.jpg',
            loadChapters: (s) async {
              final doc = (await wcGet(s, '/comics')).document;
              final scripts = doc.querySelectorAll('head > script');
              final src =
                  scripts.isEmpty ? null : scripts.last.attributes['src'];
              if (src == null) return [];
              final path = src.replaceAll('static', 'data');
              final json = await s.fetchJson(wcUri(s,
                  '${path.substring(0, path.lastIndexOf('/') + 1)}comics.json'));
              final data = ((json as Map)['pageProps']
                  as Map)['comicArchiveData'] as Map;
              final out = <SourceChapter>[];
              for (final year in data.keys.toList().reversed) {
                final months = data[year] as Map;
                for (final month in months.keys.toList().reversed) {
                  for (final c in (months[month] as List).reversed) {
                    final m = c as Map;
                    final fileStatic = m['file_static'] as String?;
                    final file = m['file'] as String?;
                    final img = fileStatic ??
                        (file != null && file.startsWith('http')
                            ? file
                            : 'https://files.explosm.net/comics/$file');
                    out.add(SourceChapter(
                      url: '/comics/${m['slug']}#$img',
                      name: '${m['slug']}',
                      scanlator: m['author_name'] as String?,
                      uploadedAt: DateTime.tryParse(
                          '${m['publish_at']}'.split(' ').first),
                    ));
                  }
                }
              }
              return out;
            },
            loadPages: (s, ch) async =>
                [ch.url.substring(ch.url.indexOf('#') + 1)],
          ),
        ],
      ),
      // Dark Legacy Comics
      MultiSeriesSource(
        id: 'en.darklegacycomics',
        name: 'Dark Legacy Comics',
        baseUrl: 'https://www.darklegacycomics.com',
        series: [
          SeriesDef(
            key: 'main',
            title: 'Dark Legacy Comics',
            author: 'Arad Kedar (Keydar)',
            cover: 'https://images2.imgbox.com/5d/d8/BVxRdljH_o.png',
            loadChapters: (s) async {
              final doc = (await wcGet(s, '/archive')).document;
              final seen = <String>{};
              final out = <SourceChapter>[];
              for (final it in doc.querySelectorAll('.archive_link')) {
                final index = clean(it.querySelector('.index')?.text);
                if (index.isEmpty || !seen.add(index)) continue;
                final dateEl = it.querySelector('.date');
                out.add(SourceChapter(
                  url: '/$index',
                  name: '#$index: ${clean(it.querySelector('.name')?.text)}',
                  number: double.tryParse(index),
                  scanlator: clean(it.querySelector('.characters')?.text)
                      .replaceAll(' ', ', '),
                  uploadedAt:
                      parseLooseDate(dateEl == null ? null : ownText(dateEl)),
                ));
              }
              out.sort((a, b) => (b.number ?? 0).compareTo(a.number ?? 0));
              return out;
            },
            loadPages: wcImgs('.comic > img'),
          ),
          SeriesDef(
            key: 'specials',
            title: 'Dark Legacy Comics Specials',
            author: 'Arad Kedar (Keydar)',
            cover: 'https://images2.imgbox.com/5d/d8/BVxRdljH_o.png',
            status: SourceMangaStatus.completed,
            loadChapters: (s) async => const [
              SourceChapter(url: '/specials/3', name: 'Fan Comic', number: 3),
              SourceChapter(url: '/specials/2', name: 'Rover', number: 2),
              SourceChapter(
                  url: '/specials/1', name: 'Looking For Group', number: 1),
            ],
            loadPages: wcImgs('.comic > img'),
          ),
        ],
      ),
      // Dark Science (Dresden Codak)
      MultiSeriesSource(
        id: 'en.darkscience',
        name: 'Dark Science',
        baseUrl: 'https://dresdencodak.com',
        series: [
          SeriesDef(
            key: 'ds',
            title: 'Dark Science',
            author: 'Sen (A. Senna Diaz)',
            cover:
                'https://dresdencodak.com/wp-content/uploads/2019/03/DC_CastIcon_Kimiko.png',
            genres: const ['Science Fiction', 'Mystery', 'LGBT+'],
            description:
                "Scientist Kimiko Ross has a problem: her money's gone and a bank exploded her house. "
                'With no place else to go, she travels to Nephilopolis, the city of giants.',
            loadChapters: (s) async {
              final out = <SourceChapter>[];
              Uri? next = wcUri(s, '/category/darkscience/');
              var last = 0.0;
              for (var i = 0; next != null && i < 60; i++) {
                final res = await s.fetchHtml(next);
                for (final a in res.document
                    .querySelectorAll('#content article header > h2 > a')) {
                  final title = clean(a.text);
                  final href = attrAbs(a, 'href', res.url);
                  if (href == null) continue;
                  final n = double.tryParse(RegExp(r'Dark Science #(\d+)')
                              .firstMatch(title)
                              ?.group(1) ??
                          '') ??
                      last + 0.01;
                  last = n;
                  final d = RegExp(r'/(\d{4})/(\d\d)/(\d\d)/').firstMatch(href);
                  out.add(SourceChapter(
                    url: href,
                    name: title,
                    number: n,
                    uploadedAt: d == null
                        ? null
                        : DateTime.tryParse('${d[1]}-${d[2]}-${d[3]}'),
                  ));
                }
                final nx = attrAbs(
                    res.document.querySelector('#nav-below .nav-previous > a'),
                    'href',
                    res.url);
                next = nx == null ? null : Uri.parse(nx);
              }
              return out;
            },
            loadPages: (s, ch) async {
              final res = await wcGet(s, ch.url);
              final u = imgAttr(
                  res.document.querySelector('article.post img.aligncenter'),
                  res.url);
              return u == null ? <String>[] : [u];
            },
          ),
        ],
      ),
      // El Goonish Shive
      MultiSeriesSource(
        id: 'en.egscomics',
        name: 'El Goonish Shive',
        baseUrl: 'https://www.egscomics.com',
        series: [
          for (final (key, title, path) in const [
            ('main', 'El Goonish Shive', '/comic/archive'),
            ('np', 'El Goonish Shive: NewsPaper', '/egsnp/archive'),
            ('sketch', 'El Goonish Shive Sketchbook', '/sketchbook/archive'),
          ])
            SeriesDef(
              key: key,
              title: title,
              author: 'Dan Shive',
              cover:
                  'https://static.tumblr.com/8cee5e83d26a8a96ad5e51b67f2e340e/j8ipbno/fXFoj0zh9/tumblr_static_1f2fhwjyya74gsgs888g8k880.png',
              description:
                  'El Goonish Shive is a comic about a group of teenagers who face both real life and bizarre, '
                  'supernatural situations.',
              loadChapters: (s) async {
                final doc = (await wcGet(s, path)).document;
                final out = <SourceChapter>[];
                var i = 0;
                for (final o
                    in doc.querySelectorAll('select[name=comic] option')) {
                  final v = o.attributes['value'] ?? '';
                  if (!RegExp(r'^(comic|egsnp|sketchbook)').hasMatch(v))
                    continue;
                  final parts = clean(o.text).split(' - ');
                  out.add(SourceChapter(
                    url: '/$v',
                    name: parts.length > 1
                        ? parts.sublist(1).join(' - ')
                        : parts.first,
                    number: (++i).toDouble(),
                    uploadedAt: parseLooseDate(parts.first),
                  ));
                }
                return out.reversed.toList();
              },
              loadPages: wcImgs('#cc-comic'),
            ),
        ],
      ),
      // Elan School
      MultiSeriesSource(
        id: 'en.elanschool',
        name: 'Elan School',
        baseUrl: 'https://elan.school',
        series: [
          SeriesDef(
            key: 'elan',
            title: 'Elan School',
            author: 'Joe Nobody',
            cover:
                'https://elan.school/wp-content/uploads/2018/11/The-Elan-School-Comic-1cNEW-1-768x1491.jpg',
            description:
                'A 16 year old boy named Joe gets indoctrinated into a sick cult that is run by imprisoned '
                'teenagers. Based on the true story of the Elan School.',
            loadChapters: (s) async {
              final out = <SourceChapter>[];
              Uri? next = wcUri(s, '/chapters/?dps_paged=1');
              for (var i = 0; next != null && i < 40; i++) {
                final res = await s.fetchHtml(next);
                final items =
                    res.document.querySelectorAll('div.listing-item > a.title');
                if (items.isEmpty) break;
                for (final a in items) {
                  final href = attrAbs(a, 'href', res.url);
                  if (href != null)
                    out.add(SourceChapter(url: href, name: clean(a.text)));
                }
                final nx = attrAbs(
                    res.document.querySelector('a.next'), 'href', res.url);
                next = nx == null ? null : Uri.parse(nx);
              }
              return out.reversed.toList();
            },
            loadPages: (s, ch) async {
              final res = await wcGet(s, ch.url);
              return [
                for (final img
                    in res.document.querySelectorAll('img[data-orig-file]'))
                  if (img.parent?.localName != 'a')
                    if (imgAttr(img, res.url) case final u?) u,
              ];
            },
          ),
        ],
      ),
      // Existential Comics
      MultiSeriesSource(
        id: 'en.existentialcomics',
        name: 'Existential Comics',
        baseUrl: 'https://existentialcomics.com',
        series: [
          SeriesDef(
            key: 'ec',
            title: 'Existential Comics',
            author: 'Corey Mohler',
            cover: 'https://i.ibb.co/pykMVYM/existential-comics.png',
            description:
                'A philosophy comic about the inevitable anguish of living a brief life in an absurd world. Also Jokes.',
            loadChapters: (s) async {
              final res = await wcGet(s, '/archive/byDate');
              final seen = <String>{};
              final out = <SourceChapter>[];
              for (final li
                  in res.document.querySelectorAll('div#date-comics ul li')) {
                final a = li.querySelector('a');
                final href = a?.attributes['href'];
                if (a == null || href == null || !seen.add(href)) continue;
                out.add(SourceChapter(
                    url: href,
                    name: clean(a.text),
                    number: double.tryParse(href.split('/').last)));
              }
              return out.reversed.toList();
            },
            loadPages: wcImgs('.comicImg'),
          ),
        ],
      ),
      // Gunnerkrigg Court
      MultiSeriesSource(
        id: 'en.gunnerkriggcourt',
        name: 'Gunnerkrigg Court',
        baseUrl: 'https://www.gunnerkrigg.com',
        series: [
          SeriesDef(
            key: 'gc',
            title: 'Gunnerkrigg Court',
            author: 'Tom Siddell',
            cover: 'https://i.imgur.com/g2ukAIKh.jpg',
            description:
                'Gunnerkrigg Court is a Science Fantasy webcomic by Tom Siddell about a strange young girl '
                'attending an equally strange school.',
            loadChapters: (s) async {
              final doc = (await wcGet(s, '/archives/')).document;
              final out = <SourceChapter>[];
              for (final o in doc.querySelectorAll('div.chapters option')) {
                final v = o.attributes['value'] ?? '';
                final n = double.tryParse(v);
                if (n == null) continue;
                final title = clean(o.parent?.previousElementSibling?.text);
                out.add(SourceChapter(
                    url: '/?p=$v',
                    name: '${title.isEmpty ? 'Chapter' : title} (${n.toInt()})',
                    number: n));
              }
              return out.reversed.toList();
            },
            loadPages: wcImgs('.comic_image'),
          ),
        ],
      ),
      // Loading Artist
      MultiSeriesSource(
        id: 'en.loadingartist',
        name: 'Loading Artist',
        baseUrl: 'https://loadingartist.com',
        series: [
          SeriesDef(
            key: 'la',
            title: 'Loading Artist',
            author: 'Loading Artist',
            cover: 'https://loadingartist.com/img/bg/logo-text_dark.png',
            loadChapters: (s) async {
              final list =
                  jsonDecode(await s.fetchText(wcUri(s, '/search.json')))
                      as List;
              return [
                for (final c in list)
                  if (const {'comic', 'game', 'art'}
                      .contains((c as Map)['section']))
                    SourceChapter(
                      url: '${c['url']}',
                      name: '${c['title']}',
                      uploadedAt: DateTime.tryParse('${c['date'] ?? ''}'),
                    ),
              ];
            },
            loadPages: wcImgs('div.main-image-container img'),
          ),
        ],
      ),
    ];
