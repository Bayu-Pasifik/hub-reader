// Situs katalog (bagian T: situs berbasis API JSON — Komix, LustToon,
// MangaMelon), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0).

import 'dart:convert';

import '../html_utils.dart';
import '../models.dart';
import '../next_rsc.dart';
import '../source.dart';
import 'fn_source.dart';
import 'ports_util.dart';

String? _abs(String base, String? path) => path == null || path.isEmpty ? null : Uri.parse(base).resolve(path).toString();

DateTime? _iso(Object? v) => v == null ? null : DateTime.tryParse('$v');

Future<Object?> _api(FnSource s, String path) => s.fetchJson(Uri.parse(path), headers: const {'Accept': 'application/json'});

// ---------------------------------------------------------------- Komix ---

Future<MangaPage> _komixList(FnSource s, int page, {String q = '', String sort = ''}) async {
  final j = await _api(
    s,
    Uri.parse('${s.baseUrl}/api/page-data/browse').replace(queryParameters: {
      if (q.isNotEmpty) 'q': q,
      if (page > 1) 'page': '$page',
      if (sort.isNotEmpty) 'sort': sort,
    }).toString(),
  ) as Map;
  final results = (j['results'] as List).cast<Map>();
  return MangaPage([
    for (final r in results)
      SourceManga(
        url: '${s.baseUrl}/title/${r['slug']}',
        title: clean('${r['title']}'),
        thumbnailUrl: _abs(s.baseUrl, r['cover_image'] as String?),
      ),
  ], hasNextPage: ((j['page'] as num?) ?? 1) * 60 < ((j['totalCount'] as num?) ?? 0));
}

FnSource _komix() => FnSource(
      id: 'en.komix',
      name: 'Komix',
      baseUrl: 'https://komix.to',
      contentWarning: ContentWarning.mixed,
      popularFn: (s, page) => _komixList(s, page),
      latestFn: (s, page) => _komixList(s, page, sort: 'date'),
      searchFn: (s, page, q) => _komixList(s, page, q: q, sort: 'relevance'),
      detailsFn: (s, url) async {
        final slug = Uri.parse(url).pathSegments.last;
        final j = await _api(s, '${s.baseUrl}/api/page-data/title/$slug') as Map;
        final m = j['manga'] as Map;
        String? synopsis;
        try {
          final ld = jsonDecode('${j['jsonLd']}') as Map;
          for (final n in (ld['@graph'] as List).cast<Map>()) {
            if (n['@type'] == 'Book') synopsis = n['description'] as String?;
          }
        } catch (_) {}
        final alts = (m['alternative_titles'] as List?)?.map((e) => '- ${'$e'.trim()}').join('\n');
        final desc = [if (synopsis != null) synopsis.trim(), if (alts != null && alts.isNotEmpty) 'Alternative titles:\n$alts'].join('\n\n');
        final type = m['type'] as String?;
        final chapters = <SourceChapter>[];
        for (final c in (j['chapters'] as List).cast<Map>()) {
          final chNum = (c['chapter_number'] as num).toDouble();
          final n = chNum == chNum.roundToDouble() ? '${chNum.toInt()}' : '$num';
          final group = c['group'] as String?;
          chapters.add(SourceChapter(
            url: '${s.baseUrl}/title/${m['slug']}/chapter/$n${group == null ? '' : '?group=${Uri.encodeQueryComponent(group)}'}',
            name: '${c['title']}',
            number: chNum,
            scanlator: group == null || group == '(none)' ? null : group,
            uploadedAt: _iso(c['release_date'] ?? c['created_at']),
          ));
        }
        return SourceMangaDetails(
          url: url,
          title: clean('${m['title']}'),
          thumbnailUrl: _abs(s.baseUrl, m['cover_image'] as String?),
          author: m['author'] as String?,
          artist: m['artist'] as String?,
          description: desc.isEmpty ? null : desc,
          genres: [
            if (type != null && type.isNotEmpty) type[0].toUpperCase() + type.substring(1),
            for (final g in (m['genres'] as List? ?? const []).cast<Map>()) '${g['name']}',
          ],
          status: parseStatus(m['status'] as String?),
          chapters: chapters,
        );
      },
      pagesFn: (s, ch) async {
        final body = await s.fetchText(Uri.parse(ch.url), headers: const {'RSC': '1'});
        var obj = findRscObject(body, (o) => o['chapter'] is Map && o.containsKey('manga'));
        obj ??= findRscObject(nextFlightBody(await s.fetchText(Uri.parse(ch.url))), (o) => o['chapter'] is Map && o.containsKey('manga'));
        final pages = ((obj?['chapter'] as Map?)?['pages'] as List? ?? const []).cast<Map>();
        return [
          for (final p in pages) '${s.baseUrl}/api/images?t=${Uri.encodeQueryComponent('${p['enc']}')}',
        ];
      },
    );

