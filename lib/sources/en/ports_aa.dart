// Situs katalog (bagian AA), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0).

import 'package:html/dom.dart';

import 'dart:convert';
import 'ports_util.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import 'fn_source.dart';

Uri _u(String s) => Uri.parse(s);

// ------------------------------------------------------------ MyAdultComics

MangaPage _macList(HtmlResponse res) {
  final out = <SourceManga>[];
  for (final td in res.document.querySelectorAll('td.list_container')) {
    final link = td.querySelector('p.text_container > a');
    final href = absUrl(res.url, link?.attributes['href']);
    final title = clean(link?.text ?? '');
    if (href == null || title.isEmpty) continue;
    out.add(SourceManga(url: href, title: title, thumbnailUrl: attrAbs(td.querySelector('img.fon_pic_img'), 'src', res.url)));
  }
  final next = res.document.querySelectorAll('td.tbl_page a').any((a) => a.text.contains('>>'));
  return MangaPage(out, hasNextPage: next);
}

List<String> _macPaths(Document d) {
  for (final sc in d.querySelectorAll('script')) {
    if (!sc.text.contains('let template')) continue;
    return [for (final m in RegExp(r'''src=["'](books/[^"']+)["']''').allMatches(sc.text)) '/${m[1]}'];
  }
  return const [];
}

FnSource _myadultcomics() => FnSource(
      id: 'en.myadultcomics',
      name: 'MyAdultComics',
      baseUrl: 'https://myadultcomics.com',
      contentWarning: ContentWarning.nsfw,
      popularFn: (s, page) async => _macList(await s.fetchHtml(_u('${s.baseUrl}/index.php?page=$page'))),
      searchFn: (s, page, q) async => _macList(await s.fetchHtml(_u('${s.baseUrl}/index.php').replace(queryParameters: {'name': q, 'search': 'yes', 'page': '$page'}))),
      detailsFn: (s, url) async {
        final res = await s.fetchHtml(_u(url));
        final d = res.document;
        final paths = _macPaths(d);
        String? thumb;
        if (paths.isNotEmpty) {
          final seg = _u('${s.baseUrl}${paths.first}').pathSegments;
          thumb = '${s.baseUrl}/poster/${seg[seg.length - 2]}.${seg.last.split('.').last}';
        }
        List<String> labelled(String label) => [
              for (final p in d.querySelectorAll('p.text_info_book'))
                if (p.text.contains(label)) for (final a in p.querySelectorAll('a')) clean(a.text),
            ];
        final artists = labelled('Artists:');
        return SourceMangaDetails(
          url: url,
          title: clean(d.querySelector('h1#TOP')?.text ?? ''),
          thumbnailUrl: thumb,
          author: artists.join(', '),
          artist: artists.join(', '),
          genres: labelled('Tags:'),
          status: SourceMangaStatus.completed,
          chapters: [SourceChapter(url: res.url.toString(), name: 'Gallery', number: 1)],
        );
      },
      pagesFn: (s, ch) async {
        final res = await s.fetchHtml(_u(ch.url));
        return [for (final p in _macPaths(res.document)) '${s.baseUrl}$p'];
      },
    );

// ------------------------------------------------------------ Schale Scans

const _schaleApi = 'https://xqjjktixlttbqbsdpaxe.supabase.co/rest/v1';
const _schaleHeaders = {'apikey': 'sb_publishable__ow-g4H00jio3RK5qQaJuA_87iakWRc', 'Accept': 'application/json'};
const _schaleSelect = 'id,title,slug,cover_url,is_r18,created_at,chapters(published_at,created_at)';

Future<List<Map>> _schaleGet(FnSource s, String path, Map<String, String> q) async {
  final j = await s.fetchJson(_u('$_schaleApi/$path').replace(queryParameters: q), headers: _schaleHeaders);
  return (j as List).cast<Map>();
}

DateTime? _schaleLatest(Map m) {
  final cs = (m['chapters'] as List? ?? const []).cast<Map>();
  final raw = cs.isEmpty ? null : (cs.first['published_at'] ?? cs.first['created_at']);
  return DateTime.tryParse('${raw ?? m['created_at']}');
}

Future<MangaPage> _schaleList(FnSource s, int page, String? query) async {
  if (page > 1) return const MangaPage([], hasNextPage: false);
  final rows = await _schaleGet(s, 'series', {
    'select': _schaleSelect,
    'chapters.pages_ready': 'eq.true',
    'chapters.order': 'published_at.desc.nullslast',
    'chapters.limit': '1',
    if (query != null) 'title': 'ilike.*$query*',
  });
  final list = rows.where((m) => (m['chapters'] as List).isNotEmpty).toList()
    ..sort((a, b) => (_schaleLatest(b) ?? DateTime(0)).compareTo(_schaleLatest(a) ?? DateTime(0)));
  return MangaPage([
    for (final m in list)
      SourceManga(url: '${s.baseUrl}/manga/${m['slug']}#${m['id']}', title: '${m['title']}', thumbnailUrl: m['cover_url'] as String?),
  ], hasNextPage: false);
}

String _schaleNum(num n) => n == n.roundToDouble() ? '${n.toInt()}' : '$n';

