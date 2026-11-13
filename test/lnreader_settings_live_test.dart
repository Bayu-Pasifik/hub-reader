// ignore_for_file: avoid_print
// Uji langsung pengaturan plugin (pluginSettings) WTR-LAB lewat engine QuickJS
// (butuh internet). Dilewati kecuali LNR_LIVE=1.
//   LNR_LIVE=1 flutter test test/lnreader_settings_live_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/novels/lnreader/engine_isolate.dart';
import 'package:hub_reader/novels/lnreader/http_bridge.dart';
import 'package:hub_reader/novels/lnreader/js_engine.dart';
import 'package:hub_reader/novels/novel_models.dart';
import 'package:hub_reader/novels/novel_source.dart';

const _manifestUrl =
    'https://raw.githubusercontent.com/lnreader/lnreader-plugins/plugins/v3.0.0/.dist/plugins.min.json';

void main() {
  final live = Platform.environment['LNR_LIVE'] == '1';

  test('WTR-LAB: pengaturan plugin dipakai saat membaca bab', () async {
    if (!live) return markTestSkipped('set LNR_LIVE=1');
    final dio = Dio();
    final manifest = (jsonDecode((await dio.get<String>(_manifestUrl)).data!) as List).cast<Map>();
    final info = NovelPluginInfo.tryParse(manifest.firstWhere((p) => p['id'] == 'WTRLAB').cast<String, dynamic>())!;
    final store = MemoryKeyValueStore();
    final engine = await LnEngine.spawn(
      runtimeCode: File('assets/lnreader/runtime.js').readAsStringSync(),
      fetcher: LnFetcher(userAgent: () => 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36'),
      store: store,
    );
    addTearDown(engine.dispose);
    final meta = await engine.load(info.id, (await dio.get<String>(info.url)).data!);
    final source = NovelSource(info: info, engine: engine, meta: meta);
    print('settings: ${source.settings.map((s) => '${s.key}:${s.type.name}=${source.settingValue(s)}').join(', ')}');
    expect(source.settings.map((s) => s.key), containsAll(['signInUrl', 'preferredMode', 'showModeNotice']));

    final novel = (await source.popular(1)).first;
    final details = await source.details(novel.path);
    final chapterPath = details.chapters.first.path;

    final mode = source.settings.firstWhere((s) => s.key == 'preferredMode');
    final notice = source.settings.firstWhere((s) => s.key == 'showModeNotice');
    for (final value in ['ai', 'web']) {
      source.setSetting(mode, value);
      source.setSetting(notice, true);
      expect(source.settingValue(mode), value);
      final html = await source.chapter(chapterPath);
      final text = html.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      print('mode=$value: ${html.length} char | ${text.substring(0, text.length.clamp(0, 220))}');
      expect(html.length, greaterThan(500));
    }
    source.setSetting(notice, false);
    final plain = await source.chapter(chapterPath);
    print('notice off: ${plain.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim().substring(0, 160)}');
    expect(store.keys(), contains('WTRLAB_DB_preferredMode'));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
