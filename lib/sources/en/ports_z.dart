// Situs katalog (bagian Z: Sacachispa, NexComic), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0). Bab khusus Patreon disembunyikan;
// filter genre/katalog komisi belum ada.

import 'dart:convert';

import '../models.dart';
import '../source.dart';
import 'fn_source.dart';

const _api = 'https://api.sacachispa.site/api';
const _cdn = 'https://cdn.sacachispa.site/';

String? _cover(Object? path) => path == null ? null : Uri.parse(_cdn).resolve('$path').toString();

String? _join(Iterable<Object?> items) {
  final out = items.map((e) => '$e').where((e) => e.isNotEmpty).join(', ');
  return out.isEmpty ? null : out;
}

List<String> _genres(Object? demographic, Iterable<Object?> genres) => [
      if (demographic != null && demographic != 'NONE') '$demographic',
      for (final g in genres) '$g',
    ];

SourceMangaStatus _status(Object? s) => switch (s) {
      'ONGOING' => SourceMangaStatus.ongoing,
      'COMPLETED' => SourceMangaStatus.completed,
      'HIATUS' => SourceMangaStatus.hiatus,
      'DROPPED' => SourceMangaStatus.cancelled,
      _ => SourceMangaStatus.unknown,
    };

SourceManga _entry(FnSource s, Map m) => SourceManga(
      url: '${s.baseUrl}/manga/${m['id']}/${m['slug']}',
      title: '${m['title']}',
      thumbnailUrl: _cover(m['cover']),
    );

Future<Map> _get(FnSource s, String url) async => await s.fetchJson(Uri.parse(url), headers: const {'Accept': 'application/json'}) as Map;

Future<MangaPage> _catalog(FnSource s, int page, String? query) async {
  final uri = Uri.parse(query == null ? '$_api/manga' : '$_api/manga/search').replace(queryParameters: {
    if (query != null) 'q': query,
    'page': '$page',
    'limit': '24',
  });
  final j = await _get(s, uri.toString());
  final p = j['pagination'] as Map;
  return MangaPage([for (final m in (j['data'] as List).cast<Map>()) _entry(s, m)], hasNextPage: (p['page'] as num) < (p['pages'] as num));
}

FnSource _sacachispa() => FnSource(
      id: 'en.sacachispa',
      name: 'SACACHISPA',
      baseUrl: 'https://sacachispa.site',
      contentWarning: ContentWarning.mixed,
      popularFn: (s, page) => _catalog(s, page, null),
      latestFn: (s, page) async {
        final j = await _get(s, '$_api/releases?page=$page&limit=100');
        final seen = <String>{};
        return MangaPage([
          for (final r in (j['data'] as List).cast<Map>())
            if (seen.add('${(r['manga'] as Map)['id']}')) _entry(s, r['manga'] as Map),
        ], hasNextPage: false);
      },
      searchFn: (s, page, q) => _catalog(s, page, q),
      detailsFn: (s, url) async {
        final seg = Uri.parse(url).pathSegments;
        final id = seg[seg.indexOf('manga') + 1];
        final d = (await _get(s, '$_api/manga/$id'))['data'] as Map;
        final syn = (d['synopses'] as List).cast<Map>();
        final alts = <String>{for (final t in (d['titles'] as List).cast<Map>()) '${t['title']}'}..remove('${d['title']}');
        final chapters = <SourceChapter>[];
        var page = 1;
        var pages = 1;
        do {
          final j = await _get(s, '$_api/releases?mangaId=${d['id']}&page=$page&limit=500');
          pages = ((j['pagination'] as Map)['pages'] as num).toInt();
          for (final r in (j['data'] as List).cast<Map>()) {
            final c = r['chapter'] as Map;
            final freeAt = DateTime.tryParse('${c['freeAt'] ?? ''}');
            final locked = freeAt != null ? freeAt.isAfter(DateTime.now()) : c['patreonOnly'] == true;
            if (locked) continue;
            final title = '${c['title'] ?? ''}'.trim();
            chapters.add(SourceChapter(
              url: '${s.baseUrl}/read/${r['id']}',
              name: 'Chapter ${c['chapter']}${title.isEmpty ? '' : ' - $title'}',
              number: double.tryParse('${c['chapter']}') ?? -1,
              uploadedAt: DateTime.tryParse('${r['publishedAt']}'),
            ));
          }
        } while (page++ < pages);
        chapters.sort((a, b) => (b.number ?? -1).compareTo(a.number ?? -1));
        return SourceMangaDetails(
          url: url,
          title: '${d['title']}',
          thumbnailUrl: _cover(d['cover']),
          author: _join((d['authors'] as List).cast<Map>().map((e) => e['name'])),
          artist: _join((d['artists'] as List).cast<Map>().map((e) => e['name'])),
          genres: _genres(d['demographic'], (d['genres'] as List).cast<Map>().map((e) => e['name'])),
          description: [
            if (syn.isNotEmpty) '${syn.first['synopsis']}',
            if (alts.isNotEmpty) 'Alternative titles:\n${alts.map((e) => '- $e').join('\n')}',
          ].join('\n\n'),
          status: _status(d['status']),
          chapters: chapters,
        );
      },
      pagesFn: (s, ch) async {
        final id = Uri.parse(ch.url).pathSegments.last;
        final j = await _get(s, '$_api/releases/$id/pages');
        return [for (final p in ((j['data'] as Map)['items'] as List).cast<Map>()) '${p['url']}'];
      },
    );