FnSource _schalescans() => FnSource(
      id: 'en.schalescans',
      name: 'Schale Scans',
      baseUrl: 'https://www.schalescans.com',
      contentWarning: ContentWarning.mixed,
      popularFn: (s, page) => _schaleList(s, page, null),
      searchFn: (s, page, q) => _schaleList(s, page, q.trim()),
      detailsFn: (s, url) async {
        final id = _u(url).fragment;
        final rows = await _schaleGet(s, 'series', {
          'select': 'id,title,slug,cover_url,description,status,is_r18,alt_titles,authors,series_genres(genres(name)),'
              'chapters(id,chapter_number,volume_number,title,published_at,created_at)',
          'id': 'eq.$id',
          'chapters.pages_ready': 'eq.true',
          'chapters.order': 'chapter_number.desc',
        });
        final m = rows.first;
        final slug = '${m['slug']}';
        final r18 = m['is_r18'] == true;
        final authors = (m['authors'] as List? ?? const []).cast<Map>();
        String names(String role) => authors.where((a) => a['role'] == role).map((a) => '${a['name']}').join(', ');
        final alts = (m['alt_titles'] as List? ?? const []).map((e) => '- $e').toList();
        final chapters = <SourceChapter>[];
        for (final c in (m['chapters'] as List).cast<Map>()) {
          final n = (c['chapter_number'] as num);
          final vol = c['volume_number'] as num?;
          final title = c['title'];
          chapters.add(SourceChapter(
            url: '${s.baseUrl}/read/$slug/${_schaleNum(n)}#${c['id']}${r18 ? '!r18' : ''}',
            name: '${vol == null ? '' : 'Vol. ${_schaleNum(vol)} '}Ch. ${_schaleNum(n)}${title == null ? '' : ': $title'}',
            number: n.toDouble(),
            uploadedAt: DateTime.tryParse('${c['published_at'] ?? c['created_at']}'),
          ));
        }
        final desc = '${m['description'] ?? ''}'.trim();
        return SourceMangaDetails(
          url: url,
          title: '${m['title']}',
          thumbnailUrl: m['cover_url'] as String?,
          author: names('author'),
          artist: names('artist'),
          genres: [
            for (final g in (m['series_genres'] as List? ?? const []).cast<Map>())
              '${(g['genres'] as Map)['name']}'.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' '),
          ],
          description: [if (desc.isNotEmpty) desc, if (alts.isNotEmpty) 'Alternative titles:\n${alts.join('\n')}'].join('\n\n'),
          status: switch ('${m['status']}'.toLowerCase()) {
            'ongoing' => SourceMangaStatus.ongoing,
            'completed' || 'oneshot' => SourceMangaStatus.completed,
            'hiatus' => SourceMangaStatus.hiatus,
            'dropped' => SourceMangaStatus.cancelled,
            _ => SourceMangaStatus.unknown,
          },
          chapters: chapters,
        );
      },
      pagesFn: (s, ch) async {
        final frag = _u(ch.url).fragment;
        final id = frag.split('!').first;
        final rows = await _schaleGet(s, 'chapters', {
          'select': 'series(is_r18),chapter_pages(object_key)',
          'id': 'eq.$id',
          'chapter_pages.order': 'page_number.asc',
        });
        final d = rows.first;
        final host = (d['series'] as Map)['is_r18'] == true ? 'https://img-r18.schalescans.com' : 'https://img.schalescans.com';
        return [for (final p in (d['chapter_pages'] as List).cast<Map>()) '$host/${p['object_key']}'];
      },
    );

// ------------------------------------------------------------------ helper

/// Nilai JSON (objek/larik) pertama setelah `"key":` di [body] yang lolos [accept].
Object? _jsonAfter(String body, String key, [bool Function(Object value)? accept]) {
  final needle = '"$key":';
  var from = 0;
  while (true) {
    final at = body.indexOf(needle, from);
    if (at < 0) return null;
    from = at + needle.length;
    if (from >= body.length || (body[from] != '{' && body[from] != '[')) continue;
    var depth = 0;
    var inString = false;
    var end = -1;
    for (var i = from; i < body.length; i++) {
      final c = body.codeUnitAt(i);
      if (inString) {
        if (c == 0x5c) {
          i++;
        } else if (c == 0x22) {
          inString = false;
        }
      } else if (c == 0x22) {
        inString = true;
      } else if (c == 0x5b || c == 0x7b) {
        depth++;
      } else if (c == 0x5d || c == 0x7d) {
        depth--;
        if (depth == 0) {
          end = i;
          break;
        }
      }
    }
    if (end < 0) continue;
    try {
      final v = jsonDecode(body.substring(from, end + 1));
      if (v != null && (accept == null || accept(v))) return v;
    } on FormatException {
      continue;
    }
  }
}

// -------------------------------------------------------------- Myth Toons

const _mythBase = 'https://mythtoons.org';

String? _mythAbs(Object? p) => p == null ? null : _u(_mythBase).resolve('$p').toString();

Future<List<Map>> _mythCatalogue(FnSource s) async {
  final j = await s.fetchJson(_u('$_mythBase/api/manga-list'), headers: const {'Accept': 'application/json'}) as List;
  return j.cast<Map>().where((m) => m['contentKind'] != 'novel').toList();
}

SourceManga _mythEntry(Map m) => SourceManga(url: '$_mythBase/manga/${m['id']}', title: '${m['title']}'.trim(), thumbnailUrl: _mythAbs(m['cover']));

