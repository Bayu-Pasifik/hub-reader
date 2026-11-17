// Situs katalog (bagian O), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0): readcomicsonlinelol.

import 'dart:convert';

import '../models.dart';
import '../next_rsc.dart';
import '../source.dart';
import 'fn_source.dart';

const _rsc = {'RSC': '1'};

Uri _rscUri(HttpSource s, String path) => Uri.parse('${s.baseUrl}$path').replace(queryParameters: {'_rsc': ''});

// Katalog lengkap, terpopuler dulu (sama seperti situsnya).
Future<List<Map>> _rcoCatalogue(HttpSource s) async {
  final body = await s.fetchText(_rscUri(s, '/comics'), headers: _rsc);
  final obj = findRscObject(body, (o) => o['comics'] is List && (o['comics'] as List).isNotEmpty && (o['comics'] as List).first is Map && (o['comics'] as List).first['slug'] != null);
  return [for (final c in (obj?['comics'] as List? ?? const [])) c as Map];
}

SourceManga _rcoManga(Map c) =>
    SourceManga(url: '/comic/${c['slug']}', title: '${c['title']}', thumbnailUrl: c['cover'] as String?);

String _searchable(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

SourceMangaStatus _rcoStatus(String? raw) {
  switch ((raw ?? '').toLowerCase()) {
    case 'ongoing':
      return SourceMangaStatus.ongoing;
    case 'completed':
      return SourceMangaStatus.completed;
  }
  return SourceMangaStatus.unknown;
}

List<MangaSource> webcomicsO() => [
      FnSource(
        id: 'en.readcomicsonlinelol',
        name: 'ReadComicsOnline.lol',
        baseUrl: 'https://readcomicsonline.lol',
        popularFn: (s, page) async => MangaPage([for (final c in await _rcoCatalogue(s)) _rcoManga(c)], hasNextPage: false),
        latestFn: (s, page) async {
          const limit = 20;
          final d = await s.fetchJson(Uri.parse('${s.baseUrl}/api/comics/browse').replace(queryParameters: {
            'tab': 'latest',
            'offset': '${(page - 1) * limit}',
            'limit': '$limit',
          })) as Map;
          return MangaPage([for (final c in (d['comics'] as List).cast<Map>()) _rcoManga(c)], hasNextPage: d['hasMore'] == true);
        },
        searchFn: (s, page, q) async {
          final n = _searchable(q);
          return MangaPage([
            for (final c in await _rcoCatalogue(s))
              if (_searchable('${c['title']}').contains(n)) _rcoManga(c),
          ], hasNextPage: false);
        },
        detailsFn: (s, url) async {
          final status = (await _rcoCatalogue(s)).where((c) => '/comic/${c['slug']}' == url).firstOrNull;
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}$url'));
          Map? series;
          for (final sc in res.document.querySelectorAll('script[type="application/ld+json"]')) {
            if (sc.text.contains('"ComicSeries"')) {
              series = jsonDecode(sc.text) as Map;
              break;
            }
          }
          final body = await s.fetchText(_rscUri(s, url), headers: _rsc);
          final issuesObj = findRscObject(body, (o) => o['issues'] is List);
          final issues = (issuesObj?['issues'] as List? ?? const []).cast<Map>();
          final publisher = (series?['publisher'] as Map?)?['name'];
          final desc = [
            if ('${series?['description'] ?? ''}'.isNotEmpty) '${series!['description']}',
            if (publisher != null) 'Publisher: $publisher',
          ];
          return SourceMangaDetails(
            url: url,
            title: '${series?['name'] ?? status?['title'] ?? url.split('/').last}',
            thumbnailUrl: series?['image'] as String?,
            author: (series?['author'] as Map?)?['name'] as String?,
            artist: (series?['illustrator'] as Map?)?['name'] as String?,
            genres: [for (final g in (series?['genre'] as List? ?? const [])) '$g'],
            description: desc.isEmpty ? null : desc.join('\n\n'),
            status: _rcoStatus(status?['status'] as String?),
            chapters: [
              for (final i in issues)
                SourceChapter(
                  url: '$url/${i['slug']}',
                  name: '${i['title']}',
                  number: double.tryParse('${i['slug']}'),
                  uploadedAt: DateTime.tryParse('${i['releaseDate']}'),
                ),
            ],
          );
        },
        pagesFn: (s, ch) async {
          final body = await s.fetchText(_rscUri(s, ch.url), headers: _rsc);
          final obj = findRscObject(body, (o) => o['pages'] is List);
          return [for (final p in (obj?['pages'] as List? ?? const []).cast<Map>()) '${p['url']}'];
        },
      ),
    ];
