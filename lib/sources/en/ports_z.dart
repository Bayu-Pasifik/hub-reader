// Situs katalog (bagian Z: Sacachispa), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0). Bab khusus Patreon disembunyikan;
// filter genre/katalog komisi belum ada.

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

List<MangaSource> portsZ() => [_sacachispa()];