FnSource _mythtoons() => FnSource(
      id: 'en.mythtoons',
      name: 'Myth Toons',
      baseUrl: _mythBase,
      contentWarning: ContentWarning.nsfw,
      popularFn: (s, page) async {
        if (page > 1) return const MangaPage([], hasNextPage: false);
        final views = await s.fetchJson(_u('$_mythBase/api/manga-views?limit=1000&orderBy=view_count'), headers: const {'Accept': 'application/json'}) as List;
        final counts = {for (final v in views.cast<Map>()) '${v['id']}': (v['viewCount'] as num).toInt()};
        final list = await _mythCatalogue(s)
          ..sort((a, b) => (counts['${b['id']}'] ?? 0).compareTo(counts['${a['id']}'] ?? 0));
        return MangaPage([for (final m in list) _mythEntry(m)], hasNextPage: false);
      },
      latestFn: (s, page) async {
        final j = await s.fetchJson(_u('$_mythBase/api/manga-list?limit=51&offset=${(page - 1) * 50}'), headers: const {'Accept': 'application/json'}) as List;
        final list = j.cast<Map>();
        return MangaPage([for (final m in list.take(50)) if (m['contentKind'] != 'novel') _mythEntry(m)], hasNextPage: list.length > 50);
      },
      searchFn: (s, page, q) async {
        if (page > 1) return const MangaPage([], hasNextPage: false);
        final needle = q.toLowerCase();
        return MangaPage([for (final m in await _mythCatalogue(s)) if ('${m['title']}'.toLowerCase().contains(needle)) _mythEntry(m)], hasNextPage: false);
      },
      detailsFn: (s, url) async {
        final html = (await s.fetchHtml(_u(url))).body;
        final d = _jsonAfter(nextFlightBody(html), 'dataDetails', (v) => v is Map && v.containsKey('chapters')) as Map?;
        if (d == null) throw StateError('details not found');
        String? real(Object? v) => (v == null || '$v'.trim().isEmpty || v == 'N/A') ? null : '$v';
        final alt = real(d['alternativeTitle']);
        final desc = '${d['description'] ?? ''}'.trim();
        return SourceMangaDetails(
          url: url,
          title: '${d['title']}'.trim(),
          thumbnailUrl: _mythAbs(d['cover']),
          author: real(d['author']),
          artist: real(d['artist']),
          genres: [for (final g in (d['genres'] as List? ?? const [])) '$g'],
          description: [if (desc.isNotEmpty) desc, if (alt != null) 'Alternative titles: $alt'].join('\n\n'),
          status: switch ('${d['status']}'.toLowerCase()) {
            'ongoing' => SourceMangaStatus.ongoing,
            'completed' => SourceMangaStatus.completed,
            'hiatus' => SourceMangaStatus.hiatus,
            _ => SourceMangaStatus.unknown,
          },
          chapters: [
            for (final c in (d['chapters'] as List).cast<Map>().reversed)
              SourceChapter(
                url: '$_mythBase/read/${c['id']}',
                name: c['isLocked'] == true ? '🔒 ${c['title']}' : '${c['title']}',
                number: (c['number'] as num?)?.toDouble(),
                uploadedAt: DateTime.tryParse('${c['addedAt']}'),
              ),
          ],
        );
      },
      pagesFn: (s, ch) async {
        final html = (await s.fetchHtml(_u(ch.url))).body;
        final r = _jsonAfter(nextFlightBody(html), 'dataRead', (v) => v is Map && v.containsKey('pages')) as Map?;
        if (r == null) throw StateError('reader not found');
        if (r['isLocked'] == true) return const [];
        return [for (final p in (r['pages'] as List)) _mythAbs(p)!];
      },
    );

// ------------------------------------------------------------------- Bbato

String? _bbatoImg(Element? img, Uri base) {
  if (img == null) return null;
  final ds = attrAbs(img, 'data-src', base);
  return (ds != null && ds.isNotEmpty) ? ds : attrAbs(img, 'src', base);
}

Future<MangaPage> _bbatoList(FnSource s, Uri uri) async {
  final res = await s.fetchHtml(uri);
  final out = <SourceManga>[];
  for (final el in res.document.querySelectorAll('.original.card-lg .unit')) {
    final poster = el.querySelector('a.poster');
    final href = absUrl(res.url, poster?.attributes['href']);
    if (poster == null || href == null) continue;
    out.add(SourceManga(url: href, title: clean(el.querySelector('.info > a')?.text ?? ''), thumbnailUrl: _bbatoImg(poster.querySelector('img'), res.url)));
  }
  return MangaPage(out, hasNextPage: res.document.querySelector('.pagination a[rel=next]') != null);
}

List<String> _bbatoMeta(Element d, String label) {
  for (final div in d.querySelectorAll('.meta div')) {
    if (div.querySelector('span')?.text.contains(label) ?? false) return [for (final a in div.querySelectorAll('a')) clean(a.text)];
  }
  return const [];
}

FnSource _bbato() => FnSource(
      id: 'en.bbato',
      name: 'Bbato',
      baseUrl: 'https://bbato.com',
      contentWarning: ContentWarning.mixed,
      popularFn: (s, page) => _bbatoList(s, _u('${s.baseUrl}/filter').replace(queryParameters: {'sort': 'views', if (page > 1) 'page': '$page'})),
      latestFn: (s, page) => _bbatoList(s, _u('${s.baseUrl}/updated${page > 1 ? '/page/$page' : ''}')),
      searchFn: (s, page, q) => _bbatoList(s, _u('${s.baseUrl}/filter').replace(queryParameters: {'keyword': q, if (page > 1) 'page': '$page'})),
      detailsFn: (s, url) async {
        final res = await s.fetchHtml(_u(url));
        final d = res.document;
        final slug = _u(url).pathSegments.where((e) => e.isNotEmpty).last;
        final origin = _u(url).origin;
        final list = await s.fetchJson(_u('$origin/get-chapter-list?slug=$slug'), headers: const {'X-Requested-With': 'XMLHttpRequest', 'Accept': 'application/json'}) as Map;
        final chapters = <SourceChapter>[
          for (final c in (list['data'] as List? ?? const []).cast<Map>())
            SourceChapter(
              url: '$origin/read/$slug/${c['chapter_slug']}',
              name: '${c['chapter_name']}',
              number: parseChapterNumber('${c['chapter_name']}'),
              uploadedAt: DateTime.tryParse('${c['updated_at']}'.replaceFirst(' ', 'T')),
            ),
        ];
        return SourceMangaDetails(
          url: url,
          title: clean(d.querySelector('h1[itemprop=name]')?.text ?? ''),
          thumbnailUrl: _bbatoImg(d.querySelector('.poster img'), res.url),
          author: _bbatoMeta(d.documentElement!, 'Author').join(', '),
          description: clean(d.querySelector('.description')?.text ?? ''),
          genres: _bbatoMeta(d.documentElement!, 'Genres'),
          status: parseStatus(d.querySelector('.info > p')?.text),
          chapters: chapters,
        );
      },
      pagesFn: (s, ch) async {
        final res = await s.fetchHtml(_u(ch.url));
        return [
          for (final page in res.document.querySelectorAll('.pages .page'))
            if (!page.classes.contains('notice-page'))
              if (_bbatoImg(page.querySelector('img'), res.url) case final u? when !u.startsWith('data:')) u,
        ];
      },
    );

// ------------------------------------------------------------------ Inkora

const _inkApi = 'https://api.spacely.tech/manhwa/index';

