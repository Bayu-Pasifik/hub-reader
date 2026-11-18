// Sumber kelompok Aman (seri-bab HTML), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0): src/en/*.

import 'package:dio/dio.dart';
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
