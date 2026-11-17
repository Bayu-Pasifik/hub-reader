// Situs katalog (bagian K), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0): arvenscansnet, snafucomic,
// manhuaplustop.

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import 'fn_source.dart';

// ---------------------------------------------------------------- Arven Scans

const _arvenApi = 'https://api.arvenscans.net';

SourceManga _arvenManga(Map w) => SourceManga(
      url: '${w['id']}',
      title: '${w['title']}',
      thumbnailUrl: w['cover_url'] == null ? null : '$_arvenApi${w['cover_url']}',
    );

Future<MangaPage> _arvenList(HttpSource s, Uri uri) async {
  final d = await s.fetchJson(uri) as Map;
  final meta = d['meta'] as Map?;
  final cur = (meta?['current_page'] as num?)?.toInt() ?? 1;
  final total = (meta?['total_pages'] as num?)?.toInt() ?? 1;
  return MangaPage([for (final w in (d['data'] as List).cast<Map>()) _arvenManga(w)], hasNextPage: cur < total);
}

Uri _arvenWorks(int page, {String? search, String sort = 'latest'}) => Uri.parse('$_arvenApi/works').replace(queryParameters: {
      'sort': sort,
      if (search != null) 'search': search,
      'page': '$page',
      'limit': '24',
    });

// ---------------------------------------------------------------------- Snafu

Future<List<(SourceManga, String)>> _snafuCatalog(HttpSource s) async {
  final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/all-comics'));
  final seen = <String>{};
  final out = <(SourceManga, String)>[];
  final series = RegExp(r'^/[^/]+$');
  for (final a in res.document.querySelectorAll('a[href]')) {
    final path = Uri.tryParse(a.attributes['href']!.trim())?.path ?? '';
    if (!series.hasMatch(path)) continue;
    final img = a.querySelector('img');
    final tTitle = clean(a.querySelector('.home-tile-title')?.text);
    final tAuthor = clean(a.querySelector('.home-tile-author')?.text);
    if (img == null || tAuthor.isEmpty) continue;
    final slug = path.substring(1);
    if (!seen.add(slug)) continue;
    final alt = clean(img.attributes['alt']);
    out.add((
      SourceManga(
        url: slug,
        title: alt.isEmpty ? tTitle : alt,
        thumbnailUrl: attrAbs(img, 'src', s.baseUri),
      ),
      tAuthor.replaceFirst(RegExp(r'^bys+', caseSensitive: false), ''),
    ));
  }
  return out;
}

// --------------------------------------------------------------- ManhuaPlus.top

DateTime? _relative(String text) {
  final m = RegExp(r'(\d+)\s*([smhdwMy]) ago').firstMatch(text.trim());
  if (m == null) return null;
  final n = int.parse(m[1]!);
  final now = DateTime.now();
  switch (m[2]) {
    case 's':
      return now.subtract(Duration(seconds: n));
    case 'm':
      return now.subtract(Duration(minutes: n));
    case 'h':
      return now.subtract(Duration(hours: n));
    case 'd':
      return now.subtract(Duration(days: n));
    case 'w':
      return now.subtract(Duration(days: 7 * n));
    case 'M':
      return DateTime(now.year, now.month - n, now.day);
    case 'y':
      return DateTime(now.year - n, now.month, now.day);
  }
  return null;
}

String? _mpImg(Element? e, Uri base) {
  if (e == null) return null;
  for (final k in const ['data-original', 'src']) {
    final v = e.attributes[k];
    if (v != null && v.isNotEmpty) return absUrl(base, v);
  }
  return null;
}

Future<MangaPage> _mpList(HttpSource s, Uri uri) async {
  final res = await s.fetchHtml(uri);
  final items = <SourceManga>[];
  for (final el in res.document.querySelectorAll('div.items div.item')) {
    final a = el.querySelector('h3 a');
    if (a == null) continue;
    items.add(SourceManga(
      url: Uri.parse(absUrl(s.baseUri, a.attributes['href'])!).path,
      title: clean(a.text),
      thumbnailUrl: _mpImg(el.querySelector('div.image img'), s.baseUri),
    ));
  }
  return MangaPage(items, hasNextPage: res.document.querySelector('ul.pagination li.active + li') != null);
}