// ---------------------------------------------------------------- NexComic

/// Larik JSON pertama setelah `"key":` di [body] yang lolos [accept]; dipindai
/// langsung karena potongan teks RSC bisa memuat baris baru.
List<Map>? _arrayAfter(String body, String key, bool Function(Map first) accept) {
  final needle = '"$key":[';
  var from = 0;
  while (true) {
    final at = body.indexOf(needle, from);
    if (at < 0) return null;
    from = at + needle.length;
    final start = from - 1;
    var depth = 0;
    var inString = false;
    var end = -1;
    for (var i = start; i < body.length; i++) {
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
      final list = jsonDecode(body.substring(start, end + 1)) as List;
      if (list.isNotEmpty && list.first is Map && accept(list.first as Map)) return list.cast<Map>();
    } on FormatException {
      continue;
    }
  }
}

SourceMangaStatus _nexStatus(Object? s) => switch ('$s'.toLowerCase()) {
      'ongoing' => SourceMangaStatus.ongoing,
      'completed' => SourceMangaStatus.completed,
      'hiatus' => SourceMangaStatus.hiatus,
      'cancelled' || 'dropped' => SourceMangaStatus.cancelled,
      _ => SourceMangaStatus.unknown,
    };

SourceManga _nexEntry(FnSource s, Map m) {
  final avatar = m['avatar'];
  return SourceManga(
    url: '${s.baseUrl}/series/${m['slug']}',
    title: '${m['title']}',
    thumbnailUrl: avatar is Map ? '${s.baseUrl}${avatar['url']}' : null,
  );
}

Future<List<Map>> _nexAll(FnSource s) async {
  final j = await s.fetchJson(Uri.parse('${s.baseUrl}/api/local/series'), headers: const {'Accept': 'application/json'}) as Map;
  return (j['data'] as List).cast<Map>();
}

