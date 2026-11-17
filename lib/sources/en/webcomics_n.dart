// Situs katalog (bagian N), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0): mangacherri, colorizedmangas,
// complexbowler, broccolisoup, hypercomic.

import 'package:html/dom.dart';

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import 'fn_source.dart';

String? _opt(String s) {
  final t = clean(s);
  return t.isEmpty ? null : t;
}

String _seg1(Uri u) => u.pathSegments.length > 1 ? u.pathSegments[1] : '';

// ----------------------------------------------------------------- MangaCherri

SourceMangaStatus _cherriStatus(String? raw) {
  final t = (raw ?? '').toLowerCase();
  if (t.contains('ongoing')) return SourceMangaStatus.ongoing;
  if (t.contains('completed')) return SourceMangaStatus.completed;
  if (t.contains('hiatus')) return SourceMangaStatus.hiatus;
  return SourceMangaStatus.unknown;
}

Future<MangaPage> _cherriBrowse(HttpSource s, int page, Map<String, String> q) async {
  final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/manga').replace(queryParameters: {
    ...q,
    if (page > 1) 'page': '$page',
  }));
  final items = <SourceManga>[];
  for (final card in res.document.querySelectorAll('article.cherri-list-card')) {
    final a = card.querySelector('h2 a');
    if (a == null) continue;
    items.add(SourceManga(
      url: _seg1(Uri.parse(absUrl(s.baseUri, a.attributes['href'])!)),
      title: clean(a.text),
      thumbnailUrl: attrAbs(card.querySelector('img'), 'src', s.baseUri),
    ));
  }
  final next = res.document.querySelectorAll('nav.pager a').any((a) => clean(a.text).contains('Next'));
  return MangaPage(items, hasNextPage: next);
}

// ---------------------------------------------------------------- Colorized

Future<List<SourceManga>> _colorizedList(HttpSource s) async {
  final res = await s.fetchHtml(Uri.parse(s.baseUrl));
  final seen = <String>{};
  final out = <SourceManga>[];
  for (final a in res.document.querySelectorAll('div.lib-color-view a[href], div.lib-bw-view a[href]')) {
    var href = a.attributes['href']!;
    if (href.endsWith('/')) href = href.substring(0, href.length - 1);
    final slug = href.split('/').last;
    final title = _opt(a.querySelector('h3')?.text ?? '');
    if (slug.isEmpty || title == null || !seen.add(slug)) continue;
    out.add(SourceManga(url: '/$slug', title: title, thumbnailUrl: attrAbs(a.querySelector('img'), 'src', s.baseUri)));
  }
  return out;
}

// ------------------------------------------------------------- Complex Bowler

Future<List<SourceManga>> _bowlerProjects(HttpSource s) async {
  final res = await s.fetchHtml(Uri.parse(s.baseUrl));
  final out = <SourceManga>[];
  for (final section in res.document.querySelectorAll('.project-section')) {
    final links = [for (final a in section.querySelectorAll('a')) if (a.children.any((c) => c.localName == 'img')) a];
    if (links.isEmpty) continue;
    for (final a in links) {
      final cover = a.querySelector('img')!;
      final href = absUrl(s.baseUri, a.attributes['href']);
      final alt = cover.attributes['alt'];
      if (href == null || alt == null || alt.isEmpty) continue;
      out.add(SourceManga(
        url: Uri.parse(href).path.replaceFirst(RegExp(r'\.html$'), ''),
        title: alt,
        thumbnailUrl: attrAbs(cover, 'src', s.baseUri),
      ));
    }
  }
  return out;
}

Future<Map<String, SourceMangaStatus>> _bowlerStatuses(HttpSource s) async {
  final res = await s.fetchHtml(Uri.parse(s.baseUrl));
  final out = <String, SourceMangaStatus>{};
  for (final section in res.document.querySelectorAll('.project-section')) {
    final h = clean(section.querySelector('h2')?.text).toLowerCase();
    final st = h == 'ongoing projects'
        ? SourceMangaStatus.ongoing
        : h == 'completed projects'
            ? SourceMangaStatus.completed
            : SourceMangaStatus.unknown;
    for (final a in section.querySelectorAll('a')) {
      final href = absUrl(s.baseUri, a.attributes['href']);
      if (href != null) out[Uri.parse(href).path.replaceFirst(RegExp(r'\.html$'), '')] = st;
    }
  }
  return out;
}