Future<MangaPage> _inkList(FnSource s, Uri uri) async {
  final j = await s.fetchJson(uri, headers: const {'Accept': 'application/json'}) as Map;
  return MangaPage([
    for (final m in (j['results'] as List).cast<Map>())
      SourceManga(url: '${s.baseUrl}/title/${m['id']}', title: '${m['title']}', thumbnailUrl: m['image'] as String?),
  ], hasNextPage: j['hasNextPage'] == true);
}

FnSource _inkora() => FnSource(
      id: 'en.inkora',
      name: 'Inkora',
      baseUrl: 'https://inkora.spacely.tech',
      contentWarning: ContentWarning.mixed,
      popularFn: (s, page) => _inkList(s, _u('$_inkApi/advanced-search').replace(queryParameters: {'page': '$page', 'per_page': '24', 'sort': 'follows', 'order': 'desc'})),
      latestFn: (s, page) => _inkList(s, _u('$_inkApi/latest?page=$page')),
      searchFn: (s, page, q) => _inkList(s, _u('$_inkApi/advanced-search').replace(queryParameters: {'page': '$page', 'per_page': '24', 'q': q, 'sort': 'follows', 'order': 'desc'})),
      detailsFn: (s, url) async {
        final id = _u(url).pathSegments.where((e) => e.isNotEmpty).last;
        final d = await s.fetchJson(_u('$_inkApi/info/$id'), headers: const {'Accept': 'application/json'}) as Map;
        final alts = [for (final a in (d['altTitles'] as List? ?? const [])) if (a != d['title']) '$a'];
        final seen = <String>{};
        final chapters = <SourceChapter>[];
        void add(Map c) {
          if (!seen.add('${c['id']}')) return;
          final n = (c['chapterNumber'] as num?)?.toDouble();
          final t = '${c['title'] ?? ''}'.trim();
          chapters.add(SourceChapter(
            url: '${s.baseUrl}/manhwa/$id/read/${c['id']}',
            name: t.isNotEmpty ? t : 'Chapter ${n == null ? '?' : (n == n.roundToDouble() ? n.toInt() : n)}',
            number: n ?? -1,
            scanlator: (c['scanGroup'] as Map?)?['name'] as String?,
            uploadedAt: DateTime.tryParse('${c['releaseDate']}'),
          ));
        }

        for (final c in (d['chapters'] as List? ?? const []).cast<Map>()) {
          add(c);
          for (final v in (c['versions'] as List? ?? const []).cast<Map>()) {
            add(v);
          }
        }
        final desc = '${d['description'] ?? ''}'.trim();
        return SourceMangaDetails(
          url: url,
          title: '${d['title']}',
          thumbnailUrl: d['image'] as String?,
          author: (d['authors'] as List? ?? const []).join(', '),
          artist: (d['artists'] as List? ?? const []).join(', '),
          genres: {
            if (d['type'] != null) '${d['type']}',
            for (final g in (d['genres'] as List? ?? const [])) '$g'.replaceAll('_', ' ').replaceFirstMapped(RegExp(r'^\w'), (m) => m[0]!.toUpperCase()),
          }.toList(),
          description: [if (desc.isNotEmpty) desc, if (alts.isNotEmpty) 'Alternative titles:\n${alts.join('\n')}'].join('\n\n'),
          status: switch ('${d['status']}') {
            'releasing' || 'ongoing' => SourceMangaStatus.ongoing,
            'finished' || 'completed' => SourceMangaStatus.completed,
            'on_hiatus' || 'hiatus' => SourceMangaStatus.hiatus,
            'discontinued' || 'cancelled' => SourceMangaStatus.cancelled,
            _ => SourceMangaStatus.unknown,
          },
          chapters: chapters,
        );
      },
      pagesFn: (s, ch) async {
        final id = _u(ch.url).pathSegments.last;
        final j = await s.fetchJson(_u('$_inkApi/read/$id'), headers: const {'Accept': 'application/json'}) as Map;
        final pages = (j['pages'] as List).cast<Map>()..sort((a, b) => (a['page'] as num).compareTo(b['page'] as num));
        return [for (final p in pages) '${p['img']}'];
      },
    );

// --------------------------------------------------------------- KaliScans

Future<MangaPage> _kaliList(FnSource s, Uri uri) async {
  final res = await s.fetchHtml(uri);
  final out = <SourceManga>[];
  for (final el in res.document.querySelectorAll('div.book-item')) {
    final link = el.querySelector('h3 a[href]');
    final href = absUrl(res.url, link?.attributes['href']);
    if (link == null || href == null) continue;
    final img = el.querySelector('.thumb img');
    out.add(SourceManga(url: href, title: clean(link.text), thumbnailUrl: attrAbs(img, 'data-src', res.url)));
  }
  final next = res.document.querySelector('.paginator a.active ~ a.btn') != null;
  return MangaPage(out, hasNextPage: next);
}

String? _kaliMeta(Element info, String label, String sel) {
  for (final p in info.querySelectorAll('.meta p')) {
    if (p.querySelector('strong')?.text.contains(label) ?? false) return clean(p.querySelector(sel)?.text);
  }
  return null;
}

