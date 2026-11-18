// Situs katalog (bagian AA), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0).

import 'package:html/dom.dart';

import 'dart:convert';
import 'ports_util.dart';
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

List<MangaSource> portsAa() => [_myadultcomics(), _schalescans(), _mythtoons()];