// ------------------------------------------------------------------ Hypercomic

SourceManga _hyperItem(Element a, Uri base) => SourceManga(
      url: Uri.parse(absUrl(base, a.attributes['href'])!).path,
      title: clean(a.querySelector('.title')?.text),
      thumbnailUrl: attrAbs(a.querySelector('img'), 'src', base),
    );

Future<MangaPage> _hyperBrowse(HttpSource s, int page, int weekday) async {
  final d = await s.fetchJson(
    Uri.parse('${s.baseUrl}/Webtoon').replace(queryParameters: {
      'page': '$page',
      'vtype': 'ajax',
      'weekday': '$weekday',
      'lang': 'en',
    }),
    headers: const {'X-Requested-With': 'XMLHttpRequest'},
  ) as Map;
  final total = int.tryParse('${d['totalpage']}') ?? 1;
  final items = <SourceManga>[];
  for (final m in (d['data'] as List).cast<Map>()) {
    final id = m['CONT_IDX'];
    if (id == null || m['TITLE'] == null) continue;
    items.add(SourceManga(
      url: '/Webtoon/episode/$id/1/',
      title: '${m['TITLE']}'.trim(),
      thumbnailUrl: m['THUMBNAIL'] == null ? null : 'https://d2gfgyilxd7m0r.cloudfront.net/${m['THUMBNAIL']}',
    ));
  }
  return MangaPage(items, hasNextPage: page < total);
}

// ---------------------------------------------------------------- Broccoli Soup

const _broccoliCover = 'https://politeandgood.com/assets/images/static/Bocki%20(correct%20size).png';