FnSource _kaliscans() => FnSource(
      id: 'en.kaliscans',
      name: 'KaliScans',
      baseUrl: 'https://kaliscans.org',
      contentWarning: ContentWarning.mixed,
      popularFn: (s, page) => _kaliList(s, _u('${s.baseUrl}/popular?page=$page')),
      latestFn: (s, page) => _kaliList(s, _u('${s.baseUrl}/latest?page=$page')),
      searchFn: (s, page, q) => _kaliList(s, _u('${s.baseUrl}/search').replace(queryParameters: {'q': q, 'status': 'all', 'sort': 'popular', 'page': '$page'})),
      detailsFn: (s, url) async {
        final res = await s.fetchHtml(_u(url));
        final d = res.document;
        final info = d.querySelector('.book-info');
        if (info == null) throw StateError('series not found');
        final slug = _u(url).pathSegments.where((e) => e.isNotEmpty).last;
        final seen = <String>{};
        final chapters = <SourceChapter>[];
        for (final a in d.querySelectorAll('#chapter-list li a')) {
          final href = absUrl(res.url, a.attributes['href']);
          if (href == null || !seen.add(href)) continue;
          chapters.add(SourceChapter(
            url: href,
            name: clean(a.querySelector('.chapter-title')?.text ?? ''),
            number: double.tryParse(_u(href).pathSegments.last.replaceAll('-', '.')),
            uploadedAt: parseLooseDate(a.querySelector('.chapter-update')?.text),
          ));
        }
        chapters.sort((a, b) => (b.number ?? -1).compareTo(a.number ?? -1));
        final alt = clean(info.querySelector('.name h2')?.text).split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        final title = clean(info.querySelector('.name h1')?.text);
        alt.removeWhere((e) => e.toLowerCase() == title.toLowerCase());
        final summary = clean(d.querySelector('.summary .content')?.text);
        return SourceMangaDetails(
          url: '${s.baseUrl}/series/$slug',
          title: title,
          thumbnailUrl: attrAbs(info.querySelector('#cover img'), 'data-src', res.url),
          author: _kaliMeta(info, 'Authors', 'span'),
          genres: [
            for (final p in info.querySelectorAll('.meta p'))
              if (p.querySelector('strong')?.text.contains('Genres') ?? false) for (final a in p.querySelectorAll('a')) clean(a.text).replaceAll(RegExp(r'[, ]+$'), ''),
          ],
          description: [if (summary.isNotEmpty) summary, if (alt.isNotEmpty) 'Alternative titles: ${alt.join(' · ')}'].join('\n\n'),
          status: parseStatus(_kaliMeta(info, 'Status', 'span')),
          chapters: chapters,
        );
      },
      pagesFn: (s, ch) async {
        final res = await s.fetchHtml(_u(ch.url));
        return [
          for (final img in res.document.querySelectorAll('#chapter-images img'))
            if (attrAbs(img, 'src', res.url) case final u? when u.isNotEmpty) u,
        ];
      },
    );

// ------------------------------------------------------------- MyMangaList

Future<MangaPage> _mmlList(FnSource s, int page, Map<String, String> q) async {
  final res = await s.fetchHtml(_u('${s.baseUrl}/advanced-search').replace(queryParameters: {'content_type': 'Series', ...q, 'page': '$page'}));
  final out = <SourceManga>[];
  for (final card in res.document.querySelectorAll('[data-results-feed] a.cardish')) {
    final href = absUrl(res.url, card.attributes['href']);
    if (href == null) continue;
    out.add(SourceManga(url: href, title: clean(card.querySelector('.card-copy strong')?.text ?? ''), thumbnailUrl: attrAbs(card.querySelector('img'), 'src', res.url)));
  }
  final shell = res.document.querySelector('[data-search-results-shell]');
  return MangaPage(out, hasNextPage: (shell?.attributes['data-next-page-url'] ?? '').isNotEmpty);
}

FnSource _mymangalist() => FnSource(
      id: 'en.mymangalist',
      name: 'MyMangaList',
      baseUrl: 'https://www5.mymangalist.org',
      contentWarning: ContentWarning.mixed,
      popularFn: (s, page) => _mmlList(s, page, {'sort': 'popular'}),
      latestFn: (s, page) => _mmlList(s, page, {'sort': 'newest'}),
      searchFn: (s, page, q) => _mmlList(s, page, {'q': q}),
      detailsFn: (s, url) async {
        final res = await s.fetchHtml(_u(url));
        final d = res.document;
        String? meta(String label) {
          for (final c in d.querySelectorAll('.meta-grid .meta-card')) {
            if (clean(c.querySelector('small')?.text) == label) {
              final v = clean(c.querySelector('strong')?.text);
              return (v.isEmpty || v == '-') ? null : v;
            }
          }
          return null;
        }

        final title = clean(d.querySelector('h1.page-heading')?.text);
        final alts = clean(d.querySelector('p.page-lead')?.text)
            .replaceFirst('Alternative title:', '')
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty && e.toLowerCase() != title.toLowerCase() && e.runes.any((r) => r != 0x3f))
            .toList();
        var story = '';
        for (final p in d.querySelectorAll('section.panel')) {
          if (clean(p.querySelector('h2')?.text).contains('Story Overview')) {
            story = clean(p.querySelector('p')?.text);
            break;
          }
        }
        final permalink = d.querySelector('#chapterGroups')?.attributes['data-title-permalink'];
        final chapters = <SourceChapter>[];
        if (permalink != null) {
          var offset = 0;
          while (true) {
            final j = await s.fetchJson(
              _u('${s.baseUrl}/api/titles/chapters.php').replace(queryParameters: {'permalink': permalink, 'offset': '$offset', 'limit': '50'}),
              headers: {'Accept': 'application/json', 'Referer': url},
            ) as Map;
            for (final c in ((j['group'] as Map)['items'] as List).cast<Map>()) {
              chapters.add(SourceChapter(
                url: '${s.baseUrl}/${c['href']}',
                name: '${c['label']}',
                number: parseChapterNumber('${c['label']}'),
                uploadedAt: parseLooseDate('${c['published_date'] ?? ''}'),
              ));
            }
            offset = (j['next_offset'] as num).toInt();
            if (j['has_more'] != true) break;
          }
        }
        return SourceMangaDetails(
          url: url,
          title: title,
          thumbnailUrl: attrAbs(d.querySelector('section.hero img'), 'src', res.url),
          author: meta('Author'),
          artist: meta('Artist'),
          genres: [for (final c in d.querySelectorAll('.genre-cluster .chip')) clean(c.text)],
          description: [if (story.isNotEmpty) story, if (alts.isNotEmpty) 'Alternative titles: ${alts.join(', ')}'].join('\n\n'),
          status: switch ((meta('Status') ?? '').toLowerCase()) {
            'ongoing' || 'on-going' || 'ong' => SourceMangaStatus.ongoing,
            'completed' || 'complete' || 'c' => SourceMangaStatus.completed,
            _ => SourceMangaStatus.unknown,
          },
          chapters: chapters,
        );
      },
      pagesFn: (s, ch) async {
        final res = await s.fetchHtml(_u(ch.url));
        final m = RegExp(r'MYMANGALIST_READER = (\{.*\});').firstMatch(res.body);
        if (m == null) throw StateError('reader not found');
        return [for (final p in (jsonDecode(m[1]!) as Map)['pageUrls'] as List) '$p'];
      },
    );

