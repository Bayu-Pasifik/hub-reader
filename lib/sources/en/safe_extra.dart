// Sumber kelompok Aman (seri-bab HTML), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0): src/en/*.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import 'chapter_source.dart';
import 'fn_source.dart';
import 'gallery_source.dart';
import 'single_series.dart';

List<MangaSource> safeExtra() => [
      ChapterSource(
        id: 'en.demonicscans',
        name: 'Manga Demon',
        baseUrl: 'https://demonicscans.org',
        contentWarning: ContentWarning.safe,
        popularUrl: (b, p) => '$b/advanced.php?list=$p&status=all&orderby=VIEWS%20DESC',
        searchUrl: (b, p, q) => p > 1 ? null : '$b/search.php?manga=${Uri.encodeQueryComponent(q)}',
        cardSel: 'div.advanced-element, a[href^="/manga/"]',
        cardLinkSel: 'a[href^="/manga/"]',
        cleanTitle: (t) => t.replaceFirst(RegExp(r'\s+\d{3,}$'), ''),
        nextSel: 'a[href*="advanced.php?list="]',
        titleSel: 'meta[property="og:title"]',
        coverSel: 'meta[property="og:image"]',
        tagSel: '.genres-list li',
        chapterSel: 'a.chplinks',
        imagesOf: (d, u) => imagesFrom(d, u, 'img.imgholder[src*="/"]', ['src'])
            .where((e) => !e.contains('/img/')).toList(),
      ),
      ChapterSource(
        id: 'en.comichubfree',
        name: 'ComicHubFree',
        baseUrl: 'https://comichubfree.com',
        contentWarning: ContentWarning.safe,
        popularUrl: (b, p) => '$b/popular-comic?page=$p',
        latestUrl: (b, p) => '$b/new-comic?page=$p',
        searchUrl: (b, p, q) => '$b/search-comic?key=${Uri.encodeQueryComponent(q)}&page=$p',
        cardSel: 'div.cartoon-box',
        cardLinkSel: 'h3 a',
        cardTitleSel: 'h3 a',
        cardThumbSel: 'img.lazyload',
        titleSel: 'meta[property="og:title"]',
        coverSel: 'meta[property="og:image"]',
        chapterSel: 'a[href*="/issue-"]',
        chapterUrlOf: (h) => h.endsWith('/all') ? h : '$h/all',
        imagesOf: (d, u) => imagesFrom(d, u, 'img.chapter_img', ['data-src', 'src']),
      ),
      ChapterSource(
        id: 'en.comivex',
        name: 'Comivex',
        baseUrl: 'https://comivex.com',
        contentWarning: ContentWarning.safe,
        popularUrl: (b, p) => '$b/latest/?page=$p',
        searchUrl: (b, p, q) => null,
        localSearch: true,
        cardSel: '.u-card',
        cardLinkSel: 'a.u-card__title',
        cardTitleSel: 'a.u-card__title',
        cardThumbSel: 'img.u-card__img',
        nextSel: 'a[rel=next], a.next, a[href*="page="][aria-label*="ext"]',
        titleSel: 'meta[property="og:title"]',
        coverSel: 'meta[property="og:image"]',
        chapterSel: 'a.ch-link',
        cleanTitle: (t) => t.replaceFirst(RegExp(r'\s+—\s+Read.*$'), ''),
        imagesOf: (d, u) => imagesFrom(d, u, 'img[src*="/cdn_"], img[src*="/chapter-"]', ['src']),
      ),
      ChapterSource(
        id: 'en.mangabolt',
        name: 'MangaBolt',
        baseUrl: 'https://mangabolt.com',
        contentWarning: ContentWarning.safe,
        popularUrl: (b, p) => '$b/directory?page=$p',
        latestUrl: (b, p) => '$b/new-manga?page=$p',
        searchUrl: (b, p, q) => '$b/search?q=${Uri.encodeQueryComponent(q)}&page=$p',
        cardSel: 'article.series-card',
        cardLinkSel: 'a.cover-link',
        cardTitleSel: 'a.cover-link img',
        nextSel: 'link[rel=next], a[rel=next]',
        titleSel: 'h1',
        coverSel: 'meta[property="og:image"]',
        chapterSel: '#chapter-list a[href^="/chapters/"]',
        cleanTitle: (t) => t.replaceFirst(RegExp(r'^Cover for\s+'), '').replaceFirst(RegExp(r'\s+Manga \| MangaBolt$'), ''),
        imagesOf: (d, u) => imagesFrom(d, u, 'img[src*="cdn.mangabolt.com"]', ['src']),
      ),
      ChapterSource(
        id: 'en.philiascans',
        name: 'Philia Scans',
        baseUrl: 'https://philiascans.org',
        contentWarning: ContentWarning.safe,
        popularUrl: (b, p) => '$b/all-mangas?page=$p',
        searchUrl: (b, p, q) => '$b/all-mangas?s=${Uri.encodeQueryComponent(q)}&page=$p',
        cardSel: 'a.manga-card',
        cardTitleSel: '.card-title',
        nextSel: 'a[rel=next], link[rel=next]',
        thumbFromUrl: (u) => '${u.replaceFirst(RegExp(r'/series/.*$'), '')}/api/covers/${u.split('/').last}',
        titleSel: 'h1',
        coverSel: 'meta[property="og:image"]',
        chapterSel: 'a[href*="/chapter-"]',
        chapterUrlOf: (h) => h.contains('?') ? h : '$h?lang=en',
        imagesOf: (d, u) {
          final seen = <String>{};
          return [
            for (final m in RegExp(r'src\\?":\\?"(https://media\.philiascans\.org/api/media/chapters/(?:[^"\\]|\\u0026)+)').allMatches(d.outerHtml))
              if (seen.add(m[1]!)) m[1]!.replaceAll(String.fromCharCode(92) + 'u0026', '&').replaceAll('&amp;', '&'),
          ];
        },
      ),
      FnSource(
        id: 'en.oriyami',
        name: 'OriYami',
        baseUrl: 'https://oriyami.com',
        contentWarning: ContentWarning.safe,
        popularFn: (s, page) => _oriList(s, page, ''),
        searchFn: (s, page, q) => _oriList(s, page, q),
        detailsFn: (s, url) async {
          final res = await s.fetchHtml(Uri.parse(url));
          final doc = res.document;
          final title = clean(doc.querySelector('meta[property="og:title"]')?.attributes['content'] ?? doc.querySelector('h1')?.text)
              .replaceFirst(RegExp(r'\s*[|\-–]\s*(Read|OriYami).*$'), '');
          final seen = <String>{};
          final chapters = <SourceChapter>[];
          for (final a in doc.querySelectorAll('a[href*="/chapter-"]')) {
            final href = attrAbs(a, 'href', res.url);
            final m = href == null ? null : RegExp(r'/chapter-(\d+(?:[.-]\d+)?)/?$').firstMatch(href);
            if (href == null || m == null || !seen.add(href)) continue;
            final num = m[1]!.replaceAll('-', '.');
            chapters.add(SourceChapter(url: href, name: 'Chapter $num', number: double.tryParse(num)));
          }
          chapters.sort((a, b) => (b.number ?? 0).compareTo(a.number ?? 0));
          return SourceMangaDetails(
            url: url,
            title: title.isEmpty ? url.split('/').last : title,
            thumbnailUrl: attrAbs(doc.querySelector('meta[property="og:image"]'), 'content', res.url),
            description: clean(doc.querySelector('meta[property="og:description"]')?.attributes['content']),
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse(ch.url));
          final seen = <String>{};
          final num = RegExp(r'chapter-(\d+(?:[.-]\d+)?)/?$').firstMatch(ch.url)?[1]?.replaceAll('-', '.');
          return [
            for (final m in RegExp(r'https://cdn\.oriyami\.com/(?:manga|manhua|manhwa|digital-comic)/[^"\\\s/]+/([^"\\\s/]+)/[^"\\\s]+\.(?:jpe?g|png|webp)')
                .allMatches(res.document.outerHtml))
              if ((num == null || m[1] == num) && seen.add(m[0]!)) m[0]!,
          ];
        },
      ),
      FnSource(
        id: 'en.luminaretranslations',
        name: 'Luminare Translations',
        baseUrl: 'https://luminaretranslations.com',
        contentWarning: ContentWarning.safe,
        popularFn: (s, page) => _luminareList(s, page, ''),
        searchFn: (s, page, q) => _luminareList(s, page, q),
        detailsFn: (s, url) async {
          final slug = Uri.parse(url).pathSegments.where((e) => e.isNotEmpty).last;
          final info = ((await s.fetchJson(Uri.parse('${s.baseUrl}/wp-json/yarnovel/v1/series/$slug'))) as Map)['data'] as Map;
          final list = ((await s.fetchJson(Uri.parse('${s.baseUrl}/wp-json/yarnovel/v1/series/$slug/chapters?per_page=500'))) as Map)['data'] as List;
          final chapters = [
            for (final c in list.cast<Map>())
              SourceChapter(
                url: '${c['url']}',
                name: c['title'] == null ? 'Chapter ${c['number']}' : 'Chapter ${c['number']}: ${c['title']}',
                number: (c['number'] as num?)?.toDouble(),
                uploadedAt: DateTime.tryParse('${c['published_at']}'),
              ),
          ]..sort((a, b) => (b.number ?? 0).compareTo(a.number ?? 0));
          return SourceMangaDetails(
            url: url,
            title: clean('${info['title']}'),
            thumbnailUrl: info['cover_image'] as String?,
            description: clean('${info['excerpt'] ?? ''}'),
            author: info['author'] as String?,
            genres: [for (final g in (info['genres'] as List? ?? const [])) '$g'],
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final id = Uri.parse(ch.url).pathSegments.where((e) => e.isNotEmpty).last;
          final data = ((await s.fetchJson(Uri.parse('${s.baseUrl}/wp-json/yarnovel/v1/chapters/$id'))) as Map)['data'] as Map;
          final doc = html_parser.parse('${data['content']}');
          return imagesFrom(doc, Uri.parse(s.baseUrl), 'img', ['src', 'data-src']);
        },
      ),
      FnSource(
        id: 'en.leslievictims',
        name: 'Leslie&Victims',
        baseUrl: 'https://leslie-victims.pages.dev',
        contentWarning: ContentWarning.mixed,
        popularFn: (s, page) async => _lesliePage(s, await _leslieLibrary(s), '', page),
        searchFn: (s, page, q) async => _lesliePage(s, await _leslieLibrary(s), q, page),
        detailsFn: (s, url) async {
          final id = Uri.decodeComponent(url.split('#').last);
          final m = (await _leslieLibrary(s)).firstWhere((e) => '${e['id']}' == id);
          final chapters = [
            for (final c in (m['chapters'] as List).cast<Object>())
              SourceChapter(
                url: '${s.baseUrl}/#${Uri.encodeComponent(id)}/${Uri.encodeComponent('$c')}',
                name: 'Chapter $c',
                number: double.tryParse(RegExp(r'^\d+(?:\.\d+)?').firstMatch('$c')?[0] ?? ''),
              ),
          ].reversed.toList();
          return SourceMangaDetails(
            url: url,
            title: '${m['title']}',
            thumbnailUrl: m['cover'] == null ? null : '${s.baseUrl}/${Uri.encodeFull('${m['cover']}')}',
            chapters: chapters,
          );
        },
        pagesFn: _lesliePages,
      ),
      FnSource(
        id: 'en.warforrayuba',
        name: 'War For Rayuba',
        baseUrl: 'https://xrabohrok.github.io/WarMap',
        contentWarning: ContentWarning.safe,
        popularFn: (s, page) => _rayubaList(s, page, ''),
        searchFn: (s, page, q) => _rayubaList(s, page, q),
        detailsFn: (s, url) async {
          final id = url.split('/').where((e) => e.isNotEmpty).last;
          final g = await _gist(s, id);
          final chapters = <SourceChapter>[];
          for (final e in (g['chapters'] as Map).entries) {
            final c = e.value as Map;
            final num = double.tryParse('${e.key}');
            final title = clean('${c['title'] ?? ''}');
            chapters.add(SourceChapter(
              url: '$url#${e.key}',
              name: title.isEmpty ? 'Chapter ${e.key}' : 'Chapter ${e.key}: $title',
              number: num,
            ));
          }
          chapters.sort((a, b) => (b.number ?? 0).compareTo(a.number ?? 0));
          return SourceMangaDetails(
            url: url,
            title: clean('${g['title']}'),
            thumbnailUrl: g['cover'] as String?,
            description: clean('${g['description'] ?? ''}'),
            author: g['author'] as String?,
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final parts = ch.url.split('#');
          final id = parts.first.split('/').where((e) => e.isNotEmpty).last;
          final key = parts.last;
          final g = await _gist(s, id);
          final groups = ((g['chapters'] as Map)[key] as Map)['groups'] as Map;
          final v = groups.values.first;
          Object? items = v;
          if (v is String) {
            items = await s.fetchJson(Uri.parse('https://cubari.moe${v.replaceFirst('/proxy/', '/read/')}'));
          }
          return [
            for (final p in (items as List))
              if (p is Map) '${p['src']}' else '$p',
          ];
        },
      ),
      FnSource(
        id: 'en.nuxscans',
        name: 'Nux Scans',
        baseUrl: 'https://nuxscans-comics.blogspot.com',
        contentWarning: ContentWarning.safe,
        popularFn: (s, page) async => _nuxPage(s, page, ''),
        searchFn: (s, page, q) async => _nuxPage(s, page, q),
        detailsFn: (s, url) async {
          final res = await s.fetchHtml(Uri.parse('$url?m=0'));
          final doc = res.document;
          final chapters = <SourceChapter>[];
          final seen = <String>{};
          // Daftar bab ada di dalam komentar HTML, jadi dibaca dari teks mentah.
          for (final m in RegExp(r'class="list-item[^"]*"s*>s*<a href="([^"]+)"[^>]*>([^<]+)</a>').allMatches(doc.outerHtml)) {
            final href = m[1]!;
            if (!seen.add(href)) continue;
            final label = clean(m[2]);
            chapters.add(SourceChapter(url: href, name: 'Chapter $label', number: double.tryParse(label)));
          }
          chapters.sort((a, b) => (b.number ?? 0).compareTo(a.number ?? 0));
          final feed = await _nuxEntries(s);
          final e = feed.where((x) => x.url == url).firstOrNull;
          return SourceMangaDetails(
            url: url,
            title: clean(doc.querySelector('meta[property="og:title"]')?.attributes['content']),
            thumbnailUrl: e?.thumbnailUrl,
            genres: e?.genres ?? const [],
            status: e?.status ?? SourceMangaStatus.unknown,
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse('${ch.url}?m=0'));
          return imagesFrom(res.document, res.url, '.post-content img[src*="googleusercontent"]', ['src']);
        },
      ),
      FnSource(
        id: 'en.kappabeast',
        name: 'Kappa Beast',
        baseUrl: 'https://kappabeast.com',
        contentWarning: ContentWarning.safe,
        popularFn: (s, page) => _kappaList(s, page, '', ''),
        latestFn: (s, page) => _kappaList(s, page, '', 'updatedAt:desc'),
        searchFn: (s, page, q) => _kappaList(s, page, q, ''),
        detailsFn: (s, url) async {
          final slug = Uri.parse(url).pathSegments.last;
          final json = await s.fetchJson(_kappaApi(s, 'mangas', {
            r'filters[slug][$eq]': slug,
            'populate[media][populate]': '*',
            'populate[category][fields][0]': 'name',
            'populate[chapters][fields][0]': 'number',
            'populate[chapters][fields][1]': 'title',
            'populate[chapters][fields][2]': 'createdAt',
            'populate[chapters][sort][0]': 'number:desc',
            'pagination[pageSize]': '1',
          })) as Map;
          final d = ((json['data'] as List).first) as Map;
          final m = _kappaManga(s, d);
          final chapters = <SourceChapter>[];
          for (final c in ((d['chapters'] as List?) ?? const []).cast<Map>()) {
            final n = c['number'] as num;
            final shown = n % 1 == 0 ? n.toInt().toString() : n.toString();
            final title = clean('${c['title'] ?? ''}');
            chapters.add(SourceChapter(
              url: '${s.baseUrl}/reader/$slug/${c['number']}#${d['documentId']}',
              name: 'Chapter $shown${title.isEmpty || title == 'Chapter $shown' ? '' : ' - $title'}',
              number: n.toDouble(),
            ));
          }
          return SourceMangaDetails(
            url: m.url,
            title: m.title,
            thumbnailUrl: m.thumbnailUrl,
            description: d['description'] as String?,
            author: d['author'] as String?,
            artist: d['artist'] as String?,
            genres: [for (final c in ((d['category'] as List?) ?? const []).cast<Map>()) '${c['name']}'],
            status: switch (d['manga_status']) {
              'Ongoing' => SourceMangaStatus.ongoing,
              'Completed' => SourceMangaStatus.completed,
              'Hiatus' => SourceMangaStatus.hiatus,
              _ => SourceMangaStatus.unknown,
            },
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final u = Uri.parse(ch.url);
          final json = await s.fetchJson(_kappaApi(s, 'chapters', {
            r'filters[manga][documentId][$eq]': u.fragment,
            r'filters[number][$eq]': u.pathSegments[u.pathSegments.length - 1],
            'pagination[pageSize]': '1',
          })) as Map;
          final data = json['data'] as List;
          final htmlText = data.isEmpty ? null : (data.first as Map)['htmlContent'] as String?;
          if (htmlText == null) return const [];
          return [
            for (final a in html_parser.parse(htmlText).querySelectorAll('div.separator > a[href]'))
              _kappaFull(a.attributes['href']!),
          ];
        },
      ),
      FnSource(
        id: 'en.comicland',
        name: 'ComicLand',
        baseUrl: 'https://comicland.org',
        contentWarning: ContentWarning.safe,
        popularFn: (s, page) => _comiclandList(s, '/comics/popular', page, {}),
        latestFn: (s, page) => _comiclandList(s, '/comics', page, {'status': 'ongoing'}),
        searchFn: (s, page, q) => _comiclandList(s, '/comic/search', page, {'q': q}),
        detailsFn: (s, url) async {
          final slug = url.split('/').where((e) => e.isNotEmpty).last;
          final d = await _comiclandData(s, '/comic/detail', {'slug': slug}) as Map;
          String names(String k) => [for (final e in ((d[k] as List?) ?? const []).cast<Map>()) '${e['name']}'].join(', ');
          final chapters = [
            for (final c in ((d['chapters'] as List?) ?? const []).cast<Map>())
              SourceChapter(
                url: '${s.baseUrl}/comic/$slug/chapter/${'${c['chapter_index']}'.replaceFirst(RegExp(r'\.0$'), '')}',
                name: '${c['title']}',
                number: (c['chapter_index'] as num?)?.toDouble(),
              ),
          ].reversed.toList();
          return SourceMangaDetails(
            url: url,
            title: '${d['title']}',
            thumbnailUrl: d['cover_url'] as String?,
            description: d['description'] as String?,
            author: names('authors'),
            artist: names('artists'),
            genres: [for (final e in ((d['genres'] as List?) ?? const []).cast<Map>()) '${e['name']}'],
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final slug = ch.url.split('/comic/').last.split('/chapter/').first;
          final idx = ch.url.split('/chapter/').last;
          final d = await _comiclandData(s, '/chapter/pages_by_index', {'slug': slug, 'index': idx}) as Map;
          return [for (final p in (d['pages'] as List? ?? const [])) '$p'];
        },
      ),
      FnSource(
        id: 'en.tinyview',
        name: 'Tinyview',
        baseUrl: 'https://tinyview.com',
        contentWarning: ContentWarning.safe,
        popularFn: (s, page) async => page > 1 ? const MangaPage([], hasNextPage: false) : _tinyDirectory(s, ''),
        searchFn: (s, page, q) async => page > 1 ? const MangaPage([], hasNextPage: false) : _tinyDirectory(s, q),
        detailsFn: (s, url) async {
          final path = url.replaceFirst(s.baseUrl, '');
          final comic = await _tinyComic(s, path);
          final panels = [for (final p in (comic['panels'] as List).cast<Map>()) p];
          final series = path.replaceFirst('/', '');
          final now = DateTime.now().toUtc();
          final comics = <Map>[];
          final seen = <String>{};
          for (final p in panels) {
            final a = p['action'] as String?;
            if (a == null || !a.startsWith('/$series/') || !a.endsWith('/index.json')) continue;
            if ((p['actionType'] as String?)?.isNotEmpty == true || p['inAppProducts'] != null) continue;
            final when = DateTime.tryParse('${p['datetime']}');
            if (when != null && when.isAfter(now)) continue;
            if (seen.add(a)) comics.add(p);
          }
          final cover = panels.where((p) => p['image'] != null && p['action'] == null).firstOrNull;
          return SourceMangaDetails(
            url: url,
            title: clean('${comic['title']}'),
            thumbnailUrl: cover == null ? null : _tinyImage(s, path, '${cover['image']}'),
            description: clean(html_parser.parseFragment('${comic['description'] ?? ''}').text),
            chapters: [
              for (var i = 0; i < comics.length; i++)
                SourceChapter(
                  url: '${s.baseUrl}${(comics[i]['action'] as String).replaceFirst('/index.json', '')}',
                  name: (comics[i]['showTo'] ?? comics[i]['show-to']) == 'subscribers-only'
                      ? '🔒 ${clean('${comics[i]['title']}')}'
                      : clean('${comics[i]['title']}'),
                  number: (comics.length - i).toDouble(),
                ),
            ],
          );
        },
        pagesFn: (s, ch) async {
          final path = ch.url.replaceFirst(s.baseUrl, '');
          final comic = await _tinyComic(s, path);
          if (comic['show-to'] == 'subscribers-only') return const [];
          return [
            for (final p in (comic['panels'] as List).cast<Map>())
              if (p['image'] != null && p['action'] == null && p['template'] != 'bonus') _tinyImage(s, path, '${p['image']}'),
          ];
        },
      ),
      FnSource(
        id: 'en.manhwaz',
        name: 'ManhwaZ',
        baseUrl: 'https://manhwaz.cc',
        contentWarning: ContentWarning.safe,
        popularFn: (s, page) async {
          if (page > 1) return const MangaPage([], hasNextPage: false);
          final res = await s.fetchHtml(Uri.parse(s.baseUrl));
          return MangaPage(_manhwazCards(res.document, res.url, 'article.popular-card'), hasNextPage: false);
        },
        latestFn: (s, page) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/?page=$page'));
          return MangaPage(_manhwazCards(res.document, res.url, 'article.latest-card'),
              hasNextPage: res.document.querySelector('nav.pagination a[aria-label="Next page"]') != null);
        },
        searchFn: (s, page, q) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/search?s=${Uri.encodeQueryComponent(q)}&page=$page'));
          return MangaPage(_manhwazCards(res.document, res.url, 'article.popular-card'),
              hasNextPage: res.document.querySelector('nav.pagination a[aria-label="Next page"]') != null);
        },
        detailsFn: (s, url) async {
          var res = await s.fetchHtml(Uri.parse(url));
          final first = res.document;
          final facts = <String, Element>{};
          for (final row in first.querySelectorAll('div.series-facts dl > div')) {
            final dt = row.querySelector('dt');
            final dd = row.querySelector('dd');
            if (dt != null && dd != null) facts[clean(dt.text).toLowerCase()] = dd;
          }
          final chapters = <SourceChapter>[];
          final seen = <String>{};
          var doc = first;
          for (var i = 0; i < 80; i++) {
            for (final a in doc.querySelectorAll('a.release-row')) {
              final href = attrAbs(a, 'href', res.url);
              if (href == null || !seen.add(href)) continue;
              final label = clean(a.querySelector('strong')?.text);
              chapters.add(SourceChapter(
                url: href,
                name: label,
                number: double.tryParse(RegExp(r'(\d+(?:\.\d+)?)').firstMatch(label)?[1] ?? ''),
              ));
            }
            final next = attrAbs(doc.querySelector('nav.pagination a[aria-label="Next page"]'), 'href', res.url);
            if (next == null) break;
            res = await s.fetchHtml(Uri.parse(next));
            doc = res.document;
          }
          final h1 = first.querySelector('section.profile-manga h1');
          final statusText = clean(facts['status']?.text).toLowerCase();
          return SourceMangaDetails(
            url: url,
            title: clean(h1 == null ? '' : (h1.nodes.whereType<Text>().map((t) => t.text).join().trim().isEmpty ? h1.text : h1.nodes.whereType<Text>().map((t) => t.text).join())),
            thumbnailUrl: attrAbs(first.querySelector('div.series-cover-frame img'), 'src', res.url),
            author: clean(facts['author(s)']?.text),
            description: clean(first.querySelector('p.series-summary')?.text),
            genres: [for (final a in facts['genre(s)']?.querySelectorAll('a') ?? <Element>[]) clean(a.text)],
            status: statusText.contains('ongoing')
                ? SourceMangaStatus.ongoing
                : statusText.contains('completed')
                    ? SourceMangaStatus.completed
                    : SourceMangaStatus.unknown,
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse(ch.url));
          return [
            for (final img in res.document.querySelectorAll('div.reader-pages figure.reader-page-image img'))
              if ((attrAbs(img, 'src', res.url) ?? attrAbs(img, 'data-src', res.url)) case final u? when u.isNotEmpty) u,
          ];
        },
      ),
      FnSource(
        id: 'en.hyakuro',
        name: 'Hyakuro Translations',
        baseUrl: 'https://hyakuro.net',
        contentWarning: ContentWarning.safe,
        popularFn: (s, page) => _hyakuroList(s, page, '', 'Title:asc'),
        latestFn: (s, page) => _hyakuroList(s, page, '', 'updatedAt:desc'),
        searchFn: (s, page, q) => _hyakuroList(s, page, q, 'updatedAt:desc'),
        detailsFn: (s, url) async {
          final slug = url.split('/').where((e) => e.isNotEmpty).last;
          final a = await _hyakuroOne(s, slug, 'Cover,Chapters');
          final one = a['Oneshot'] == true;
          final chapters = <SourceChapter>[];
          for (final c in ((a['Chapters'] as List?) ?? const []).cast<Map>()) {
            final n = (c['Chapter'] as num?)?.toDouble() ?? 0;
            final shown = n % 1 == 0 ? n.toInt().toString() : n.toString();
            final title = clean('${c['Title'] ?? ''}');
            chapters.add(SourceChapter(
              url: '${s.baseUrl}/manga/$slug#${c['id']}',
              name: one
                  ? (title.isEmpty ? 'Oneshot' : 'Oneshot - $title')
                  : (title.isEmpty ? 'Chapter $shown' : 'Chapter $shown - $title'),
              number: n,
            ));
          }
          chapters.sort((x, y) => (y.number ?? 0).compareTo(x.number ?? 0));
          final m = _hyakuroManga(s, a);
          return SourceMangaDetails(
            url: m.url,
            title: m.title,
            thumbnailUrl: m.thumbnailUrl,
            author: a['Author'] as String?,
            artist: a['Artist'] as String?,
            description: a['Synopsis'] as String?,
            genres: [for (final c in ((a['Categories'] as List?) ?? const [])) '$c'],
            status: switch (a['Status']) {
              'Ongoing' => SourceMangaStatus.ongoing,
              'Completed' => SourceMangaStatus.completed,
              'Dropped' => SourceMangaStatus.cancelled,
              _ => SourceMangaStatus.unknown,
            },
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final parts = ch.url.split('#');
          final slug = parts.first.split('/').where((e) => e.isNotEmpty).last;
          final id = int.parse(parts.last);
          final a = await _hyakuroOne(s, slug, '*', key: 'populate[Chapters][populate]');
          final c = ((a['Chapters'] as List).cast<Map>()).firstWhere((e) => e['id'] == id);
          final pages = (((c['Pages'] as Map?)?['data']) as List? ?? const []).cast<Map>();
          final urls = [for (final p in pages) '${(p['attributes'] as Map)['url']}']..sort();
          return [for (final u in urls) '${s.baseUrl}/backend$u'];
        },
      ),
      FnSource(
        id: 'en.mangade',
        name: 'MangaDE',
        baseUrl: 'https://mangade.io',
        contentWarning: ContentWarning.safe,
        popularFn: (s, page) => _mangadeList(s, page, '', 'most-viewed'),
        latestFn: (s, page) => _mangadeList(s, page, '', 'newest'),
        searchFn: (s, page, q) => _mangadeList(s, page, q, 'newest'),
        detailsFn: (s, url) async {
          final mid = Uri.parse(url).queryParameters['mid']!;
          final d = await _mangadeData(s, '/comics/$mid/view', {}) as Map;
          final slug = '${d['slug']}';
          final chapters = <SourceChapter>[];
          for (final c in ((d['news_chapters'] as List?) ?? const []).cast<Map>()) {
            chapters.add(SourceChapter(
              url: '${s.baseUrl}/$slug/${c['slug']}?cid=${c['id']}&mid=$mid',
              name: clean('${c['name']}'),
              number: double.tryParse('${c['chapter_number']}'),
            ));
          }
          final st = '${d['status']}';
          return SourceMangaDetails(
            url: url,
            title: clean('${d['name']}'),
            thumbnailUrl: d['image'] as String?,
            description: d['description'] as String?,
            genres: [for (final g in '${d['genre_names'] ?? ''}'.split(',')) if (g.trim().isNotEmpty) g.trim()],
            status: st == 'Ongoing' || st == 'Releasing'
                ? SourceMangaStatus.ongoing
                : st == 'Completed'
                    ? SourceMangaStatus.completed
                    : st == 'On Hiatus'
                        ? SourceMangaStatus.hiatus
                        : SourceMangaStatus.unknown,
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final cid = Uri.parse(ch.url).queryParameters['cid']!;
          final d = await _mangadeData(s, '/chapters/$cid/view', {}) as Map;
          return [for (final p in ((d['chapter_images'] as List?) ?? const []).cast<Map>()) '${p['image']}'];
        },
      ),
      FnSource(
        id: 'en.chikari',
        name: 'Chikari',
        baseUrl: 'https://chikari.moe',
        contentWarning: ContentWarning.mixed,
        popularFn: (s, page) => _chikariList(s, page, '', 'popular'),
        latestFn: (s, page) => _chikariList(s, page, '', 'latest'),
        searchFn: (s, page, q) => _chikariList(s, page, q, 'popular'),
        detailsFn: (s, url) async {
          final slug = url.split('/').where((e) => e.isNotEmpty).last;
          final d = await s.fetchJson(Uri.parse('${s.baseUrl}/api/series/$slug')) as Map;
          final authors = ((d['authors'] as List?) ?? const []).cast<Map>();
          String role(bool artist) =>
              authors.where((a) => (a['role'] == 'artist') == artist).map((a) => '${a['name']}').join(', ');
          final chapters = <SourceChapter>[];
          var total = 1 << 30;
          for (var off = 0; off < total; off += 200) {
            final r = await s.fetchJson(Uri.parse('${s.baseUrl}/api/series/$slug/chapters?order=desc&limit=200&offset=$off')) as Map;
            total = r['total'] as int;
            final items = (r['items'] as List).cast<Map>();
            if (items.isEmpty) break;
            for (final c in items) {
              final n = (c['number'] as num?)?.toDouble();
              final token = n == null ? 'oneshot' : '$n'.replaceFirst(RegExp(r'\.0$'), '');
              final title = clean('${c['title'] ?? ''}').replaceFirst(RegExp(r'^(?:chapter|ch\.?)\s*[\d.]+\s*[-:.]?\s*', caseSensitive: false), '');
              final name = '${n == null ? 'Oneshot' : 'Chapter $token'}${title.isEmpty ? '' : ': $title'}';
              final scans = ((c['scans'] as List?) ?? const []).cast<Map>();
              if (scans.isEmpty) {
                chapters.add(SourceChapter(url: '${s.baseUrl}/series/$slug/$token', name: name, number: n));
              } else {
                for (final sc in scans) {
                  chapters.add(SourceChapter(
                    url: '${s.baseUrl}/series/$slug/$token?scan=${sc['slug']}',
                    name: name,
                    number: n,
                    scanlator: '${sc['name']}',
                  ));
                }
              }
            }
          }
          return SourceMangaDetails(
            url: url,
            title: clean('${d['title']}'),
            thumbnailUrl: d['cover_url'] as String?,
            author: role(false).isEmpty ? null : role(false),
            artist: role(true).isEmpty ? null : role(true),
            description: d['description'] as String?,
            genres: [
              if (d['type'] is String) '${d['type']}',
              for (final g in ((d['genres'] as List?) ?? const []).cast<Map>()) '${g['name']}',
            ],
            status: switch (d['status']) {
              'releasing' => SourceMangaStatus.ongoing,
              'completed' => SourceMangaStatus.completed,
              'hiatus' => SourceMangaStatus.hiatus,
              'cancelled' => SourceMangaStatus.cancelled,
              _ => SourceMangaStatus.unknown,
            },
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final u = Uri.parse(ch.url);
          final seg = u.pathSegments;
          final scan = u.queryParameters['scan'];
          final r = await s.fetchJson(
            Uri.parse('${s.baseUrl}/api/series/${seg[1]}/chapters/${seg[2]}${scan == null ? '' : '?scan=$scan'}'),
            headers: {'Referer': ch.url},
          ) as Map;
          return [for (final p in (r['pages'] as List? ?? const [])) '$p'];
        },
      ),
      FnSource(
        id: 'en.kuramanga',
        name: 'KuraManga',
        baseUrl: 'https://kuramanga.com',
        contentWarning: ContentWarning.mixed,
        popularFn: (s, page) => _kuraSearch(s, page, ''),
        latestFn: (s, page) async {
          final res = await s.fetchHtml(Uri.parse(page > 1 ? '${s.baseUrl}/?page=$page' : '${s.baseUrl}/'));
          final seen = <String>{};
          final out = <SourceManga>[];
          for (final row in res.document.querySelectorAll('.update-list .update-row')) {
            final a = row.querySelector('a.update-series-link');
            final href = attrAbs(a, 'href', res.url);
            if (a == null || href == null || !seen.add(href)) continue;
            out.add(SourceManga(url: href, title: clean(a.text), thumbnailUrl: attrAbs(row.querySelector('img'), 'src', res.url)));
          }
          return MangaPage(out, hasNextPage: res.document.querySelector('a[data-lu-next]:not(.is-disabled)') != null);
        },
        searchFn: (s, page, q) => _kuraSearch(s, page, q),
        detailsFn: (s, url) async {
          final res = await s.fetchHtml(Uri.parse(url));
          final d = res.document;
          String? cred(String key) {
            for (final c in d.querySelectorAll('.mp-cred')) {
              final k = clean(c.querySelector('.mp-cred-k')?.text);
              if (k.toLowerCase().contains(key.toLowerCase())) return clean(c.querySelector('.mp-cred-v')?.text);
            }
            return null;
          }
          final both = cred('Story & Art') ?? cred('Author & Artist');
          final statusText = clean(d.querySelector('.mp-status')?.text).toLowerCase();
          final chapters = <SourceChapter>[];
          for (final el in d.querySelectorAll('.chapter-list .chapter-item')) {
            final a = el.querySelector('a');
            final href = attrAbs(a, 'href', res.url);
            if (a == null || href == null) continue;
            final name = clean(a.text);
            chapters.add(SourceChapter(
              url: href,
              name: name,
              number: double.tryParse(RegExp(r'(\d+(?:\.\d+)?)').firstMatch(name)?[1] ?? ''),
            ));
          }
          return SourceMangaDetails(
            url: url,
            title: clean(d.querySelector('h1.manga-title')?.text),
            thumbnailUrl: d.querySelector('meta[property="og:image"]')?.attributes['content'],
            description: clean(d.querySelector('.summary-inner')?.text ?? d.querySelector('.mp-synopsis')?.text),
            author: cred('Author') ?? cred('Story') ?? both,
            artist: cred('Artist') ?? both,
            genres: [for (final g in d.querySelectorAll('.genre-list a.genre-chip')) clean(g.text)],
            status: switch (statusText) {
              'ongoing' || 'upcoming' => SourceMangaStatus.ongoing,
              'completed' => SourceMangaStatus.completed,
              'on_hold' || 'on hold' || 'hiatus' => SourceMangaStatus.hiatus,
              'canceled' || 'cancelled' => SourceMangaStatus.cancelled,
              _ => SourceMangaStatus.unknown,
            },
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse(ch.url));
          return [
            for (final img in res.document.querySelectorAll('#chapterImages img'))
              if ((attrAbs(img, 'data-src', res.url) ?? attrAbs(img, 'src', res.url)) case final u? when u.isNotEmpty) u,
          ];
        },
      ),
      FnSource(
        id: 'en.hentaihere',
        name: 'HentaiHere',
        baseUrl: 'https://hentaihere.com',
        contentWarning: ContentWarning.nsfw,
        popularFn: (s, page) => _hentaiHereList(s, '${s.baseUrl}/browse/most-viewed${page > 1 ? '/page-$page' : ''}'),
        latestFn: (s, page) => _hentaiHereList(s, '${s.baseUrl}/browse/newest/page-$page'),
        searchFn: (s, page, q) => _hentaiHereList(s, '${s.baseUrl}/search?q=${Uri.encodeQueryComponent(q)}&page=$page'),
        detailsFn: (s, url) async {
          final res = await s.fetchHtml(Uri.parse(url));
          final d = res.document;
          String? detail(String label) {
            for (final dt in d.querySelectorAll('dl[aria-label=Details] dt')) {
              if (dt.text.contains(label)) {
                final v = clean(dt.nextElementSibling?.text);
                return v.isEmpty ? null : v;
              }
            }
            return null;
          }
          final chapters = <SourceChapter>[];
          for (final o in d.querySelectorAll('#preview-chapter option')) {
            final href = attrAbs(o, 'data-read', res.url);
            if (href == null) continue;
            final name = clean(o.text).replaceFirst(RegExp(r'\(latest\)$'), '').trim();
            chapters.add(SourceChapter(
              url: href,
              name: name,
              number: double.tryParse(RegExp(r'Chapter\s+([\d.]+)').firstMatch(name)?[1] ?? ''),
            ));
          }
          if (chapters.isEmpty) chapters.add(SourceChapter(url: url, name: 'Oneshot', number: 1));
          final status = detail('Status')?.toLowerCase();
          return SourceMangaDetails(
            url: url,
            title: clean(d.querySelector('h1#book-title')?.text),
            thumbnailUrl: d.querySelector('meta[property="og:image"]')?.attributes['content'],
            author: detail('Artist') ?? detail('Author'),
            genres: [for (final a in d.querySelectorAll('ul[aria-label=Tags] a')) clean(a.text)],
            status: status == 'completed'
                ? SourceMangaStatus.completed
                : status == 'ongoing'
                    ? SourceMangaStatus.ongoing
                    : SourceMangaStatus.unknown,
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse(ch.url));
          final raw = res.document.querySelector('script[data-reader-data]')?.text;
          if (raw == null) return const [];
          final data = jsonDecode(raw) as Map;
          return [for (final u in (data['images'] as List)) '$u'];
        },
      ),
      FnSource(
        id: 'en.hentaitnt',
        name: 'HentaiTnT',
        baseUrl: 'https://hentaitnt.net',
        contentWarning: ContentWarning.nsfw,
        popularFn: (s, page) => _tntList(s, '${s.baseUrl}/recommended${page > 1 ? '/page/$page' : ''}'),
        latestFn: (s, page) => _tntList(s, '${s.baseUrl}/latest-updates${page > 1 ? '/page/$page' : ''}'),
        searchFn: (s, page, q) => _tntList(s, '${s.baseUrl}${page > 1 ? '/page/$page' : ''}/?s=${Uri.encodeQueryComponent(q)}'),
        detailsFn: (s, url) async {
          final res = await s.fetchHtml(Uri.parse(url));
          final d = res.document;
          final id = d.querySelector('#post_manga_id')?.attributes['value'];
          final chapters = <SourceChapter>[];
          if (id != null) {
            final r = await s.postFormJson(Uri.parse('${s.baseUrl}/wp-admin/admin-ajax.php'), {
              'action': 'baka_ajax',
              'type': 'load_chapters_paginated',
              'parent_id': id,
              'per_page': '10000',
              'order': 'newest_first',
            }) as Map;
            final frag = html_parser.parseFragment('${((r['data'] as Map)['html'])}');
            for (final el in frag.querySelectorAll('.comic-card')) {
              final a = el.querySelector('a');
              final href = attrAbs(a, 'href', Uri.parse(s.baseUrl));
              if (a == null || href == null) continue;
              final vip = el.querySelector('.fa-crown') != null;
              final name = clean(a.attributes['title'] ?? a.text);
              chapters.add(SourceChapter(
                url: href,
                name: '${vip ? '🔒 ' : ''}$name',
                number: double.tryParse(RegExp(r'(\d+(?:\.\d+)?)').firstMatch(name)?[1] ?? ''),
              ));
            }
          }
          final status = clean(d.querySelector('i[title=Status]')?.parent?.text).toLowerCase();
          return SourceMangaDetails(
            url: url,
            title: clean(d.querySelector('meta[property="og:title"]')?.attributes['content'] ?? d.querySelector('h1')?.text),
            thumbnailUrl: d.querySelector('meta[property="og:image"]')?.attributes['content'],
            author: clean(d.querySelector('i[title=Artists] + span a')?.text),
            description: clean(d.querySelector('#synopsisText')?.text),
            genres: [for (final g in d.querySelectorAll('.genre-item')) clean(g.text)],
            status: status.contains('completed')
                ? SourceMangaStatus.completed
                : status.contains('ongoing')
                    ? SourceMangaStatus.ongoing
                    : SourceMangaStatus.unknown,
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse(ch.url));
          return imagesFrom(res.document, res.url, '.page-image', ['src', 'data-src']);
        },
      ),
      FnSource(
        id: 'en.atsumaru',
        name: 'Atsumaru',
        baseUrl: 'https://atsu.moe',
        contentWarning: ContentWarning.mixed,
        popularFn: (s, page) => _atsuBrowse(s, 'popular', page, daily: true),
        latestFn: (s, page) => _atsuBrowse(s, 'recentlyUpdated', page),
        searchFn: (s, page, q) async {
          final r = await s.fetchJson(Uri.https(Uri.parse(s.baseUrl).host, '/collections/manga/documents/search', {
            'q': q,
            'query_by': 'title,englishTitle,otherNames,authors,acronyms',
            'query_by_weights': '4,3,2,2,1',
            'num_typos': '4,3,2,1,0',
            'prefix': 'true,true,true,true,false',
            'include_fields': 'id,title,posterMedium',
            'filter_by': r'medium:!=[`Novel`] && isAdult:=false && mbContentRating:!=[`Pornographic`] && hidden:!=true',
            'page': '$page',
            'per_page': '40',
            'infix': 'off,off,fallback,off,off',
          })) as Map;
          final perPage = ((r['request_params'] as Map)['per_page'] as num).toInt();
          return MangaPage(
            [
              for (final h in (r['hits'] as List).cast<Map>())
                _atsuManga(s, h['document'] as Map),
            ],
            hasNextPage: (r['page'] as int) * perPage < (r['found'] as int),
          );
        },
        detailsFn: (s, url) async {
          final id = url.split('/').where((e) => e.isNotEmpty).last;
          final host = Uri.parse(s.baseUrl).host;
          final page = ((await s.fetchJson(Uri.https(host, '/api/manga/page', {'id': id}))) as Map)['mangaPage'] as Map;
          final all = (await s.fetchJson(Uri.https(host, '/api/manga/allChapters', {'mangaId': id}))) as Map;
          final scans = {for (final sc in ((page['scanlators'] as List?) ?? const []).cast<Map>()) '${sc['id']}': '${sc['name']}'};
          final chapters = <SourceChapter>[];
          for (final c in (all['chapters'] as List).cast<Map>()) {
            final n = (c['number'] as num?)?.toDouble();
            final sid = c['scanlationMangaId'];
            chapters.add(SourceChapter(
              url: '${s.baseUrl}/read/$id/${c['id']}',
              name: clean('${c['title']}'),
              number: n,
              scanlator: sid == null ? null : scans['$sid'],
            ));
          }
          chapters.sort((a, b) => (b.number ?? 0).compareTo(a.number ?? 0));
          final authors = ((page['authors'] as List?) ?? const []).cast<Map>();
          String join(bool artist) => authors.where((a) => (a['type'] == 'Artist') == artist).map((a) => '${a['name']}').join(', ');
          final type = page['type'] as String?;
          final st = '${page['status']}'.toLowerCase();
          return SourceMangaDetails(
            url: url,
            title: clean('${page['title']}'),
            thumbnailUrl: _atsuCdn(s, ((page['poster'] as Map?)?['largeImage']) as String?),
            author: join(false).isEmpty ? null : join(false),
            artist: join(true).isEmpty ? null : join(true),
            description: page['synopsis'] as String?,
            genres: {
              if (type != null) type == 'Manwha' ? 'Manhwa' : type,
              for (final g in ((page['genres'] as List?) ?? const []).cast<Map>()) '${g['name']}',
              for (final g in ((page['tags'] as List?) ?? const []).cast<Map>()) '${g['name']}',
            }.toList(),
            status: switch (st) {
              'ongoing' => SourceMangaStatus.ongoing,
              'completed' => SourceMangaStatus.completed,
              'hiatus' => SourceMangaStatus.hiatus,
              'canceled' => SourceMangaStatus.cancelled,
              _ => SourceMangaStatus.unknown,
            },
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final parts = ch.url.split('/read/').last.split('/');
          final r = await s.fetchJson(Uri.https(Uri.parse(s.baseUrl).host, '/api/read/chapter', {'mangaId': parts[0], 'chapterId': parts[1]})) as Map;
          final pages = ((r['readChapter'] as Map)['pages'] as List).cast<Map>();
          return [for (final p in pages) _atsuCdn(s, '${p['image']}')!];
        },
      ),
      SingleSeriesSource(
        id: 'en.megatokyo',
        name: 'Megatokyo',
        baseUrl: 'https://megatokyo.com',
        seriesTitle: 'Megatokyo',
        contentWarning: ContentWarning.safe,
        author: 'Fred Gallagher & Rodney Caston',
        cover: 'https://megatokyo.com/strips/1619.png',
        loadChapters: (s) async {
          final res = await s.fetchHtml(Uri.parse(s.baseUrl));
          var latest = 0;
          for (final m in RegExp(r'/strips?/(\d+)').allMatches(res.document.outerHtml)) {
            final n = int.parse(m[1]!);
            if (n > latest) latest = n;
          }
          if (RegExp(r'/strips/(\d+)\.').firstMatch(res.document.outerHtml)?[1] case final v?) {
            final n = int.parse(v);
            if (n > latest) latest = n;
          }
          return [
            for (var n = latest; n >= 1; n--)
              SourceChapter(url: '${s.baseUrl}/strip/$n', name: 'Strip $n', number: n.toDouble()),
          ];
        },
        loadPages: (s, ch) async {
          final n = ch.url.split('/').last;
          for (final ext in ['png', 'gif']) {
            final u = Uri.parse('${s.baseUrl}/strips/$n.$ext');
            try {
              final r = await s.dio.headUri<void>(u, options: Options(validateStatus: (_) => true));
              if (r.statusCode == 200) return [u.toString()];
            } catch (_) {}
          }
          return ['${s.baseUrl}/strips/$n.gif'];
        },
      ),
      SingleSeriesSource(
        id: 'en.onepunchmanonline',
        name: 'One Punch Man Online',
        baseUrl: 'https://w21.1punchman.com',
        seriesTitle: 'One Punch Man',
        contentWarning: ContentWarning.safe,
        author: 'ONE / Yusuke Murata',
        loadChapters: (s) async {
          final res = await s.fetchHtml(Uri.parse(s.baseUrl));
          final seen = <String>{};
          final out = <SourceChapter>[];
          for (final a in res.document.querySelectorAll('a[href*="/manga/one-punch-man-chapter-"]')) {
            final href = attrAbs(a, 'href', res.url);
            final m = href == null ? null : RegExp(r'chapter-(\d+(?:-\d+)?)/?$').firstMatch(href);
            if (href == null || m == null || !seen.add(href)) continue;
            final num = m[1]!.replaceAll('-', '.');
            out.add(SourceChapter(url: href, name: 'Chapter $num', number: double.tryParse(num)));
          }
          out.sort((a, b) => (b.number ?? 0).compareTo(a.number ?? 0));
          return out;
        },
        loadPages: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse(ch.url));
          return imagesFrom(res.document, res.url, 'img[data-src*="/mangas/"], img[src*="/mangas/"]', ['data-src', 'src']);
        },
      ),
      SingleSeriesSource(
        id: 'en.wanderinginn',
        name: 'The Wandering Inn',
        baseUrl: 'https://webcomic.wanderinginn.com',
        seriesTitle: 'The Wandering Inn',
        contentWarning: ContentWarning.safe,
        author: 'pirateaba, Hirari',
        loadChapters: (s) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/table-of-contents/'));
          final seen = <String>{};
          final out = <SourceChapter>[];
          for (final a in res.document.querySelectorAll('a[href*="/chapter/chapter-"]')) {
            final href = attrAbs(a, 'href', res.url);
            final m = href == null ? null : RegExp(r'chapter-(\d+)/?$').firstMatch(href);
            if (href == null || m == null || !seen.add(href)) continue;
            out.add(SourceChapter(url: '${s.baseUrl}/chapter-${m[1]}-page-1/', name: 'Chapter ${m[1]}', number: double.parse(m[1]!)));
          }
          out.sort((a, b) => (b.number ?? 0).compareTo(a.number ?? 0));
          return out;
        },
        loadPages: (s, ch) async {
          final chap = RegExp(r'(chapter-\d+)-page-').firstMatch(ch.url)![1]!;
          final images = <String>[];
          var url = ch.url;
          for (var i = 0; i < 120; i++) {
            final res = await s.fetchHtml(Uri.parse(url));
            final img = imagesFrom(res.document, res.url, 'img[src*="/wp-content/uploads/"][class*="wp-image"], img[src*="_pg"]', ['src']);
            if (img.isNotEmpty && !images.contains(img.first)) images.add(img.first);
            final next = attrAbs(res.document.querySelector('#next')?.parent, 'href', res.url);
            if (next == null || !next.contains('$chap-page-') || next == url) break;
            url = next;
          }
          return images;
        },
      ),
    ];

/// Daftar OriYami dari sitemap (halaman Pustaka dirender klien); 24 per halaman.
Future<MangaPage> _oriList(HttpSource s, int page, String query) async {
  final xml = await s.fetchText(Uri.parse('${s.baseUrl}/sitemaps/mangas.xml'));
  final q = query.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  final all = <SourceManga>[];
  for (final m in RegExp(r'<loc>(https://[^<]+?/(?:manga|manhua|manhwa|digital-comic)/([^/<]+))</loc>').allMatches(xml)) {
    final slug = m[2]!;
    if (q.isNotEmpty && !slug.replaceAll('-', ' ').contains(q)) continue;
    all.add(SourceManga(
      url: m[1]!,
      title: slug.split('-').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' '),
    ));
  }
  const per = 24;
  final from = (page - 1) * per;
  if (from >= all.length) return const MangaPage([], hasNextPage: false);
  final to = from + per > all.length ? all.length : from + per;
  return MangaPage(all.sublist(from, to), hasNextPage: to < all.length);
}

Future<MangaPage> _luminareList(HttpSource s, int page, String query) async {
  final q = query.isEmpty ? '' : '&search=${Uri.encodeQueryComponent(query)}';
  final json = await s.fetchJson(Uri.parse('${s.baseUrl}/wp-json/yarnovel/v1/series?type=manga&per_page=24&page=$page$q')) as Map;
  final meta = json['meta'] as Map?;
  final totalPages = (meta?['total_pages'] as num?)?.toInt() ?? 1;
  return MangaPage([
    for (final e in (json['data'] as List).cast<Map>())
      SourceManga(url: '${e['url']}', title: clean('${e['title']}'), thumbnailUrl: e['cover_image'] as String?),
  ], hasNextPage: page < totalPages);
}

Future<List<Map>> _leslieLibrary(HttpSource s) async =>
    ((await s.fetchJson(Uri.parse('${s.baseUrl}/manga.json'))) as List).cast<Map>();

MangaPage _lesliePage(HttpSource s, List<Map> all, String q, int page) {
  final lq = q.toLowerCase();
  final hits = [for (final e in all) if (lq.isEmpty || '${e['title']}'.toLowerCase().contains(lq)) e];
  if (page > 1) return const MangaPage([], hasNextPage: false);
  return MangaPage([
    for (final e in hits)
      SourceManga(
        url: '${s.baseUrl}/#${Uri.encodeComponent('${e['id']}')}',
        title: '${e['title']}',
        thumbnailUrl: e['cover'] == null ? null : '${s.baseUrl}/${Uri.encodeFull('${e['cover']}')}',
      ),
  ], hasNextPage: false);
}

/// Halaman bab Leslie&Victims: `chapter_roots` (r2), `chapter_pages` (jumlah/daftar), atau cari lewat HEAD.
Future<List<String>> _lesliePages(HttpSource s, SourceChapter ch) async {
  final parts = ch.url.split('#').last.split('/');
  final id = Uri.decodeComponent(parts.first);
  final chapter = Uri.decodeComponent(parts.sublist(1).join('/'));
  final lib = await _leslieLibrary(s);
  final m = lib.firstWhere((e) => '${e['id']}' == id);
  String two(int n) => n.toString().padLeft(2, '0');
  List<String> fromData(String root, Object? data, Object? mode) {
    if (data is int && (mode == null || mode == 'count')) return [for (var i = 1; i <= data; i++) '$root/${two(i)}.webp'];
    if (data is List) return [for (final n in data) '$root/${Uri.encodeComponent('$n')}'];
    return const [];
  }

  final rootInfo = (m['chapter_roots'] as Map?)?[chapter];
  if (rootInfo is Map) {
    final root = Uri.encodeFull('${rootInfo['url']}');
    final out = fromData(root, rootInfo['data'], rootInfo['mode']);
    if (out.isNotEmpty) return out;
  }
  final pagesInfo = (m['chapter_pages'] as Map?)?[chapter];
  final base = '${s.baseUrl}/content/${Uri.encodeComponent(id)}/${Uri.encodeComponent(chapter)}';
  final listed = fromData(base, pagesInfo, 'count');
  if (listed.isNotEmpty) return listed;
  final out = <String>[];
  for (var i = 1; i <= 120; i++) {
    final u = '$base/${two(i)}.webp';
    final r = await s.dio.headUri<void>(Uri.parse(u), options: Options(validateStatus: (_) => true));
    if (r.statusCode != 200) break;
    out.add(u);
  }
  return out;
}

const _rayubaGists = ['J0Nwh', 'JBu17', 'JED9q', 'Jnaek'];

Future<Map> _gist(HttpSource s, String id) async =>
    (await s.fetchJson(Uri.parse('https://cubari.moe/read/api/gist/series/$id/'))) as Map;

Future<MangaPage> _rayubaList(HttpSource s, int page, String q) async {
  if (page > 1) return const MangaPage([], hasNextPage: false);
  final lq = q.toLowerCase();
  final out = <SourceManga>[];
  for (final id in _rayubaGists) {
    final g = await _gist(s, id);
    final title = clean('${g['title']}');
    if (lq.isEmpty || title.toLowerCase().contains(lq)) {
      out.add(SourceManga(url: 'https://cubari.moe/read/gist/$id/', title: title, thumbnailUrl: g['cover'] as String?));
    }
  }
  return MangaPage(out, hasNextPage: false);
}

class _NuxEntry {
  _NuxEntry(this.url, this.title, this.thumbnailUrl, this.genres, this.status);
  final String url;
  final String title;
  final String? thumbnailUrl;
  final List<String> genres;
  final SourceMangaStatus status;
}

Future<List<_NuxEntry>> _nuxEntries(HttpSource s) async {
  final json = await s.fetchJson(Uri.parse('${s.baseUrl}/feeds/posts/default?alt=json&max-results=150')) as Map;
  final out = <_NuxEntry>[];
  for (final e in ((json['feed'] as Map)['entry'] as List? ?? const []).cast<Map>()) {
    final link = (e['link'] as List).cast<Map>().where((l) => l['rel'] == 'alternate').firstOrNull;
    if (link == null) continue;
    final terms = [for (final c in (e['category'] as List? ?? const []).cast<Map>()) '${c['term']}'];
    final thumb = (e['media\$thumbnail'] as Map?)?['url'] as String?;
    out.add(_NuxEntry(
      '${link['href']}',
      clean('${(e['title'] as Map)['\$t']}'),
      thumb?.replaceFirst(RegExp(r'/s72-c/'), '/s0/'),
      [for (final x in terms) if (!x.startsWith('-')) x],
      terms.contains('-ONGOING')
          ? SourceMangaStatus.ongoing
          : terms.contains('-DROPPED') || terms.contains('-AXED')
              ? SourceMangaStatus.cancelled
              : SourceMangaStatus.unknown,
    ));
  }
  return out;
}

Future<MangaPage> _nuxPage(HttpSource s, int page, String q) async {
  if (page > 1) return const MangaPage([], hasNextPage: false);
  final lq = q.toLowerCase();
  return MangaPage([
    for (final e in await _nuxEntries(s))
      if (lq.isEmpty || e.title.toLowerCase().contains(lq))
        SourceManga(url: e.url, title: e.title, thumbnailUrl: e.thumbnailUrl),
  ], hasNextPage: false);
}

Uri _kappaApi(HttpSource s, String path, Map<String, String> q) =>
    Uri.https('strapi.${Uri.parse(s.baseUrl).host}', '/api/$path', q);

SourceManga _kappaManga(HttpSource s, Map d) {
  final media = (d['media'] as List?)?.cast<Map>();
  final cover = media == null || media.isEmpty ? null : (media.first['coverImage'] as Map?)?['url'] as String?;
  return SourceManga(
    url: '${s.baseUrl}/series/${d['slug']}#${d['documentId']}',
    title: clean('${d['title']}'),
    thumbnailUrl: cover == null ? null : 'https://strapi.${Uri.parse(s.baseUrl).host}$cover',
  );
}

Future<MangaPage> _kappaList(HttpSource s, int page, String query, String sort) async {
  final json = await s.fetchJson(_kappaApi(s, 'mangas', {
    if (query.isNotEmpty) r'filters[title][$containsi]': query,
    'pagination[page]': '$page',
    'pagination[pageSize]': '20',
    'populate[media][populate]': '*',
    'populate[category][fields][0]': 'name',
    if (sort.isNotEmpty) 'sort[0]': sort,
  })) as Map;
  final p = (json['meta'] as Map)['pagination'] as Map;
  return MangaPage(
    [for (final d in (json['data'] as List).cast<Map>()) _kappaManga(s, d)],
    hasNextPage: (p['page'] as int) < (p['pageCount'] as int),
  );
}

String _kappaFull(String href) {
  final u = Uri.parse(href);
  final seg = [...u.pathSegments];
  if (seg.length > 4) seg[4] = 's0';
  return u.replace(pathSegments: seg).toString();
}

Future<Object?> _comiclandData(HttpSource s, String path, Map<String, String> q) async {
  final json = await s.fetchJson(Uri.https('api.comicland.org', '/api$path', q)) as Map;
  return json['data'];
}

Future<MangaPage> _comiclandList(HttpSource s, String path, int page, Map<String, String> q) async {
  final data = await _comiclandData(s, path, {...q, 'offset': '${(page - 1) * 20}', 'limit': '20'}) as Map?;
  final list = ((data?['list'] ?? data?['items']) as List? ?? const []).cast<Map>();
  return MangaPage(
    [
      for (final c in list)
        SourceManga(url: '${s.baseUrl}/comic/${c['slug']}', title: clean('${c['title']}'), thumbnailUrl: c['cover_url'] as String?),
    ],
    hasNextPage: data?['has_more'] as bool? ?? list.length == 20,
  );
}

String _tinyCdn(HttpSource s) => 'https://cdn.${Uri.parse(s.baseUrl).host}';

Future<Map> _tinyComic(HttpSource s, String path) async =>
    ((await s.fetchJson(Uri.parse('${_tinyCdn(s)}$path/index.json'))) as Map)['comics'] as Map;

String _tinyImage(HttpSource s, String path, String image) => Uri.parse('${_tinyCdn(s)}$path/').resolve(image).toString();

Future<MangaPage> _tinyDirectory(HttpSource s, String query) async {
  final dir = await _tinyComic(s, '/tinyview/comic-series-directory');
  final q = query.trim().toLowerCase();
  final out = <SourceManga>[];
  for (final p in (dir['panels'] as List).cast<Map>()) {
    final action = p['action'] as String?;
    if (action == null || p['title'] == null) continue;
    if (q.isNotEmpty && !'${p['title']}'.toLowerCase().contains(q) && !'${p['description'] ?? ''}'.toLowerCase().contains(q)) continue;
    out.add(SourceManga(
      url: '${s.baseUrl}${action.replaceFirst('/index.json', '')}',
      title: clean('${p['title']}'),
      thumbnailUrl: p['image'] == null ? null : Uri.parse('${_tinyCdn(s)}/').resolve('${p['image']}').toString(),
    ));
  }
  return MangaPage(out, hasNextPage: false);
}

List<SourceManga> _manhwazCards(Document doc, Uri base, String sel) {
  final out = <SourceManga>[];
  for (final card in doc.querySelectorAll(sel)) {
    final a = card.querySelector('h3 a');
    final href = attrAbs(a, 'href', base);
    if (a == null || href == null) continue;
    final img = card.querySelector('img');
    out.add(SourceManga(
      url: href,
      title: clean(a.text),
      thumbnailUrl: attrAbs(img, 'src', base) ?? attrAbs(img, 'data-src', base),
    ));
  }
  return out;
}

Uri _hyakuroApi(HttpSource s, Map<String, String> q) => Uri.https(Uri.parse(s.baseUrl).host, '/backend/api/mangas', q);

SourceManga _hyakuroManga(HttpSource s, Map a) {
  final cover = (((a['Cover'] as Map?)?['data'] as Map?)?['attributes'] as Map?)?['url'];
  return SourceManga(
    url: '${s.baseUrl}/manga/${a['slug']}',
    title: clean('${a['Title']}'),
    thumbnailUrl: cover == null ? null : '${s.baseUrl}/backend$cover',
  );
}

Future<MangaPage> _hyakuroList(HttpSource s, int page, String query, String sort) async {
  final json = await s.fetchJson(_hyakuroApi(s, {
    'populate': 'Cover,Chapters',
    'sort': sort,
    'pagination[page]': '$page',
    if (query.isNotEmpty) r'filters[Title][$containsi]': query,
  })) as Map;
  final p = (json['meta'] as Map)['pagination'] as Map;
  return MangaPage(
    [for (final e in (json['data'] as List).cast<Map>()) _hyakuroManga(s, e['attributes'] as Map)],
    hasNextPage: (p['page'] as int) < (p['pageCount'] as int),
  );
}

Future<Map> _hyakuroOne(HttpSource s, String slug, String populate, {String key = 'populate'}) async {
  final json = await s.fetchJson(_hyakuroApi(s, {r'filters[slug][$eq]': slug, key: populate})) as Map;
  return ((json['data'] as List).first as Map)['attributes'] as Map;
}

Future<Object?> _mangadeData(HttpSource s, String path, Map<String, String> q) async {
  final json = await s.fetchJson(Uri.https('api.${Uri.parse(s.baseUrl).host}', '/api$path', q)) as Map;
  return json['data'];
}

Future<MangaPage> _mangadeList(HttpSource s, int page, String query, String sort) async {
  final d = await _mangadeData(s, '/comics', {
    'page': '$page',
    'size': '20',
    'sort': sort,
    if (query.isNotEmpty) 'name': query,
  }) as Map;
  return MangaPage(
    [
      for (final c in (d['list'] as List).cast<Map>())
        SourceManga(
          url: '${s.baseUrl}/${c['slug']}?mid=${c['id']}',
          title: clean('${c['name']}'),
          thumbnailUrl: c['image'] as String?,
        ),
    ],
    hasNextPage: int.parse('${d['page']}') < (d['totalPage'] as int),
  );
}

Future<MangaPage> _chikariList(HttpSource s, int page, String query, String sort) async {
  final r = await s.fetchJson(Uri.parse(
      '${s.baseUrl}/api/series?sort=$sort${query.isEmpty ? '' : '&q=${Uri.encodeQueryComponent(query)}'}&limit=36&offset=${(page - 1) * 36}')) as Map;
  return MangaPage(
    [
      for (final c in (r['items'] as List).cast<Map>())
        SourceManga(url: '${s.baseUrl}/series/${c['slug']}', title: clean('${c['title']}'), thumbnailUrl: c['cover_url'] as String?),
    ],
    hasNextPage: page * 36 < (r['total'] as int),
  );
}

Future<MangaPage> _kuraSearch(HttpSource s, int page, String query) async {
  final r = await s.fetchJson(
    Uri.parse('${s.baseUrl}/search?ajax=1&page=$page${query.isEmpty ? '' : '&name=${Uri.encodeQueryComponent(query)}'}'),
    headers: {'X-Requested-With': 'XMLHttpRequest'},
  ) as Map;
  final data = (r['data'] as List).cast<Map>();
  final total = (r['total'] as num?)?.toInt() ?? 0;
  return MangaPage(
    [
      for (final m in data)
        SourceManga(
          url: '${s.baseUrl}/${m['normalized_title']}',
          title: clean('${m['title']}'),
          thumbnailUrl: (m['thumb'] ?? m['cover_image_url']) as String?,
        ),
    ],
    hasNextPage: data.length == 18 && (total == 0 || page * 18 < total),
  );
}

Future<MangaPage> _hentaiHereList(HttpSource s, String url) async {
  final res = await s.fetchHtml(Uri.parse(url));
  final out = <SourceManga>[];
  final seen = <String>{};
  for (final card in res.document.querySelectorAll('article.card[data-card]')) {
    final href = attrAbs(card.querySelector('a'), 'href', res.url);
    final title = clean(card.querySelector('h3')?.text);
    if (href == null || title.isEmpty || !seen.add(href)) continue;
    out.add(SourceManga(url: href, title: title, thumbnailUrl: attrAbs(card.querySelector('img'), 'src', res.url)));
  }
  return MangaPage(out, hasNextPage: res.document.querySelector('a[rel=next]') != null);
}

Future<MangaPage> _tntList(HttpSource s, String url) async {
  final res = await s.fetchHtml(Uri.parse(url));
  final out = <SourceManga>[];
  final seen = <String>{};
  for (final a in res.document.querySelectorAll('.comic-card a')) {
    final href = attrAbs(a, 'href', res.url);
    final title = clean(a.attributes['title']);
    if (href == null || title.isEmpty || !seen.add(href)) continue;
    out.add(SourceManga(url: href, title: title, thumbnailUrl: attrAbs(a.querySelector('img'), 'src', res.url)));
  }
  return MangaPage(out, hasNextPage: res.document.querySelector('a[title=Next]') != null);
}

String? _atsuCdn(HttpSource s, String? path) {
  if (path == null) return null;
  return Uri.parse('https://cdn.${Uri.parse(s.baseUrl).host}/static/').resolve(path).toString();
}

SourceManga _atsuManga(HttpSource s, Map m) {
  final big = m['largeImage'] as String?;
  final poster = m['posterMedium'] as String?;
  return SourceManga(
    url: '${s.baseUrl}/manga/${m['id']}',
    title: clean('${m['title']}'),
    thumbnailUrl: _atsuCdn(s, big ?? poster?.replaceFirst('-medium.', '-large.')),
  );
}

Future<MangaPage> _atsuBrowse(HttpSource s, String path, int page, {bool daily = false}) async {
  final r = await s.fetchJson(Uri.https(Uri.parse(s.baseUrl).host, '/api/home2/$path', {
    'offset': '${(page - 1) * 40}',
    'limit': '40',
    'types': 'Manga,Manwha,Manhua,OEL',
    'mediums': 'Comic',
    if (daily) 'timeframe': 'daily',
  })) as Map;
  final items = (r['items'] as List).cast<Map>();
  return MangaPage([for (final m in items) _atsuManga(s, m)], hasNextPage: items.length == 40);
}