FnSource _nexcomic() => FnSource(
      id: 'en.nexcomic',
      name: 'NexComic',
      baseUrl: 'https://nexcomic.com',
      contentWarning: ContentWarning.mixed,
      popularFn: (s, page) async {
        if (page > 1) return const MangaPage([], hasNextPage: false);
        final all = await _nexAll(s);
        final pop = await s.fetchJson(Uri.parse('${s.baseUrl}/api/local/popular?limit=100&period=all'), headers: const {'Accept': 'application/json'}) as Map;
        final rank = {for (final e in (pop['data'] as List).cast<Map>().indexed) '${e.$2['slug']}': e.$1};
        all.sort((a, b) => (rank['${a['slug']}'] ?? 1 << 30).compareTo(rank['${b['slug']}'] ?? 1 << 30));
        return MangaPage([for (final m in all) _nexEntry(s, m)], hasNextPage: false);
      },
      latestFn: (s, page) async => page > 1 ? const MangaPage([], hasNextPage: false) : MangaPage([for (final m in await _nexAll(s)) _nexEntry(s, m)], hasNextPage: false),
      searchFn: (s, page, q) async {
        if (page > 1) return const MangaPage([], hasNextPage: false);
        final needle = q.toLowerCase();
        bool hit(Map m) => [m['title'], ...(m['alternativeTitles'] as List? ?? const [])].any((t) => '$t'.toLowerCase().contains(needle));
        return MangaPage([for (final m in await _nexAll(s)) if (hit(m)) _nexEntry(s, m)], hasNextPage: false);
      },
      detailsFn: (s, url) async {
        final slug = Uri.parse(url).pathSegments.where((e) => e.isNotEmpty).last;
        final body = await s.fetchText(Uri.parse('${s.baseUrl}/series/$slug.rsc'), headers: const {'RSC': '1'});
        final series = _arrayAfter(body, 'series', (f) => f.containsKey('slug') && f.containsKey('title'));
        final chapterRows = _arrayAfter(body, 'chapters', (f) => f.containsKey('seriesSlug'));
        if (series == null || chapterRows == null) throw StateError('catalog not found');
        final m = series.firstWhere((e) => e['slug'] == slug);
        String? joined(Object? l) => (l as List? ?? const []).join(', ');
        final alts = [for (final a in (m['alternativeTitles'] as List? ?? const [])) if ('$a' != '${m['title']}') '$a'];
        final chapters = <SourceChapter>[];
        for (final c in chapterRows) {
          if (c['seriesSlug'] != slug || c['locked'] == true) continue;
          final n = (c['chapterNumber'] as num).toDouble();
          final title = '${c['title'] ?? ''}'.trim();
          chapters.add(SourceChapter(
            url: '${s.baseUrl}/series/$slug/chapter/${'${c['id']}'.split(':').last}',
            name: 'Chapter ${n == n.roundToDouble() ? n.toInt() : n}${title.isEmpty ? '' : ' - $title'}',
            number: n,
            uploadedAt: c['publishedAt'] is num ? DateTime.fromMillisecondsSinceEpoch((c['publishedAt'] as num).toInt()) : null,
          ));
        }
        chapters.sort((a, b) => (b.number ?? 0).compareTo(a.number ?? 0));
        final avatar = m['avatar'];
        return SourceMangaDetails(
          url: url,
          title: '${m['title']}',
          thumbnailUrl: avatar is Map ? '${s.baseUrl}${avatar['url']}' : null,
          author: joined(m['authors']),
          artist: joined(m['artists']),
          genres: {if (m['type'] != null) '${m['type']}', ...(m['genres'] as List? ?? const []).map((e) => '$e'), ...(m['tags'] as List? ?? const []).map((e) => '$e')}.toList(),
          description: ['${m['description'] ?? ''}'.trim(), if (alts.isNotEmpty) 'Alternative Titles:\n${alts.join('\n')}'].where((e) => e.isNotEmpty).join('\n\n'),
          status: _nexStatus(m['status']),
          chapters: chapters,
        );
      },
      pagesFn: (s, ch) async {
        final body = await s.fetchText(Uri.parse('${ch.url}.rsc'), headers: const {'RSC': '1'});
        final pages = _arrayAfter(body, 'pages', (f) => f.containsKey('pageNumber'));
        if (pages == null) throw StateError('pages not found');
        pages.sort((a, b) => (a['pageNumber'] as num).compareTo(b['pageNumber'] as num));
        return [for (final p in pages) '${s.baseUrl}${p['url']}'];
      },
    );

List<MangaSource> portsZ() => [_sacachispa(), _nexcomic()];