// ----------------------------------------------------------------- HentaiKun

List<SourceManga> _hkTable(HtmlResponse res) {
  final out = <SourceManga>[];
  for (final row in res.document.querySelectorAll('table.table-striped tr')) {
    if (row.classes.contains('danger')) continue;
    final a = row.querySelector('td a');
    final href = absUrl(res.url, a?.attributes['href']);
    if (a == null || href == null) continue;
    final tip = a.attributes['title'] ?? '';
    final img = RegExp('''src=["']([^"']+)["']''').firstMatch(tip)?[1];
    out.add(SourceManga(url: href, title: clean(a.text), thumbnailUrl: absUrl(res.url, img)));
  }
  return out;
}

List<SourceManga> _hkGallery(HtmlResponse res) {
  final out = <SourceManga>[];
  for (final div in res.document.querySelectorAll("div.thumbnail[id^='galary-']")) {
    final a = div.querySelector('div.overlay a');
    final href = absUrl(res.url, a?.attributes['href']);
    if (a == null || href == null) continue;
    out.add(SourceManga(url: href, title: clean(a.text), thumbnailUrl: attrAbs(div.querySelector('img.img-responsive'), 'src', res.url)));
  }
  return out;
}

Future<MangaPage> _hkList(FnSource s, String path) async {
  final res = await s.fetchHtml(_u('${s.baseUrl}$path'));
  final items = res.document.querySelector('table.table-striped') != null ? _hkTable(res) : _hkGallery(res);
  return MangaPage(items, hasNextPage: res.document.querySelector('ul.pagination li[aria-label=Next]') != null);
}

FnSource _hentaikun() => FnSource(
      id: 'en.hentaikun',
      name: 'HentaiKun',
      baseUrl: 'https://hentaikun.com',
      contentWarning: ContentWarning.nsfw,
      popularFn: (s, page) => _hkList(s, '/manga/manga-list/most-viewed/${page > 1 ? '$page/' : ''}'),
      latestFn: (s, page) => _hkList(s, '/manga/manga-list/last-updated/${page > 1 ? '$page/' : ''}'),
      searchFn: (s, page, q) => _hkList(s, '/manga/search/title/${Uri.encodeComponent(q)}/${page > 1 ? '$page/' : ''}'),
      detailsFn: (s, url) async {
        final res = await s.fetchHtml(_u(url));
        final d = res.document;
        List<String> linked(String label) {
          for (final h in d.querySelectorAll('h2')) {
            if (h.querySelector('strong')?.text.contains(label) ?? false) return [for (final a in h.querySelectorAll('a')) clean(a.text)];
          }
          return const [];
        }

        final og = d.querySelector("meta[property='og:image']")?.attributes['content'];
        final chapters = <SourceChapter>[];
        for (final a in d.querySelectorAll('table a.readchap')) {
          final href = absUrl(res.url, a.attributes['href']);
          if (href == null) continue;
          final name = clean(a.text);
          Element? tr = a.parent;
          while (tr != null && tr.localName != 'tr') {
            tr = tr.parent;
          }
          chapters.add(SourceChapter(
            url: href,
            name: name.isEmpty ? 'Chapter' : name,
            number: double.tryParse(RegExp(r'(\d+(?:\.\d+)?)').firstMatch(name)?[1] ?? '') ?? 1,
            uploadedAt: parseLooseDate(tr?.querySelector('td:last-child h6')?.text),
          ));
        }
        return SourceMangaDetails(
          url: url,
          title: clean(d.querySelector('div.single_title h1')?.text),
          thumbnailUrl: absUrl(res.url, og),
          author: linked('Artist').join(', '),
          genres: [
            ...linked('Category').take(1),
            for (final sp in d.querySelectorAll("div.desc a[href*='/tag/'] span.label-danger")) clean(sp.text),
          ],
          status: SourceMangaStatus.completed,
          chapters: chapters,
        );
      },
      pagesFn: (s, ch) async {
        final seg = _u(ch.url).pathSegments;
        final key = '${seg[2]}/${seg[3]}';
        final res = await s.fetchHtml(_u(ch.url), headers: {'Cookie': '$key=2'});
        for (final sc in res.document.querySelectorAll('script')) {
          final data = sc.text;
          if (!data.contains('var jsondata=')) continue;
          final json = data.split('var jsondata=').last.split(';').first;
          return [for (final u in jsonDecode(json) as List) '$u'];
        }
        throw StateError('no images');
      },
    );

// ---------------------------------------------------------------- Pornhwa.me

String _pmOriginal(String url) {
  final u = Uri.tryParse(url);
  if (u != null && u.host.endsWith('.wp.com')) return 'https://${u.path.replaceFirst('/', '')}';
  return url;
}

Future<MangaPage> _pmList(FnSource s, Uri uri) async {
  final res = await s.fetchHtml(uri);
  final out = <SourceManga>[];
  for (final card in res.document.querySelectorAll('#komikbaru [itemtype]')) {
    if (!(card.attributes['itemtype'] ?? '').endsWith('ComicSeries')) continue;
    final link = card.querySelector('a[itemprop=url][title]');
    final href = absUrl(res.url, link?.attributes['href']);
    if (link == null || href == null) continue;
    final cover = attrAbs(card.querySelector('img'), 'src', res.url);
    out.add(SourceManga(url: href, title: clean(link.querySelector('[itemprop=name]')?.text), thumbnailUrl: cover == null ? null : _pmOriginal(cover)));
  }
  return MangaPage(out, hasNextPage: out.isNotEmpty && res.document.querySelector('link[rel=next]') != null);
}