List<MangaSource> webcomicsN() => [
      // MangaCherri
      FnSource(
        id: 'en.mangacherri',
        name: 'MangaCherri',
        baseUrl: 'https://mangacherri.com',
        popularFn: (s, page) => _cherriBrowse(s, page, {'sort': 'popular'}),
        latestFn: (s, page) => _cherriBrowse(s, page, {'sort': 'updated'}),
        searchFn: (s, page, q) => _cherriBrowse(s, page, {'q': q, 'sort': 'popular'}),
        detailsFn: (s, slug) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/title/$slug'));
          final doc = res.document;
          final d = doc.querySelector('.cherri-detail');
          String? stat(String label) {
            for (final div in d?.querySelectorAll('.cherri-detail__stats > div') ?? const <Element>[]) {
              final sm = div.querySelector('small');
              if (sm != null && clean(sm.text).contains(label)) return clean(div.querySelector('strong')?.text);
            }
            return null;
          }

          final votes = int.tryParse((stat('VOTES') ?? '').replaceAll(',', '')) ?? 0;
          final rating = votes > 0 ? double.tryParse((stat('RATING') ?? '').replaceFirst('★', '').trim()) : null;
          final title = clean(d?.querySelector('h1')?.text);
          final alt = clean(d?.querySelector('.cherri-detail__alt')?.text)
              .split('; ')
              .where((e) => e.isNotEmpty && e != title)
              .toList();
          final desc = [
            if (rating != null) 'Rating: $rating/5 ($votes votes)',
            clean(d?.querySelector('.cherri-detail__description')?.text),
            if (alt.isNotEmpty) 'Alternative titles: ${alt.join(' · ')}',
          ].where((e) => e.isNotEmpty).toList();
          final chapters = <SourceChapter>[];
          for (final row in doc.querySelectorAll('[data-chapter-list] a[data-chapter-row]')) {
            final name = row.querySelector('strong')?.nodes.whereType<Text>().map((e) => e.text).join().trim() ?? '';
            chapters.add(SourceChapter(
              url: _seg1(Uri.parse(absUrl(s.baseUri, row.attributes['href'])!)),
              name: name,
              number: parseChapterNumber(name),
              uploadedAt: DateTime.tryParse(row.querySelector('time')?.attributes['datetime'] ?? ''),
            ));
          }
          return SourceMangaDetails(
            url: slug,
            title: title,
            thumbnailUrl: attrAbs(d?.querySelector('.cherri-detail__cover img'), 'src', s.baseUri),
            author: _opt(d?.querySelector('.cherri-detail__copy > p > strong')?.text ?? ''),
            genres: [for (final a in d?.querySelectorAll('.cherri-detail__chips a') ?? const <Element>[]) clean(a.text)],
            description: desc.isEmpty ? null : desc.join('\n\n'),
            status: _cherriStatus(d?.querySelector('.cherri-detail__copy > p.eyebrow')?.text),
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/read/${ch.url}'));
          return [
            for (final img in res.document.querySelectorAll('[data-cherri-reader] img[data-page]'))
              absUrl(s.baseUri, img.attributes['src'])!,
          ];
        },
      ),
      // Colorized Mangas
      FnSource(
        id: 'en.colorizedmangas',
        name: 'Colorized Mangas',
        baseUrl: 'https://colorizedmangas.com',
        popularFn: (s, page) async => MangaPage(await _colorizedList(s), hasNextPage: false),
        searchFn: (s, page, q) async => MangaPage([
          for (final m in await _colorizedList(s))
            if (m.title.toLowerCase().contains(q.toLowerCase())) m,
        ], hasNextPage: false),
        detailsFn: (s, url) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}$url'));
          final doc = res.document;
          final aside = doc.querySelector('aside');
          String? author;
          for (final div in aside?.querySelectorAll('dl > div') ?? const <Element>[]) {
            final dt = div.querySelector('dt');
            if (dt != null && dt.text.contains('Author')) author = _opt(div.querySelector('dd')?.text ?? '');
          }
          final genreBlock = aside?.querySelectorAll('p').where((p) => p.classes.any((c) => c.startsWith('text-[11px]'))).firstOrNull;
          final chapters = <SourceChapter>[];
          for (final a in doc.querySelectorAll('div.space-y-4 section div.space-y-2 > a')) {
            final num = _opt(a.querySelector('span.font-bold')?.text ?? '');
            final t = _opt(a.querySelector('div.truncate')?.text ?? '');
            if (num == null && t == null) continue;
            final name = num != null ? (t != null && t.toLowerCase() != num.toLowerCase() ? '$num - $t' : num) : t!;
            chapters.add(SourceChapter(
              url: Uri.parse(absUrl(s.baseUri, a.attributes['href'])!).path,
              name: name,
              number: double.tryParse(RegExp(r'\d+(\.\d+)?').firstMatch(num ?? t ?? '')?.group(0) ?? ''),
            ));
          }
          chapters.sort((a, b) {
            final c = (b.number ?? -1).compareTo(a.number ?? -1);
            return c != 0 ? c : b.name.compareTo(a.name);
          });
          return SourceMangaDetails(
            url: url,
            title: clean(aside?.querySelector('h1')?.text).replaceFirst(RegExp(r'^Colorized'), '').trim(),
            thumbnailUrl: attrAbs(aside?.querySelector('img'), 'src', s.baseUri),
            author: author,
            genres: [
              for (final g in (genreBlock?.text ?? '').split('·'))
                if (g.trim().isNotEmpty) g.trim(),
            ],
            description: _opt(aside?.querySelector('p.border-t')?.text ?? ''),
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}${ch.url}'));
          return [
            for (final img in res.document.querySelectorAll('main img[src*="pages"]'))
              absUrl(s.baseUri, img.attributes['src'])!,
          ];
        },
      ),
      // Complex Bowler
      FnSource(
        id: 'en.complexbowler',
        name: 'Complex Bowler',
        baseUrl: 'https://complexbowler.neocities.org',
        popularFn: (s, page) async => MangaPage(await _bowlerProjects(s), hasNextPage: false),
        searchFn: (s, page, q) async => MangaPage([
          for (final m in await _bowlerProjects(s))
            if (m.title.toLowerCase().contains(q.toLowerCase())) m,
        ], hasNextPage: false),
        detailsFn: (s, url) async {
          final listed = (await _bowlerProjects(s)).where((m) => m.url == url).firstOrNull;
          final status = (await _bowlerStatuses(s))[url] ?? SourceMangaStatus.unknown;
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}$url'));
          final section = res.document.querySelector('.project-section');
          final heading = clean(section?.querySelector('h2')?.text);
          final desc = [
            for (final p in section?.querySelectorAll('p') ?? const <Element>[])
              if (p.parent == section && clean(p.text).isNotEmpty) clean(p.text),
            if (heading.isNotEmpty && heading != listed?.title) 'Alternative title: $heading',
          ];
          final chapters = <SourceChapter>[];
          for (final a in section?.querySelectorAll('.chapter-list li a') ?? const <Element>[]) {
            final href = absUrl(s.baseUri, a.attributes['href']);
            if (href == null) continue;
            final u = Uri.parse(href);
            chapters.add(SourceChapter(
              url: u.host == s.baseUri.host ? u.path.replaceFirst(RegExp(r'\.html$'), '') : href,
              name: clean(a.text),
              number: parseChapterNumber(clean(a.text)),
            ));
          }
          return SourceMangaDetails(
            url: url,
            title: listed?.title ?? heading,
            thumbnailUrl: listed?.thumbnailUrl,
            description: desc.isEmpty ? null : desc.join('\n\n'),
            status: status,
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          if (ch.url.startsWith('http') && Uri.parse(ch.url).host != s.baseUri.host) return const [];
          final path = ch.url.startsWith('http') ? Uri.parse(ch.url).path : ch.url;
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}$path'));
          String? script;
          for (final sc in res.document.querySelectorAll('script')) {
            if (sc.text.contains('input_images')) {
              script = sc.text;
              break;
            }
          }
          final arr = RegExp(r'input_images\s*=\s*\[([^\]]*)]').firstMatch(script ?? '')?.group(1) ?? '';
          return [for (final m in RegExp(r'"(https?://[^"]+)"').allMatches(arr)) m[1]!];
        },
      ),
      // Broccoli Soup
      FnSource(
        id: 'en.broccolisoup',
        name: 'Broccoli Soup',
        baseUrl: 'https://politeandgood.com',
        popularFn: (s, page) async => const MangaPage([
          SourceManga(url: '/comic/archive', title: 'Broccoli Soup', thumbnailUrl: _broccoliCover),
        ], hasNextPage: false),
        searchFn: (s, page, q) async => const MangaPage([], hasNextPage: false),
        detailsFn: (s, url) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}$url'));
          final arcIndex = <String, int>{};
          final chapters = <SourceChapter>[];
          for (final group in res.document.querySelectorAll('li.archive-marker')) {
            final arc = group.querySelector('.archive-header .marker-title')?.text.trim();
            for (final page in group.querySelectorAll('li.archive-page')) {
              final a = page.querySelector('a');
              final t = a?.querySelector('span.page-title');
              if (a == null || t == null) continue;
              final href = a.attributes['href']!;
              final n = int.tryParse(href.split('/').last);
              final idx = arc == null ? null : (arcIndex[arc] = (arcIndex[arc] ?? 0) + 1);
              chapters.add(SourceChapter(
                url: Uri.parse(absUrl(s.baseUri, href)!).path,
                name: [
                  if (n != null) '$n:',
                  t.text.trim(),
                  if (arc != null) '($arc #$idx)',
                ].join(' '),
                number: n?.toDouble(),
              ));
            }
          }
          return SourceMangaDetails(
            url: url,
            title: 'Broccoli Soup',
            thumbnailUrl: _broccoliCover,
            author: 'Secret Pie',
            artist: 'Secret Pie',
            description: 'Hello there! How is the Weather? This comic is made by me, Secret Pie. '
                'I am a pie with legs who draws comics and makes music. I am also an entomologist.',
            chapters: chapters.reversed.toList(),
          );
        },
        pagesFn: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}${ch.url}'));
          return [
            for (final img in res.document.querySelectorAll('#comic img')) absUrl(s.baseUri, img.attributes['src'])!,
          ];
        },
      ),
      // HYPERCOMIC
      FnSource(
        id: 'en.hypercomic',
        name: 'HYPERCOMIC',
        baseUrl: 'https://play.hypercomic.io',
        popularFn: (s, page) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/Webtoon/searchlist'));
          return MangaPage([for (final a in res.document.querySelectorAll('ul.search_list > li > a')) _hyperItem(a, s.baseUri)],
              hasNextPage: false);
        },
        latestFn: (s, page) => _hyperBrowse(s, page, 7),
        searchFn: (s, page, q) async {
          final res = await s.postHtml(Uri.parse('${s.baseUrl}/Webtoon/searchlist'), {'searchval': q});
          return MangaPage([for (final a in res.document.querySelectorAll('#searchcont > li > a')) _hyperItem(a, s.baseUri)],
              hasNextPage: false);
        },
        detailsFn: (s, url) async {
          final id = url.split('/')[3];
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/Webtoon/episode/$id/1/'));
          final doc = res.document;
          var script = '';
          for (final sc in doc.querySelectorAll('script')) {
            if (sc.text.contains('function goPage')) {
              script = sc.text;
              break;
            }
          }
          final pageCount = int.tryParse(RegExp(r'totalPage\s*=\s*(\d+)').firstMatch(script)?.group(1) ?? '') ?? 1;
          final docs = [doc];
          for (var p = 2; p <= pageCount; p++) {
            docs.add((await s.fetchHtml(
              Uri.parse('${s.baseUrl}/Webtoon/episode/$id/$p/2/asc?vtype=ajax'),
              headers: const {'X-Requested-With': 'XMLHttpRequest'},
            ))
                .document);
          }
          final chapters = <SourceChapter>[];
          for (final d in docs) {
            for (final a in d.querySelectorAll('.webtoon_list_type_06 a')) {
              final onclick = a.attributes['onclick'] ?? '';
              final ep = RegExp(r"(?:viewPage|webtoonpay)\('(\d+)'").firstMatch(onclick)?.group(1);
              if (ep == null) continue;
              final locked = onclick.contains('webtoonpay');
              final title = clean(a.querySelector('.title')?.text);
              chapters.add(SourceChapter(
                url: '/Webtoon/episodeview/$id/$ep/1/1/asc',
                name: locked ? '🔒 $title' : title,
                number: parseChapterNumber(title),
              ));
            }
          }
          final info = doc.querySelector('.info_text');
          final blocks = <String>[];
          for (final c in info?.children ?? const <Element>[]) {
            if (clean(c.text) == 'Details') break;
            if (c.localName == 'p') blocks.add(clean(c.text));
          }
          String? publisher;
          for (final p in info?.querySelectorAll('p') ?? const <Element>[]) {
            if (clean(p.querySelector('strong')?.text) == 'Publisher') {
              publisher = clean(p.nodes.whereType<Text>().map((e) => e.text).join());
            }
          }
          return SourceMangaDetails(
            url: url,
            title: clean(doc.querySelector('.contents_wrap .text-xl')?.text),
            thumbnailUrl: attrAbs(doc.querySelector('.contents_wrap img'), 'src', s.baseUri),
            author: _opt(doc.querySelector('.contents_wrap p.font-light')?.text ?? ''),
            genres: [for (final a in doc.querySelectorAll('.contents_wrap a[href="#"]')) clean(a.text)],
            description: [
              if (blocks.isNotEmpty) blocks.join('\n\n'),
              if (publisher != null && publisher.isNotEmpty) 'Publisher: $publisher',
            ].join('\n\n'),
            chapters: chapters.reversed.toList(),
          );
        },
        pagesFn: (s, ch) async {
          if (ch.name.startsWith('🔒')) return const [];
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}${ch.url}'));
          return [
            for (final img in res.document.querySelectorAll('.webtoon_view img')) absUrl(s.baseUri, img.attributes['src'])!,
          ];
        },
      ),
    ];
