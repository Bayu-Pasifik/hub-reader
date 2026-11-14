// Uji langsung semua sumber katalog dari PC (jaringan nyata).
//   COMIC_LIVE=1 [COMIC_THEME=madara,mangathemesia] [COMIC_IDS=a,b] [COMIC_OUT=path] flutter test test/comic_live_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/sources/catalog.dart';

Future<T> _t<T>(Future<T> f) => f.timeout(const Duration(seconds: 30));

Future<Map<String, Object?>> _probe(CatalogEntry e) async {
  final r = <String, Object?>{'id': e.id, 'theme': e.theme, 'url': e.baseUrl};
  final s = e.create();
  if (s == null) return r..['stage'] = 'skip';
  var stage = 'popular';
  String? sample;
  try {
    final list = await _t(s.popular(1));
    if (list.items.isEmpty) return r..['stage'] = 'popular-empty';
    stage = 'details';
    sample = list.items.first.url;
    final d = await _t(s.details(list.items.first.url));
    if (d.chapters.isEmpty) return r..['stage'] = 'chapters-empty'..['sample'] = list.items.first.url;
    stage = 'pages';
    sample = d.chapters.first.url;
    final p = await _t(s.pages(d.chapters.first));
    if (p.isEmpty) return r..['stage'] = 'pages-empty'..['sample'] = d.chapters.first.url;
    return r..['stage'] = 'ok';
  } catch (err) {
    return r
      ..['stage'] = 'fail-$stage'
      ..['err'] = err.toString().split('\n').first
      ..['sample'] = sample;
  }
}

void main() {
  final live = Platform.environment['COMIC_LIVE'] == '1';
  test('live comic sources', () async {
    final raw = File('assets/sources/catalog.json').readAsStringSync();
    var entries = SourceCatalog.fromJsonString(raw).entries.toList();
    final themes = Platform.environment['COMIC_THEME']?.split(',');
    final ids = Platform.environment['COMIC_IDS']?.split(',');
    if (themes != null) entries = entries.where((e) => themes.contains(e.theme)).toList();
    if (ids != null) entries = entries.where((e) => ids.contains(e.id)).toList();
    final out = <Map<String, Object?>>[];
    var next = 0;
    Future<void> worker() async {
      while (next < entries.length) {
        final e = entries[next++];
        out.add(await _probe(e));
      }
    }

    await Future.wait([for (var i = 0; i < 10; i++) worker()]);
    out.sort((a, b) => '${a['id']}'.compareTo('${b['id']}'));
    File(Platform.environment['COMIC_OUT'] ?? '${Directory.systemTemp.path}/comic_live.json')
        .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(out));
  }, skip: live ? false : 'set COMIC_LIVE=1', timeout: const Timeout(Duration(minutes: 40)));
}