List<MangaSource> webcomicsK() => [
      // Arven Scans
      FnSource(
        id: 'en.arvenscansnet',
        name: 'Arven Scans',
        baseUrl: 'https://arvenscans.net',
        popularFn: (s, page) async {
          final d = await s.fetchJson(Uri.parse('$_arvenApi/works/most-read?limit=20')) as Map;
          return MangaPage([for (final w in (d['data'] as List).cast<Map>()) _arvenManga(w)], hasNextPage: false);
        },
        latestFn: (s, page) => _arvenList(s, _arvenWorks(page)),
        searchFn: (s, page, q) => _arvenList(s, _arvenWorks(page, search: q)),
        detailsFn: (s, url) async {
          final w = await s.fetchJson(Uri.parse('$_arvenApi/works/$url')) as Map;
          final g = await s.fetchJson(Uri.parse('$_arvenApi/works/$url/genres')) as Map;
          Uri chUri(int p) => Uri.parse('$_arvenApi/works/$url/chapters')
              .replace(queryParameters: {'page': '$p', 'limit': '100', 'order': 'desc'});
          final first = await s.fetchJson(chUri(1)) as Map;
          final all = <Map>[...(first['data'] as List).cast<Map>()];
          final totalPages = ((first['meta'] as Map?)?['total_pages'] as num?)?.toInt() ?? 1;
          for (var p = 2; p <= totalPages; p++) {
            all.addAll(((await s.fetchJson(chUri(p)) as Map)['data'] as List).cast<Map>());
          }
          final genres = <String>[
            for (final x in (g['data'] as List).cast<Map>()) '${x['name_en']}',
            for (final t in (w['tags'] as List? ?? const [])) '$t',
          ];
          final seen = <String>{};
          final alt = [for (final a in (w['alt_titles'] as List? ?? const [])) '$a'].where((e) => e.trim().isNotEmpty).toList();
          final desc = [
            if ((w['description'] as String?)?.isNotEmpty ?? false) w['description'] as String,
            if (alt.isNotEmpty) 'Alternative titles: ${alt.join(' · ')}',
          ];
          return SourceMangaDetails(
            url: url,
            title: '${w['title']}',
            thumbnailUrl: w['cover_url'] == null ? null : '$_arvenApi${w['cover_url']}',
            author: (w['author'] as String?)?.trim().isEmpty ?? true ? null : w['author'] as String,
            description: desc.isEmpty ? null : desc.join('\n\n'),
            genres: genres.where((e) => seen.add(e.toLowerCase())).toList(),
            status: parseStatus('${w['status']}'),
            chapters: [
              for (final c in all)
                if (((c['coins'] as num?) ?? 0) == 0)
                  SourceChapter(
                    url: '${c['id']}',
                    name: () {
                      final n = (c['chapter_number'] as num).toDouble();
                      final ns = n == n.truncateToDouble() ? n.toInt().toString() : n.toString();
                      final t = clean('${c['title'] ?? ''}');
                      return 'Chapter $ns${t.isEmpty ? '' : ' — $t'}';
                    }(),
                    number: (c['chapter_number'] as num).toDouble(),
                    uploadedAt: DateTime.tryParse('${c['created_at']}'),
                  ),
            ],
          );
        },
        pagesFn: (s, ch) async {
          final d = await s.fetchJson(Uri.parse('$_arvenApi/chapters/${ch.url}')) as Map;
          return [for (final p in (d['images'] as List)) '$_arvenApi$p'];
        },
      ),
      // Snafu Comics
      FnSource(
        id: 'en.snafucomics',
        name: 'Snafu Comics',
        baseUrl: 'https://www.snafu-comics.com',
        popularFn: (s, page) async =>
            MangaPage(page > 1 ? const [] : [for (final e in await _snafuCatalog(s)) e.$1], hasNextPage: false),
        searchFn: (s, page, q) async {
          final n = q.toLowerCase();
          return MangaPage([
            for (final (m, a) in await _snafuCatalog(s))
              if (m.title.toLowerCase().contains(n) || a.toLowerCase().contains(n)) m,
          ], hasNextPage: false);
        },
        detailsFn: (s, slug) async {
          final entry = (await _snafuCatalog(s)).where((e) => e.$1.url == slug).firstOrNull;
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/$slug/archive'));
          final doc = res.document;
          Iterable<Element> links = doc.querySelectorAll('a[href]');
          final heading = doc
              .querySelectorAll('h1, h2, h3, h4')
              .where((e) => clean(e.text).toLowerCase() == 'archive')
              .firstOrNull;
          if (heading != null) {
            final acc = <Element>[];
            var sib = heading.nextElementSibling;
            while (sib != null && !const ['h1', 'h2', 'h3', 'h4'].contains(sib.localName)) {
              acc.addAll(sib.querySelectorAll('a[href]'));
              sib = sib.nextElementSibling;
            }
            links = acc;
          }
          String? toPath(String href) {
            final t = href.trim();
            if (t.startsWith('/')) return t;
            if (t.startsWith(s.baseUrl)) return t.substring(s.baseUrl.length).isEmpty ? '/' : t.substring(s.baseUrl.length);
            return null;
          }

          final chapters = <SourceChapter>[];
          final seen = <String>{};
          for (final a in links) {
            final path = toPath(a.attributes['href']!);
            if (path == null || !RegExp('^/${RegExp.escape(slug)}/.+').hasMatch(path) || !seen.add(path)) continue;
            final name = clean(a.text).isEmpty ? path.split('/').last : clean(a.text);
            chapters.add(SourceChapter(
              url: path,
              name: name,
              number: double.tryParse(RegExp(r'\d+(\.\d+)?').firstMatch(name)?.group(0) ?? ''),
            ));
          }
          if (chapters.isEmpty) {
            for (final o in doc.querySelectorAll('select option[value]')) {
              final v = (o.attributes['value'] ?? '').trim();
              if (v.isEmpty) continue;
              final path = toPath(v) ?? '/$slug/$v';
              if (seen.add(path)) chapters.add(SourceChapter(url: path, name: clean(o.text).isEmpty ? v : clean(o.text)));
            }
          }
          return SourceMangaDetails(
            url: slug,
            title: entry?.$1.title ?? slug,
            thumbnailUrl: entry?.$1.thumbnailUrl,
            author: entry?.$2,
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}${ch.url}'));
          return [
            for (final img in res.document.querySelectorAll('img[src*="/comics/"]'))
              absUrl(s.baseUri, img.attributes['src'])!,
          ];
        },
      ),
      // ManhuaPlus.top
      FnSource(
        id: 'en.manhuaplustop',
        name: 'ManhuaPlus.top',
        baseUrl: 'https://manhuaplus.top',
        popularFn: (s, page) =>
            _mpList(s, Uri.parse('${s.baseUrl}/all-manga/$page/').replace(queryParameters: {'sort': 'views'})),
        latestFn: (s, page) =>
            _mpList(s, Uri.parse('${s.baseUrl}/all-manga/$page/').replace(queryParameters: {'sort': 'latest-updated'})),
        searchFn: (s, page, q) =>
            _mpList(s, Uri.parse('${s.baseUrl}/search/$page/').replace(queryParameters: {'keyword': q})),
        detailsFn: (s, url) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}$url'));
          final doc = res.document;
          final info = doc.querySelector('article#item-detail');
          String? list(String sel) {
            final t = info?.querySelectorAll(sel).map((e) => clean(e.text)).where((e) => e.isNotEmpty).join(', ');
            return t == null || t.isEmpty ? null : t;
          }

          final title = clean(info?.querySelector('h1.title-detail')?.text);
          final alt = clean(info?.querySelector('h2.other-name')?.text)
              .split(RegExp(r'\s*;\s*|\s+/\s+'))
              .where((e) => e.isNotEmpty && e != title)
              .toList();
          final desc = [
            clean(info?.querySelector('div.detail-content p')?.text),
            if (alt.isNotEmpty) 'Alternative titles: ${alt.join(' · ')}',
          ].where((e) => e.isNotEmpty).join('\n\n');
          final st = clean(info?.querySelector('li.status p.col-xs-8')?.text).toLowerCase();
          return SourceMangaDetails(
            url: url,
            title: title,
            thumbnailUrl: _mpImg(info?.querySelector('div.col-image img'), s.baseUri),
            author: list('li.author p.col-xs-8 a'),
            genres: list('li.kind p.col-xs-8 a')?.split(', ') ?? const [],
            description: desc.isEmpty ? null : desc,
            status: parseStatus(st == 'on-hold' ? 'hiatus' : st == 'canceled' ? 'cancelled' : st),
            chapters: [
              for (final li in doc.querySelectorAll('div.list-chapter li.row:not(.heading)'))
                if (li.querySelector('a') != null)
                  SourceChapter(
                    url: Uri.parse(absUrl(s.baseUri, li.querySelector('a')!.attributes['href'])!).path,
                    name: clean(li.querySelector('a')!.text),
                    number: parseChapterNumber(clean(li.querySelector('a')!.text)),
                    uploadedAt: _relative(li.querySelector('div.col-xs-4')?.text ?? ''),
                  ),
            ],
          );
        },
        pagesFn: (s, ch) async {
          final chapterUrl = '${s.baseUrl}${ch.url}';
          final page = await s.fetchHtml(Uri.parse(chapterUrl));
          String? id;
          for (final sc in page.document.querySelectorAll('script')) {
            id = RegExp(r'CHAPTER_ID\s*=\s*(\d+)').firstMatch(sc.text)?.group(1);
            if (id != null) break;
          }
          if (id == null) return const [];
          final d = await s.postFormJson(Uri.parse('${s.baseUrl}/ajax/image/list/chap/$id'), const {}) as Map;
          final frag = html_parser.parseFragment('${d['html']}');
          return [
            for (final img in frag.querySelectorAll('div.page-chapter > img'))
              if (_mpImg(img, Uri.parse(chapterUrl)) != null) _mpImg(img, Uri.parse(chapterUrl))!,
          ];
        },
      ),
    ];