// ------------------------------------------------------------- LustToon ---

const _lustApi = 'https://back.lustoon.com';

MangaPage _lustPage(Object? json) {
  final m = json as Map;
  final meta = m['meta'] as Map?;
  final items = (m['data'] as List? ?? const []).cast<Map>().where((e) => e['slug'] != null);
  return MangaPage([
    for (final i in items)
      SourceManga(
        url: 'https://lustoon.com/comic/${i['slug']}',
        title: clean('${i['name']}'),
        thumbnailUrl: (i['urlImg'] as String?)?.replaceFirst('http://', 'https://'),
      ),
  ], hasNextPage: ((meta?['current_page'] as num?) ?? 1) < ((meta?['last_page'] as num?) ?? 1));
}

Future<MangaPage> _lustFilter(FnSource s, int page, String orderBy) async => _lustPage(await _api(
    s,
    Uri.parse('$_lustApi/filtrar').replace(queryParameters: {
      'page': '$page',
      'limit': '24',
      'orderBy': orderBy,
      'sort': 'desc',
      'gendersId': '',
      'origin': '',
      'state': '',
      'loading': 'true',
    }).toString()));

FnSource _lustoon() => FnSource(
      id: 'en.lusttoon',
      name: 'LustToon',
      baseUrl: 'https://lustoon.com',
      contentWarning: ContentWarning.nsfw,
      popularFn: (s, page) => _lustFilter(s, page, '6'),
      latestFn: (s, page) => _lustFilter(s, page, '3'),
      searchFn: (s, page, q) async {
        if (page > 1) return const MangaPage([], hasNextPage: false);
        final j = await _api(s, Uri.parse('$_lustApi/home/buscar').replace(queryParameters: {'query': q}).toString()) as List;
        return _lustPage({'data': j});
      },
      detailsFn: (s, url) async {
        final body = await s.fetchText(Uri.parse(url), headers: const {'RSC': '1'});
        var serie = findRscObject(body, (o) => o.containsKey('slug') && o['chapters'] is List);
        serie ??= findRscObject(nextFlightBody(await s.fetchText(Uri.parse(url))), (o) => o.containsKey('slug') && o['chapters'] is List);
        if (serie == null) throw StateError('Seri tidak ditemukan');
        final slug = '${serie['slug']}';
        final chapters = <SourceChapter>[];
        for (final c in (serie['chapters'] as List).cast<Map>().where((e) => e['slug'] != null)) {
          final nm = c['name'] as String?;
          final chNum = (c['num'] as num?)?.toDouble();
          chapters.add(SourceChapter(
            url: 'https://lustoon.com/comic/$slug/${c['slug']}',
            name: nm != null && RegExp(r'\d').hasMatch(nm)
                ? nm
                : 'Chapter ${chNum == null ? '' : (chNum.roundToDouble() == chNum ? chNum.toInt() : chNum)}'.trim(),
            number: chNum,
            uploadedAt: _iso(c['createdAt']),
          ));
        }
        return SourceMangaDetails(
          url: url,
          title: clean('${serie['name']}'),
          thumbnailUrl: (serie['urlImg'] as String?)?.replaceFirst('http://', 'https://'),
          description: serie['sinopsis'] as String?,
          genres: [for (final g in (serie['genders'] as List? ?? const []).cast<Map>()) '${g['name']}'],
          status: parseStatus((serie['state'] as Map?)?['estado'] as String?),
          chapters: chapters,
        );
      },
      pagesFn: (s, ch) async {
        final html = await s.fetchText(Uri.parse(ch.url));
        final flight = nextFlightBody(html);
        final obj = findRscObject(flight, (o) => o.containsKey('urlImg') && o.containsKey('chapterId'));
        var images = <String>[];
        try {
          images = [for (final u in (jsonDecode('${obj?['urlImg']}') as List)) '$u'];
        } catch (_) {}
        if (images.isEmpty) {
          images = [
            for (final m in RegExp(r'https?://media\.lustoon\.com/file/[^"\s' "'" r'\\]+\.(?:jpg|jpeg|png|webp|avif)', caseSensitive: false)
                .allMatches(html))
              if (m[0]!.contains('/serie/')) m[0]!,
          ];
        }
        return images.map((u) => u.replaceFirst('http://', 'https://')).where((u) => !u.contains('brakeout')).toSet().toList();
      },
    );