Uri _pmListing(FnSource s, String path, int page) => _u('${s.baseUrl}/$path/${page > 1 ? '$page/' : ''}');

FnSource _pornhwame() => FnSource(
      id: 'en.pornhwame',
      name: 'Pornhwa.me',
      baseUrl: 'https://pornhwa.me',
      contentWarning: ContentWarning.nsfw,
      popularFn: (s, page) => _pmList(s, _pmListing(s, 'trending', page)),
      latestFn: (s, page) => _pmList(s, _pmListing(s, 'latest-update', page)),
      searchFn: (s, page, q) => _pmList(s, _u('${s.baseUrl}/search/${Uri.encodeComponent(q)}/')),
      detailsFn: (s, url) async {
        final res = await s.fetchHtml(_u(url));
        final d = res.document;
        String? info(String label) {
          for (final sp in d.querySelectorAll('span')) {
            final b = sp.children.isNotEmpty && sp.children.first.localName == 'b' ? sp.children.first : null;
            if (b != null && ownText(b).contains(label)) {
              final v = clean(sp.text.replaceFirst(b.text, ''));
              return (v.isEmpty || v == '-') ? null : v;
            }
          }
          return null;
        }

        String? synopsis;
        for (final sc in d.querySelectorAll('script[type="application/ld+json"]')) {
          try {
            final j = jsonDecode(sc.text);
            if (j is Map && j['@type'] == 'CreativeWorkSeries') synopsis = j['description'] as String?;
          } on FormatException {
            continue;
          }
        }
        final title = clean(d.querySelector('article h1')?.text);
        var alt = info('Alternative Title');
        if (alt != null && alt.startsWith('(') && alt.endsWith(')')) alt = alt.substring(1, alt.length - 1);
        if (alt != null && alt.toLowerCase().contains(title.toLowerCase())) alt = null;
        final chapters = <SourceChapter>[];
        for (final li in d.querySelectorAll('ul#chapter-list > li[data-ch]')) {
          final a = li.querySelector('a');
          final href = absUrl(res.url, a?.attributes['href']);
          if (a == null || href == null) continue;
          final name = clean(a.querySelector('span')?.text);
          chapters.add(SourceChapter(url: href, name: name, number: double.tryParse(li.attributes['data-ch'] ?? '') ?? parseChapterNumber(name)));
        }
        return SourceMangaDetails(
          url: url,
          title: title,
          thumbnailUrl: attrAbs(d.querySelector('[itemprop=image] img'), 'src', res.url),
          author: info('Author'),
          artist: info('Artist'),
          genres: {
            for (final a in d.querySelectorAll('article a')) if ((a.attributes['href'] ?? '').startsWith('/genre/')) clean(a.text),
            if (info('Type') != null) info('Type')!,
          }.toList(),
          description: [if (synopsis != null && synopsis.isNotEmpty) synopsis, if (alt != null) 'Alternative titles: $alt'].join('\n\n'),
          status: switch (info('Status')) {
            'on-going' => SourceMangaStatus.ongoing,
            'completed' => SourceMangaStatus.completed,
            _ => SourceMangaStatus.unknown,
          },
          chapters: chapters,
        );
      },
      pagesFn: (s, ch) async {
        final res = await s.fetchHtml(_u(ch.url));
        return [
          for (final img in res.document.querySelectorAll('img.chapter-img'))
            if (attrAbs(img, 'src', res.url) case final u? when u.isNotEmpty) u,
        ];
      },
    );

// ----------------------------------------------------------------- StreameX

SourceManga _sxEntry(FnSource s, Map m) {
  final t = (m['title'] as Map);
  final names = [t['english'], t['romaji'], t['native']].where((e) => e != null && '$e'.trim().isNotEmpty).toList();
  final cover = m['coverImage'] as Map?;
  return SourceManga(url: '${s.baseUrl}/manga/${m['id']}', title: '${names.first}', thumbnailUrl: (cover?['extraLarge'] ?? cover?['large']) as String?);
}

Future<MangaPage> _sxList(FnSource s, String path, Map<String, String> q) async {
  final j = await s.fetchJson(_u('${s.baseUrl}/api/manga/$path').replace(queryParameters: q), headers: const {'Accept': 'application/json'}) as Map;
  return MangaPage(
    [for (final m in (j['results'] as List).cast<Map>()) _sxEntry(s, m)],
    hasNextPage: (j['page'] as num) < (j['total_pages'] as num),
  );
}

FnSource _streamex() => FnSource(
      id: 'en.streamex',
      name: 'StreameX',
      baseUrl: 'https://streamex.hn',
      contentWarning: ContentWarning.mixed,
      popularFn: (s, page) => _sxList(s, 'popular', {'page': '$page'}),
      searchFn: (s, page, q) => _sxList(s, 'search', {'query': q, 'page': '$page'}),
      detailsFn: (s, url) async {
        final id = _u(url).pathSegments.where((e) => e.isNotEmpty).last;
        final d = await s.fetchJson(_u('${s.baseUrl}/api/manga/info/$id'), headers: const {'Accept': 'application/json'}) as Map;
        final ch = await s.fetchJson(_u('${s.baseUrl}/api/manga/chapters?id=$id'), headers: const {'Accept': 'application/json'}) as Map;
        final t = d['title'] as Map;
        final names = [t['english'], t['romaji'], t['native']].where((e) => e != null && '$e'.trim().isNotEmpty).map((e) => '$e').toSet().toList();
        List<String> staff(List<String> roles) {
          final edges = ((d['staff'] as Map?)?['edges'] as List? ?? const []).cast<Map>();
          return {
            for (final e in edges)
              if (roles.any((r) => '${e['role']}'.startsWith(r))) '${((e['node'] as Map)['name'] as Map)['full']}',
          }.toList();
        }

        final cover = d['coverImage'] as Map?;
        final desc = clean(html.parseFragment('${d['description'] ?? ''}'.replaceAll(RegExp(r'<br\s*/?>'), '\n')).text);
        return SourceMangaDetails(
          url: url,
          title: names.first,
          thumbnailUrl: (cover?['extraLarge'] ?? cover?['large']) as String?,
          author: staff(['Story', 'Original']).join(', '),
          artist: staff(['Art', 'Story & Art']).join(', '),
          genres: [for (final g in (d['genres'] as List? ?? const [])) '$g'],
          description: [if (desc.isNotEmpty) desc, if (names.length > 1) 'Alternative titles: ${names.skip(1).join(', ')}'].join('\n\n'),
          status: switch (d['status']) {
            'RELEASING' => SourceMangaStatus.ongoing,
            'FINISHED' => SourceMangaStatus.completed,
            'HIATUS' => SourceMangaStatus.hiatus,
            'CANCELLED' => SourceMangaStatus.cancelled,
            _ => SourceMangaStatus.unknown,
          },
          chapters: [
            for (final c in (ch['chapters'] as List? ?? const []).cast<Map>())
              SourceChapter(
                url: '${s.baseUrl}/manga/read/$id?chapterId=${c['id']}',
                name: '${c['title']}',
                number: double.tryParse('${c['chapter']}') ?? -1,
              ),
          ],
        );
      },
      pagesFn: (s, ch) async {
        final chapterId = _u(ch.url).queryParameters['chapterId'];
        final res = await s.dio.getUri<String>(_u('${s.baseUrl}/api/manga/pages?chapterId=$chapterId'), options: Options(headers: {'Accept': 'application/json', 'Referer': ch.url}));
        final proxy = res.realUri.resolve('/api/manga-image');
        final pages = jsonDecode(res.data ?? '[]') as List;
        return [for (final p in pages.cast<Map>()) proxy.replace(queryParameters: {'url': '${p['img']}'}).toString()];
      },
    );

