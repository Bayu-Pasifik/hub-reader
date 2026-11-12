// Tes engine QuickJS untuk plugin LNReader.
//
// Butuh library native QuickJS milik flutter_js di host:
//   Windows: folder berisi quickjs_c_bridge.dll ada di PATH
//   Linux:   LIBQUICKJSC_TEST_PATH=<pub-cache>/flutter_js-x/linux/shared/libquickjs_c_bridge_plugin.so
// Tanpa itu tes dilewati (lihat .github/workflows/android.yml).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/novels/lnreader/engine_isolate.dart';
import 'package:hub_reader/novels/lnreader/http_bridge.dart';
import 'package:hub_reader/novels/lnreader/js_engine.dart';

/// Plugin mini bergaya hasil compile lnreader-plugins (CommonJS, ES5).
const _plugin = r'''
var cheerio = require("cheerio");
var fetch_1 = require("@libs/fetch");
var storage_1 = require("@libs/storage");
var novelStatus_1 = require("@libs/novelStatus");
var filterInputs_1 = require("@libs/filterInputs");
var dayjs = require("dayjs");
var Plugin = (function () {
  function Plugin() {
    this.id = "fake";
    this.name = "Fake";
    this.version = "1.0.0";
    this.icon = "src/en/fake/icon.png";
    this.site = SITE;
    this.filters = { sort: { label: "Sort", value: "pop", type: filterInputs_1.FilterTypes.Picker,
      options: [{ label: "Popular", value: "pop" }] } };
  }
  Plugin.prototype.popularNovels = function (page, options) {
    var self = this;
    return fetch_1.fetchApi(this.site + "list?page=" + page + "&sort=" + options.filters.sort.value)
      .then(function (r) { return r.text(); })
      .then(function (html) {
        var $ = cheerio.load(html);
        return $(".novel a").map(function (i, el) {
          return { name: $(el).text().trim(), path: $(el).attr("href"), cover: self.site + "c.jpg" };
        }).get();
      });
  };
  Plugin.prototype.parseNovel = function (path) {
    var self = this;
    return fetch_1.fetchApi(new URL(path, this.site).href).then(function (r) { return r.json(); })
      .then(function (j) {
        storage_1.storage.set("last", path);
        return { path: path, name: j.title, status: novelStatus_1.NovelStatus.Ongoing,
          chapters: j.chapters.map(function (c, i) {
            return { name: c, path: path + "/" + (i + 1), releaseTime: dayjs("2024-01-0" + (i + 1)).format("YYYY-MM-DD") };
          }) };
      });
  };
  Plugin.prototype.parseChapter = function (path) {
    var form = new FormData();
    form.append("p", path);
    return new Promise(function (res) { setTimeout(res, 10); })
      .then(function () { return fetch_1.fetchApi(SITE + "chapter", { method: "POST", body: form }); })
      .then(function (r) { return r.text(); })
      .then(function (t) { return "<p>" + t + "</p><p>" + storage_1.storage.get("last") + "</p>"; });
  };
  Plugin.prototype.searchNovels = function () { return Promise.reject(new Error("no search")); };
  return Plugin;
}());
exports.default = new Plugin();
''';

void main() {
  late HttpServer server;
  late String site;
  LnEngine? engine;
  final store = MemoryKeyValueStore();
  String? skip;

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    site = 'http://127.0.0.1:${server.port}/';
    server.listen((req) async {
      final res = req.response;
      switch (req.uri.path) {
        case '/list':
          res.headers.contentType = ContentType.html;
          res.write('<div class="novel"><a href="/n/1"> One (${req.uri.queryParameters['sort']}) </a></div>'
              '<div class="novel"><a href="/n/2">Two</a></div>');
        case '/n/1':
          res.headers.contentType = ContentType.json;
          res.write(jsonEncode({'title': 'Novel Satu', 'chapters': ['Bab 1', 'Bab 2']}));
        case '/chapter':
          final body = await utf8.decodeStream(req);
          res.write(body.contains('name="p"') && body.contains('/n/1/2') ? 'isi bab ✓' : 'bad form');
        default:
          res.statusCode = 404;
      }
      await res.close();
    });
    try {
      final runtime = File('assets/lnreader/runtime.js').readAsStringSync();
      // Cek library native dulu di isolate ini (pesan error lebih jelas).
      LnJsEngine(runtimeCode: runtime, fetch: (_) => throw UnimplementedError()).dispose();
      engine = await LnEngine.spawn(
        runtimeCode: runtime,
        fetcher: LnFetcher(userAgent: () => 'test'),
        store: store,
      );
    } on ArgumentError catch (e) {
      skip = 'QuickJS native library tidak tersedia: $e';
    }
  });

  tearDownAll(() async {
    engine?.dispose();
    await server.close(force: true);
  });

  test('menjalankan plugin: list, detail, bab, filter, storage, FormData, timer', () async {
    if (skip != null) return markTestSkipped(skip!);
    final e = engine!;
    final meta = await e.load('fake', 'var SITE = "$site";\n$_plugin');
    expect(meta['name'], 'Fake');
    expect(meta['hasParsePage'], false);

    final list = await e.invoke('fake', 'popularNovels', [
      1,
      {'showLatestNovels': false, 'filters': {'sort': {'type': 'Picker', 'value': 'pop'}}},
    ]) as List;
    expect(list, hasLength(2));
    expect((list.first as Map)['name'], 'One (pop)');

    final novel = await e.invoke('fake', 'parseNovel', ['/n/1']) as Map;
    expect(novel['name'], 'Novel Satu');
    expect(novel['status'], 'Ongoing');
    final chapters = novel['chapters'] as List;
    expect((chapters[1] as Map)['releaseTime'], '2024-01-02');

    final html = await e.invoke('fake', 'parseChapter', ['/n/1/2']) as String;
    expect(html, '<p>isi bab ✓</p><p>/n/1</p>');
    // storage.set dari isolate engine tersimpan di store isolate utama.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(store.keys(), contains('fake_DB_last'));
  });

  test('TextEncoder/TextDecoder/atob tidak rekursif (regresi crash QuickJS)', () async {
    if (skip != null) return markTestSkipped(skip!);
    final e = engine!;
    await e.load('codec', r'''
exports.default = {
  id: 'codec', name: 'Codec', version: '1.0.0', site: 'x', icon: '',
  popularNovels: function () {
    var s = 'Tiếng Việt 😀';
    var bytes = new TextEncoder().encode(s);
    var back = new TextDecoder('utf-8').decode(bytes);
    var b64 = Uint8Array.from(atob(btoa('abc')), function (c) { return c.charCodeAt(0); });
    return Promise.resolve([{ name: back + '|' + bytes.length + '|' + new TextDecoder().decode(b64), path: '/' }]);
  },
  parseNovel: function () {}, parseChapter: function () {}, searchNovels: function () {},
};
''');
    final list = await e.invoke('codec', 'popularNovels', [1, {}]) as List;
    expect((list.single as Map)['name'], 'Tiếng Việt 😀|19|abc');
  });

  test('error dari plugin diteruskan sebagai LnPluginException', () async {
    if (skip != null) return markTestSkipped(skip!);
    await expectLater(
      engine!.invoke('fake', 'searchNovels', ['x', 1]),
      throwsA(isA<LnPluginException>().having((x) => x.message, 'message', contains('no search'))),
    );
  });
}
