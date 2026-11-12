// ignore_for_file: avoid_print
// Uji langsung plugin LNReader asli lewat engine QuickJS (butuh internet).
// Dilewati kecuali LNR_LIVE=1. Pilih plugin: LNR_IDS=id1,id2 (default: beberapa
// plugin Indonesia & English).
//   LNR_LIVE=1 flutter test test/lnreader_live_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/novels/lnreader/engine_isolate.dart';
import 'package:hub_reader/novels/lnreader/http_bridge.dart';
import 'package:hub_reader/novels/lnreader/js_engine.dart';

const _manifestUrl =
    'https://raw.githubusercontent.com/lnreader/lnreader-plugins/plugins/v3.0.0/.dist/plugins.min.json';

void main() {
  final live = Platform.environment['LNR_LIVE'] == '1';
  final ids = (Platform.environment['LNR_IDS'] ?? 'IDWN.id,meionovel,novelringan.com,wbnovel,novelfire,royalroad')
      .split(',');

  test('plugin asli: popular -> novel -> chapter', () async {
    if (!live) return markTestSkipped('set LNR_LIVE=1');
    final dio = Dio();
    final manifest = (jsonDecode((await dio.get<String>(_manifestUrl)).data!) as List).cast<Map>();
    final engine = await LnEngine.spawn(
      runtimeCode: File('assets/lnreader/runtime.js').readAsStringSync(),
      fetcher: LnFetcher(userAgent: () => 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36'),
      store: MemoryKeyValueStore(),
    );
    addTearDown(engine.dispose);
    var ok = 0;
    for (final id in ids) {
      final item = manifest.firstWhere((p) => p['id'] == id, orElse: () => {});
      if (item.isEmpty) {
        print('?? $id tidak ada di manifest');
        continue;
      }
      final sw = Stopwatch()..start();
      var stage = 'load';
      try {
        final code = (await dio.get<String>(item['url'] as String)).data!;
        final meta = await engine.load(id, code);
        final filters = meta['filters'] as Map?;
        stage = 'popular';
        final list = await engine.invoke(id, 'popularNovels', [
          1,
          {
            'showLatestNovels': false,
            'filters': filters?.map((k, v) => MapEntry(k, {'type': (v as Map)['type'], 'value': v['value']})),
          },
        ]) as List;
        final tPopular = sw.elapsedMilliseconds;
        stage = 'novel';
        final path = (list.first as Map)['path'];
        final novel = await engine.invoke(id, 'parseNovel', [path]) as Map;
        var chapters = (novel['chapters'] as List?) ?? const [];
        if (chapters.isEmpty && meta['hasParsePage'] == true) {
          stage = 'page';
          chapters = ((await engine.invoke(id, 'parsePage', [path, '1']) as Map)['chapters'] as List?) ?? const [];
        }
        final tNovel = sw.elapsedMilliseconds;
        stage = 'chapter';
        final html = await engine.invoke(id, 'parseChapter', [(chapters.first as Map)['path']]) as String;
        ok++;
        print('OK   $id: ${list.length} novel, ${chapters.length} bab, ${html.length} char '
            '(popular ${tPopular}ms, novel ${tNovel - tPopular}ms, bab ${sw.elapsedMilliseconds - tNovel}ms)');
      } catch (e) {
        print('FAIL $id [$stage]: $e');
      }
    }
    expect(ok, greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 10)));
}