// ---------------------------------------------------------------- BabeSource

List<SourceManga> _babeCards(HtmlResponse res) {
  final out = <SourceManga>[];
  for (final card in res.document.querySelectorAll('.main-content__cards .main-content__tumba')) {
    final link = card.querySelector('a.main-content__card-link');
    final href = absUrl(res.url, link?.attributes['href']);
    if (link == null || href == null || !href.contains('/galleries/')) continue;
    final img = link.querySelector('img');
    out.add(SourceManga(url: href, title: clean(img?.attributes['alt']), thumbnailUrl: attrAbs(img, 'src', res.url)));
  }
  return out;
}

Future<MangaPage> _babeList(FnSource s, Uri base, int page) async {
  var uri = base;
  if (page > 1) {
    final segs = [...base.pathSegments.where((e) => e.isNotEmpty)];
    uri = base.replace(pathSegments: [...segs, 'page$page.html']);
  }
  final res = await s.fetchHtml(uri);
  return MangaPage(_babeCards(res), hasNextPage: res.document.querySelector('a.paginations__next[rel=next]') != null);
}

FnSource _babesource() => FnSource(
      id: 'en.babesource',
      name: 'BabeSource',
      baseUrl: 'https://babesource.com',
      contentWarning: ContentWarning.nsfw,
      popularFn: (s, page) => _babeList(s, _u('${s.baseUrl}/most-viewed/'), page),
      latestFn: (s, page) => _babeList(s, _u('${s.baseUrl}/newest/'), page),
      searchFn: (s, page, q) async {
        // Gerbang pencarian situs mengalihkan ke daftar hasil; ikuti pengalihannya.
        final gate = await s.fetchHtml(_u('${s.baseUrl}/searchgate.php').replace(queryParameters: {'mode': 'search', 'type': 'photos', 'q': q}));
        if (page == 1) return MangaPage(_babeCards(gate), hasNextPage: gate.document.querySelector('a.paginations__next[rel=next]') != null);
        final base = gate.url.replace(pathSegments: gate.url.pathSegments.where((e) => e.isNotEmpty && !RegExp(r'^page\d+\.html$').hasMatch(e)).toList());
        return _babeList(s, base.replace(path: '${base.path}/'), page);
      },
      detailsFn: (s, url) async {
        final res = await s.fetchHtml(_u(url));
        final d = res.document;
        final aside = d.querySelector('aside.aside-setting');
        final models = [for (final a in aside?.querySelectorAll('.aside-setting__chapter--models a') ?? const []) clean(a.querySelector('strong')?.text)].where((e) => e.isNotEmpty).toList();
        final paysite = clean(aside?.querySelector('.aside-setting__chapter--paysite a .aside-link-text')?.text);
        final cats = <String>{
          for (final a in [...?aside?.querySelectorAll('.aside-setting__chapter--categories a'), ...?aside?.querySelectorAll('a.aside-setting__category-link')])
            if (clean(a.text).isNotEmpty) clean(a.text),
        };
        final photos = d.querySelectorAll('a.slideshowGalleryImage');
        final title = clean(d.querySelector('title')?.text);
        final dates = [for (final sp in aside?.querySelectorAll('.aside-setting__views-item span:last-child') ?? const []) clean(sp.text)];
        return SourceMangaDetails(
          url: url,
          title: title.contains(' | ') ? title.substring(0, title.lastIndexOf(' | ')) : title,
          thumbnailUrl: attrAbs(photos.isEmpty ? null : photos.first.querySelector('img'), 'src', res.url),
          author: models.join(', '),
          artist: paysite,
          genres: cats.toList(),
          description: '${photos.length} photos',
          status: SourceMangaStatus.completed,
          chapters: [
            SourceChapter(
              url: url,
              name: 'Gallery',
              number: 1,
              uploadedAt: DateTime.tryParse(dates.firstWhere((e) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(e), orElse: () => '')),
            ),
          ],
        );
      },
      pagesFn: (s, ch) async {
        final res = await s.fetchHtml(_u(ch.url));
        return [for (final a in res.document.querySelectorAll('a.slideshowGalleryImage')) if (absUrl(res.url, a.attributes['href']) case final u?) u];
      },
    );

List<MangaSource> portsAa() => [_myadultcomics(), _schalescans(), _mythtoons(), _bbato(), _inkora(), _kaliscans(), _mymangalist(), _hentaikun(), _pornhwame(), _streamex(), _babesource()];