// ----------------------------------------------------------- MangaMelon ---

const _melonApi = 'https://api.mangamelon.com';

Future<Map> _melon(FnSource s, String path, Map<String, Object?> body) async {
  final data = base64.encode(utf8.encode(jsonEncode(body)));
  return await s.postFormJson(Uri.parse('$_melonApi/$path'), {'data': data, 'sessionid': ''}) as Map;
}

SourceManga _melonItem(Map m) => SourceManga(
      url: 'https://mangamelon.com/manga/${m['id']}',
      title: clean('${m['title']}'),
      thumbnailUrl: (m['cover'] as String?)?.isEmpty == true ? null : m['cover'] as String?,
    );

Future<MangaPage> _melonList(FnSource s, int page, {String search = '', String sort = 'popular'}) async {
  const size = 36;
  final skip = (page - 1) * size;
  final j = await _melon(s, 'api/manga/list', {
    'search': search,
    'genre': '',
    'lang': 'en',
    'sort': sort,
    'includeNsfw': true,
    'limit': size,
    'skip': skip,
  });
  final list = (j['list'] as List).cast<Map>();
  final total = (j['total'] as num?)?.toInt() ?? -1;
  return MangaPage([for (final m in list) _melonItem(m)], hasNextPage: total > 0 ? skip + list.length < total : list.length >= size);
}

FnSource _mangamelon() => FnSource(
      id: 'en.mangamelon',
      name: 'MangaMelon',
      baseUrl: 'https://mangamelon.com',
      contentWarning: ContentWarning.mixed,
      popularFn: (s, page) => _melonList(s, page),
      latestFn: (s, page) => _melonList(s, page, sort: 'latest'),
      searchFn: (s, page, q) => _melonList(s, page, search: q, sort: 'latest'),
      detailsFn: (s, url) async {
        final id = Uri.parse(url).pathSegments.last;
        final m = (await _melon(s, 'api/manga/get', {'target': id, 'withReviews': false}))['manga'] as Map;
        final all = <Map>[];
        var skip = 0;
        while (true) {
          final r = await _melon(s, 'api/chapter/list', {'target': id, 'status': 0, 'limit': 1000, 'skip': skip, 'pending': '', 'force': true});
          final cs = (r['chapters'] as List? ?? const []).cast<Map>();
          all.addAll(cs);
          skip += cs.length;
          if (cs.length < 1000) break;
        }
        all.sort((a, b) => ((b['seq'] as num?) ?? 0).compareTo((a['seq'] as num?) ?? 0));
        return SourceMangaDetails(
          url: url,
          title: clean('${m['title']}'),
          thumbnailUrl: m['cover'] as String?,
          author: m['authors'] as String?,
          description: m['desc'] as String?,
          genres: [for (final g in (m['genres'] as List? ?? const [])) '$g'],
          status: parseStatus(m['status'] as String?),
          chapters: [
            for (final c in all)
              SourceChapter(
                url: 'https://mangamelon.com/chapter/$id/${c['id']}',
                name: '${c['title']}',
                number: parseChapterNumber('${c['title']}'),
                uploadedAt: '${c['updated']}'.startsWith('0001-') ? null : _iso(c['updated']),
              ),
          ],
        );
      },
      pagesFn: (s, ch) async {
        final r = await _melon(s, 'api/chapter/get', {'target': ch.url.split('/').last, 'all': true});
        final pages = ((r['chapter'] as Map)['pages'] as List? ?? const []).cast<Map>().toList()
          ..sort((a, b) => ((a['seq'] as num?) ?? 0).compareTo((b['seq'] as num?) ?? 0));
        return [for (final p in pages) '${p['url']}'];
      },
    );

List<MangaSource> portsT() => [_komix(), _lustoon(), _mangamelon()];
