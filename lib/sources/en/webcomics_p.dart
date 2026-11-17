// Situs katalog (bagian P), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0): baetoon.

import '../html_utils.dart';
import '../models.dart';
import '../next_rsc.dart';
import '../source.dart';
import 'fn_source.dart';

const _placeholder = {'Korean Creator', 'Korean Studio'};
const _rsc = {'RSC': '1'};

Uri _bUri(HttpSource s, String path) => Uri.parse('${s.baseUrl}$path').replace(queryParameters: {'_rsc': ''});

SourceManga _bManga(Map t) =>
    SourceManga(url: '${t['id']}', title: '${t['title']}', thumbnailUrl: t['coverNormal'] as String?);

Future<MangaPage> _bSearch(HttpSource s, int page, String sort, [String? text]) async {
  final d = await s.fetchJson(Uri.parse('${s.baseUrl}/api/titles/search').replace(queryParameters: {
    'sort': sort,
    if (text != null) 'text': text,
    'page': '$page',
    'limit': '24',
  })) as Map;
  final p = d['pagination'] as Map?;
  final cur = (p?['page'] as num?)?.toInt() ?? page;
  final total = (p?['totalPages'] as num?)?.toInt() ?? page;
  return MangaPage([for (final t in (d['data'] as List).cast<Map>()) _bManga(t)], hasNextPage: cur < total);
}

String? _creator(Object? v) {
  final t = '${v ?? ''}'.trim();
  return t.isEmpty || _placeholder.contains(t) ? null : t;
}

List<MangaSource> webcomicsP() => [
      FnSource(
        id: 'en.baetoon',
        name: 'Baetoon',
        baseUrl: 'https://baetoon.com',
        popularFn: (s, page) => _bSearch(s, page, 'most-view'),
        latestFn: (s, page) => _bSearch(s, page, 'lastest-updates'),
        searchFn: (s, page, q) => _bSearch(s, page, 'most-view', q),
        detailsFn: (s, id) async {
          final body = await s.fetchText(_bUri(s, '/title-detail/$id'), headers: _rsc);
          final d = findRscObject(body, (o) => o['chapters'] is List && o['title'] != null && o['id'] == id);
          if (d == null) throw Exception('Title not found');
          final title = '${d['title']}';
          final released = '${d['released'] ?? ''}';
          final alt = [for (final a in (d['alternativeNames'] as List? ?? const [])) '$a'].where((e) => e != title).toList();
          final desc = [
            [
              if (RegExp(r'^\d{4}$').hasMatch(released)) released,
              if (d['officialTranslation'] == true) 'Official translation',
              if (d['animeAdaptation'] == true) 'Anime adaptation',
            ].join(' · '),
            '${d['description'] ?? ''}',
            if (alt.isNotEmpty) 'Alternative titles: ${alt.join(' · ')}',
          ].where((e) => e.trim().isNotEmpty).toList();
          final genres = <String>{
            if (d['type'] != null) '${d['type']}',
            for (final t in (d['tags'] as List? ?? const [])) '$t',
            for (final t in (d['keywords'] as List? ?? const [])) '$t',
          }.toList();
          final chapters = <SourceChapter>[];
          for (final c in (d['chapters'] as List).cast<Map>()) {
            final uploads = (c['sources'] as List? ?? const []).cast<Map>();
            if (uploads.isEmpty) continue;
            final u = uploads.first;
            chapters.add(SourceChapter(
              url: '${u['id']}',
              name: '${c['title']}',
              number: double.tryParse('${c['number']}'),
              uploadedAt: DateTime.tryParse('${u['datetime']}'),
              scanlator: u['sourceName'] as String?,
            ));
          }
          return SourceMangaDetails(
            url: id,
            title: title,
            thumbnailUrl: d['coverNormal'] as String?,
            author: _creator(d['author']),
            artist: _creator(d['artist']),
            genres: genres,
            description: desc.isEmpty ? null : desc.join('\n\n'),
            status: parseStatus('${d['status']}'),
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final body = await s.fetchText(_bUri(s, '/chapter-detail/${ch.url}'), headers: _rsc);
          final d = findRscObject(body, (o) => o['pages'] is List && o['seriesId'] != null);
          return [for (final p in (d?['pages'] as List? ?? const [])) '$p'];
        },
      ),
    ];
