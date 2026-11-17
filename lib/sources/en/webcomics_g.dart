// Situs katalog (bagian G), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0): infinitescan, clowncorps,
// arknightscomics, clonemanga, aurora, darthsdroids.

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import 'fn_source.dart';
import 'multi_series.dart';

const _small = {'a', 'an', 'and', 'as', 'at', 'by', 'for', 'in', 'of', 'on', 'or', 'the', 'to'};

String _title(String slug) {
  final words = slug.split('-');
  return [
    for (var i = 0; i < words.length; i++)
      if (i > 0 && _small.contains(words[i])) words[i] else words[i].replaceRange(0, words[i].isEmpty ? 0 : 1, words[i].isEmpty ? '' : words[i][0].toUpperCase()),
  ].join(' ');
}

Future<MangaPage> _filtered(FnSource s, String q) async {
  final all = await s.popular(1);
  return MangaPage([
    for (final m in all.items)
      if (m.title.toLowerCase().contains(q.toLowerCase())) m,
  ], hasNextPage: false);
}

class _InfiniteSite {
  _InfiniteSite(this.series, this.imageHost);
  final List<String> series;
  final String imageHost;
}

_InfiniteSite? _infinite;

Future<Map<String, dynamic>?> _counts(FnSource s, String slug) async {
  try {
    final j = await s.fetchJson(Uri.parse('${s.baseUrl}/json/$slug.json')) as Map;
    final m = j[slug];
    return m is Map ? m.cast<String, dynamic>() : null;
  } catch (_) {
    return null;
  }
}

Future<_InfiniteSite> _infiniteSite(FnSource s, {bool refresh = false}) async {
  if (!refresh && _infinite != null) return _infinite!;
  final home = await s.fetchHtml(Uri.parse('${s.baseUrl}/'));
  final src = attrAbs(home.document.querySelector('script[type=module][src]'), 'src', home.url);
  final script = await s.fetchText(Uri.parse(src!));
  final slugs = RegExp(r'/gallery/([a-z0-9]+(?:-[a-z0-9]+)*)\.webp').allMatches(script).map((m) => m[1]!).toSet().toList();
  final ok = slugs;
  final host = RegExp(r'https://pub-[0-9a-f]+\.r2\.dev').firstMatch(script)?[0] ?? '';
  return _infinite = _InfiniteSite(ok, host);
}

