// Situs katalog (bagian V: Pornhwa18 berbasis Qwik City), port Dart dari
// extension keiyoushi/extensions-source (Apache-2.0).

import 'dart:convert';

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import 'fn_source.dart';

const _undefined = '\u0001';

/// Data loader Qwik City: tiap nilai objek/larik adalah indeks basis-36 ke `_objs`.
Object? _qwik(String body) {
  final root = jsonDecode(body) as Map;
  final objs = root['_objs'] as List;
  Object? resolve(Object? ref) {
    final value = objs[int.parse('$ref', radix: 36)];
    if (value is Map) return {for (final e in value.entries) e.key: resolve(e.value)};
    if (value is List) return [for (final e in value) resolve(e)];
    if (value is String) {
      if (value == _undefined) return null;
      if (value.isNotEmpty && value.codeUnitAt(0) < 32) return value.substring(1);
    }
    return value;
  }

  final entry = resolve(root['_entry']) as Map;
  final loaders = (entry['loaders'] as Map).values;
  return loaders.firstWhere((e) => e != null, orElse: () => null);
}

Future<Object?> _qwikGet(FnSource s, String url) async => _qwik(await s.fetchText(Uri.parse(url), headers: const {'Accept': 'application/json'}));

const _pageSize = 18;

Future<MangaPage> _p18List(FnSource s, String path, int page) async {
  final url = '${s.baseUrl}$path/q-data.json${page > 1 ? '?page=$page' : ''}';
  final all = (await _qwikGet(s, url) as List).cast<Map>();
  final slice = all.skip((page - 1) * _pageSize).where((e) => '${e['slug'] ?? ''}'.isNotEmpty);
  return MangaPage([
    for (final e in slice)
      SourceManga(
        url: '${s.baseUrl}/comic/${e['slug']}/',
        title: clean('${e['title']}'),
        thumbnailUrl: (e['poster'] as String?)?.replaceFirst('/188.165.221.196/', '/manhwa18.com/'),
      ),
  ], hasNextPage: all.length >= page * _pageSize);
}

String _num(num n) => n == n.roundToDouble() ? '${n.toInt()}' : '$n';

FnSource _pornhwa18() => FnSource(
      id: 'en.pornhwa18',
      name: 'Pornhwa18',
      baseUrl: 'https://pornhwa18.com',
      contentWarning: ContentWarning.nsfw,
      popularFn: (s, page) => _p18List(s, '/popular', page),
      latestFn: (s, page) => _p18List(s, '', page),
      searchFn: (s, page, q) => _p18List(s, '/search/${Uri.encodeComponent(q.trim())}', page),
      detailsFn: (s, url) async {
        final slug = Uri.parse(url).pathSegments.where((e) => e.isNotEmpty).last;
        final d = await _qwikGet(s, '${s.baseUrl}/comic/$slug/q-data.json') as Map;
        final tax = [for (final t in (d['taxonomy_relation'] as List? ?? const []).cast<Map>()) t['taxonomy'] as Map];
        String names(String type) => tax.where((t) => t['type'] == type).map((t) => '${t['name']}').join(', ');
        final synopsis = clean('${d['synopsis'] ?? ''}');
        final alter = clean('${d['alter'] ?? ''}');
        final chapters = <SourceChapter>[];
        for (final c in (d['chapters'] as List? ?? const []).cast<Map>()) {
          final n = _num(c['chapter'] as num);
          chapters.add(SourceChapter(
            url: '${s.baseUrl}/comic/$slug/chapter-$n/',
            name: 'Chapter $n',
            number: (c['chapter'] as num).toDouble(),
            uploadedAt: DateTime.tryParse('${c['created_at'] ?? ''}'),
          ));
        }
        return SourceMangaDetails(
          url: url,
          title: clean('${d['title']}'),
          thumbnailUrl: (d['poster'] as String?)?.replaceFirst('/188.165.221.196/', '/manhwa18.com/'),
          author: names('author'),
          artist: names('artist'),
          description: [if (synopsis.isNotEmpty) synopsis, if (alter.isNotEmpty) 'Alternative titles: $alter'].join('\n\n'),
          genres: [if (d['type'] != null) '${d['type']}', ...tax.where((t) => t['type'] == 'genre').map((t) => '${t['name']}')],
          status: switch (d['status']) {
            'on-going' => SourceMangaStatus.ongoing,
            'end' => SourceMangaStatus.completed,
            'on-hold' => SourceMangaStatus.hiatus,
            _ => SourceMangaStatus.unknown,
          },
          chapters: chapters,
        );
      },
      pagesFn: (s, ch) async {
        final base = ch.url.endsWith('/') ? ch.url : '${ch.url}/';
        final r = await _qwikGet(s, '${base}q-data.json') as Map;
        final chapters = ((r['data'] as Map)['chapters'] as List).cast<Map>();
        final images = (chapters.first['images'] as Map).entries.toList()..sort((a, b) => int.parse('${a.key}').compareTo(int.parse('${b.key}')));
        return [for (final e in images) '${(e.value as Map)['src']}'];
      },
    );

List<MangaSource> portsV() => [_pornhwa18()];