List<MangaSource> webcomicsG() => [
      // Infinite-Scan
      FnSource(
        id: 'en.infinitescan',
        name: 'Infinite-Scan',
        baseUrl: 'https://www.infinite-scan.com',
        popularFn: (s, page) async {
          if (page > 1) return const MangaPage([], hasNextPage: false);
          final site = await _infiniteSite(s, refresh: true);
          return MangaPage([
            for (final slug in site.series)
              SourceManga(url: '/$slug', title: _title(slug), thumbnailUrl: '${s.baseUrl}/gallery/$slug.webp'),
          ], hasNextPage: false);
        },
        searchFn: (s, page, q) => _filtered(s, q),
        detailsFn: (s, url) async {
          final slug = url.replaceFirst('/', '');
          final counts = await _counts(s, slug);
          if (counts == null) throw Exception("This series isn't on the site anymore");
          final numbers = [
            for (final k in counts.keys)
              if (int.tryParse(k.replaceFirst('chapter_', '')) case final n?) n,
          ]..sort((a, b) => b.compareTo(a));
          return SourceMangaDetails(
            url: url,
            title: _title(slug),
            thumbnailUrl: '${s.baseUrl}/gallery/$slug.webp',
            chapters: [for (final n in numbers) SourceChapter(url: '/$slug/$n', name: 'Chapter $n', number: n.toDouble())],
          );
        },
        pagesFn: (s, ch) async {
          final parts = ch.url.replaceFirst('/', '').split('/');
          final key = 'chapter_${parts[1].padLeft(3, '0')}';
          final counts = await _counts(s, parts[0]);
          final count = (counts?[key] as num?)?.toInt();
          if (count == null) throw Exception("This chapter isn't on the site anymore");
          final host = (await _infiniteSite(s)).imageHost;
          final folder = '$host/book/${parts[0]}/${key[0].toUpperCase()}${key.substring(1)}';
          return [for (var p = 1; p <= count; p++) '$folder/${p.toString().padLeft(2, '0')}.webp'];
        },
      ),
      // Clown Corps
      MultiSeriesSource(
        id: 'en.clowncorps',
        name: 'Clown Corps',
        baseUrl: 'https://clowncorps.net',
        series: [
          SeriesDef(
            key: 'cc',
            title: 'Clown Corps',
            author: 'Clown Corps',
            cover: 'https://clowncorps.net/wp-content/uploads/2022/11/clowns41.jpg',
            loadChapters: (s) async {
              final first = await wcGet(s, '/comic');
              final ind = clean(first.document.querySelector('#paginav li.paginav-pages')?.text);
              final total = int.tryParse(ind.split(' ').last) ?? 1;
              final out = <SourceChapter>[];
              final seen = <String>{};
              for (var p = 1; p <= total && p <= 80; p++) {
                final doc = p == 1 ? first : await wcGet(s, '/comic/page/$p/');
                var added = false;
                for (final c in doc.document.querySelectorAll('.comic')) {
                  final a = c.querySelector('.post-title a');
                  final href = attrAbs(a, 'href', doc.url);
                  if (a == null || href == null || !seen.add(href)) continue;
                  added = true;
                  out.add(SourceChapter(
                    url: href,
                    name: clean(a.text),
                    uploadedAt: parseLooseDate('${clean(c.querySelector('.post-date')?.text)}'),
                  ));
                }
                if (!added) break;
              }
              return out;
            },
            loadPages: wcImgs('#comic img'),
          ),
        ],
      ),
      // Arknights Comics
      FnSource(
        id: 'en.arknightscomics',
        name: 'Arknights Comics',
        baseUrl: 'https://arknights.global',
        popularFn: (s, page) async {
          if (page > 1) return const MangaPage([], hasNextPage: false);
          return MangaPage([for (final c in await _arkComics(s)) _arkManga(c)], hasNextPage: false);
        },
        searchFn: (s, page, q) async => MangaPage([
          for (final c in await _arkComics(s))
            if ('${c['name']}'.toLowerCase().contains(q.toLowerCase())) _arkManga(c),
        ], hasNextPage: false),
        detailsFn: (s, url) async {
          final name = Uri.parse(url).queryParameters['name'] ?? '';
          final comics = await _arkComics(s);
          final c = comics.firstWhere((e) => e['name'] == name, orElse: () => comics.first);
          final r = await s.fetchJson(Uri.parse('${s.baseUrl}/api/resource/comic/details')
              .replace(queryParameters: {'name': name, 'index': '1', 'size': '9999'})) as Map;
          final rows = ((r['data'] as Map)['rows'] as List).cast<Map>();
          rows.sort((a, b) => (b['chapter'] as num).compareTo(a['chapter'] as num));
          return SourceMangaDetails(
            url: url,
            title: '${c['name']}',
            thumbnailUrl: _arkCover(c),
            description: _arkDesc(c),
            chapters: [
              for (final ch in rows)
                SourceChapter(
                  url: '/comic-detail?name=${Uri.encodeQueryComponent(name)}&chapter=${ch['chapter']}',
                  name: '${ch['detailsName']}',
                  number: (ch['chapter'] as num).toDouble(),
                  uploadedAt: DateTime.fromMillisecondsSinceEpoch(((ch['publishTime'] as num).toInt()) * 1000),
                ),
            ],
          );
        },
        pagesFn: (s, ch) async {
          final q = Uri.parse('${s.baseUrl}${ch.url}').queryParameters;
          final r = await s.fetchJson(Uri.parse('${s.baseUrl}/api/resource/comic/details')
              .replace(queryParameters: {'name': q['name']!, 'index': '1', 'size': '9999', 'chapter': q['chapter']!})) as Map;
          final rows = ((r['data'] as Map)['rows'] as List).cast<Map>();
          return [for (final row in rows) for (final i in (row['detailsContent'] as List)) '$i'];
        },
      ),
      // Clone Manga
      FnSource(
        id: 'en.clonemanga',
        name: 'Clone Manga',
        baseUrl: 'https://manga.clone-army.org',
        popularFn: (s, page) async {
          if (page > 1) return const MangaPage([], hasNextPage: false);
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/viewer_landing.php'));
          final items = <SourceManga>[];
          for (final e in res.document.querySelectorAll('.comicPreviewContainer')) {
            final a = e.querySelector('a');
            final href = a?.attributes['href'];
            final style = e.querySelector('.comicPreview')?.attributes['style'] ?? '';
            final i = style.indexOf('site/themes');
            final j = style.indexOf(')');
            if (href == null) continue;
            items.add(SourceManga(
              url: '${s.baseUrl}/${href.replaceFirst(RegExp(r'^/'), '')}',
              title: clean(e.querySelector('h3')?.text),
              thumbnailUrl: i >= 0 && j > i ? '${s.baseUrl}/${style.substring(i, j)}' : null,
            ));
          }
          return MangaPage(items, hasNextPage: false);
        },
        searchFn: (s, page, q) => _filtered(s, q),
        detailsFn: (s, url) async {
          final res = await s.fetchHtml(Uri.parse(url));
          final scripts = res.document.getElementsByTagName('script');
          final text = scripts.length > 3 ? scripts[3].text : res.body;
          final all = RegExp(r'&page=(.*?)&lang=').allMatches(text).toList();
          final n = all.length > 3 ? int.tryParse(all[3][1]!) ?? 1 : (all.isNotEmpty ? int.tryParse(all.last[1]!) ?? 1 : 1);
          final base = res.url.toString();
          return SourceMangaDetails(
            url: url,
            title: clean(res.document.querySelector('h3, h2, title')?.text),
            author: 'Dan Kim',
            artist: 'Dan Kim',
            chapters: [
              for (var i = n; i >= 1; i--) SourceChapter(url: '$base&page=$i', name: 'Chapter $i', number: i.toDouble()),
            ],
          );
        },
        pagesFn: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse(ch.url));
          final img = res.document.querySelector('.subsectionContainer img');
          final u = imgAttr(img, res.url);
          return u == null ? <String>[] : [u];
        },
      ),
      // aurora (setiap bab arsip jadi satu judul, halaman jadi bab)
      FnSource(
        id: 'en.aurora',
        name: 'aurora',
        baseUrl: 'https://comicaurora.com',
        popularFn: (s, page) async {
          if (page > 1) return const MangaPage([], hasNextPage: false);
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/archive/'));
          final items = <SourceManga>[];
          for (final b in res.document.querySelectorAll('.wp-block-image')) {
            final a = b.querySelector('a');
            final href = attrAbs(a, 'href', res.url);
            if (a == null || href == null) continue;
            items.add(SourceManga(
              url: href,
              title: 'aurora - ${clean(a.text)}',
              thumbnailUrl: imgAttr(b.querySelector('img'), res.url),
            ));
          }
          return MangaPage(items, hasNextPage: false);
        },
        searchFn: (s, page, q) => _filtered(s, q),
        detailsFn: (s, url) async {
          final first = await s.fetchHtml(Uri.parse(url));
          final pageUrls = <String>[url];
          for (final a in first.document.querySelectorAll('#paginav a[title]').skip(1)) {
            final h = attrAbs(a, 'href', first.url);
            if (h != null) pageUrls.add(h);
          }
          final out = <SourceChapter>[];
          for (final u in pageUrls) {
            final r = u == url ? first : await s.fetchHtml(Uri.parse(u));
            for (final p in r.document.querySelectorAll('.post-content')) {
              final link = attrAbs(p.querySelector('a.webcomic-link'), 'href', r.url);
              final title = clean(p.querySelector('.post-title a')?.text);
              if (link == null) continue;
              final n = double.tryParse(title.contains('.') ? title.substring(title.indexOf('.') + 1).split('-').first.trim() : '');
              out.add(SourceChapter(
                url: link,
                name: title,
                number: n,
                uploadedAt: parseLooseDate(clean(p.querySelector('.post-date')?.text)),
              ));
            }
          }
          return SourceMangaDetails(
            url: url,
            title: clean(first.document.querySelector('title')?.text),
            author: 'OSP-Red',
            genres: const ['fantasy'],
            description: 'Aurora is a fantasy webcomic (updates M/W/F) written and illustrated by Red, '
                'better known for her work on the YouTube channel "Overly Sarcastic Productions."',
            chapters: out.reversed.toList(),
          );
        },
        pagesFn: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse(ch.url));
          return [
            for (final img in res.document.querySelectorAll('.webcomic-media .webcomic-link .attachment-full'))
              if (imgAttr(img, res.url) case final u?) u,
          ];
        },
      ),
      // Darths & Droids
      FnSource(
        id: 'en.darthsdroids',
        name: 'Darths & Droids',
        baseUrl: 'https://www.darthsanddroids.net',
        popularFn: (s, page) async {
          if (page > 1) return const MangaPage([], hasNextPage: false);
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/archive.html'));
          final items = <SourceManga>[];
          var nextTitle = 'Darths & Droids';
          for (final tr in res.document.querySelectorAll('div.text > table.text tr')) {
            final th = tr.querySelector('th');
            if (th != null) {
              nextTitle = 'Darths & Droids ${clean(th.text)}';
              continue;
            }
            final a = tr.querySelector('td[colspan="3"] > a');
            final href = attrAbs(a, 'href', res.url);
            if (href != null) {
              items.add(SourceManga(url: '$href#${Uri.encodeComponent(nextTitle)}', title: nextTitle));
            } else if (tr.querySelector('td[colspan]') == null || a == null) {
              if (tr.querySelectorAll('td').length >= 3) {
                items.add(SourceManga(url: '${s.baseUrl}/archive.html#${Uri.encodeComponent(nextTitle)}', title: nextTitle));
                break;
              }
            }
          }
          return MangaPage(items, hasNextPage: false);
        },
        searchFn: (s, page, q) => _filtered(s, q),
        detailsFn: (s, url) async {
          final hash = url.indexOf('#');
          final archive = hash < 0 ? url : url.substring(0, hash);
          final title = hash < 0 ? 'Darths & Droids' : Uri.decodeComponent(url.substring(hash + 1));
          final res = await s.fetchHtml(Uri.parse(archive));
          final out = <SourceChapter>[];
          var i = 0;
          for (final tr in res.document.querySelectorAll('div.text > table.text tr')) {
            final tds = tr.querySelectorAll('td');
            final a = tds.length > 2 ? tds[2].querySelector('a') : null;
            if (a != null) {
              final href = attrAbs(a, 'href', res.url);
              if (href != null) {
                out.add(SourceChapter(url: href, name: clean(a.text), number: (i++).toDouble(), uploadedAt: parseLooseDate(clean(tds[0].text))));
              }
            } else if (tds.isNotEmpty && tds.first.attributes['colspan'] == null) {
              final a0 = tds.first.querySelector('a');
              final href = attrAbs(a0, 'href', res.url);
              if (a0 != null && href != null) out.add(SourceChapter(url: href, name: clean(a0.text), number: (i++).toDouble()));
            }
          }
          return SourceMangaDetails(
            url: url,
            title: title,
            author: 'David Morgan-Mar & Co.',
            artist: 'David Morgan-Mar & Co.',
            genres: const ['Campaign Comic', 'Comedy', 'Space Opera', 'Science Fiction'],
            chapters: out.reversed.toList(),
          );
        },
        pagesFn: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse(ch.url));
          return [
            for (final img in res.document.querySelectorAll('div.center img'))
              if (imgAttr(img, res.url) case final u?) u,
          ];
        },
      ),
    ];

Future<List<Map>> _arkComics(FnSource s) async {
  final j = await s.fetchJson(Uri.parse('${s.baseUrl}/api/resource/comic/list')) as Map;
  return (((j['data'] as Map)['rows']) as List).cast<Map>();
}

String? _arkCover(Map c) {
  final v = c['smallImage'];
  if (v is List) return v.isEmpty ? null : '${v.first}';
  return v == null ? null : '$v';
}

String? _arkDesc(Map c) {
  final d = c['comicDescribe'];
  return d == null ? null : clean(d.toString().replaceAll(RegExp(r'<[^>]*>'), ' '));
}

SourceManga _arkManga(Map c) => SourceManga(
      url: '/comic?name=${Uri.encodeQueryComponent('${c['name']}')}',
      title: '${c['name']}',
      thumbnailUrl: _arkCover(c),
    );
