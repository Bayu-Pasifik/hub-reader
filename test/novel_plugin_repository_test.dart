import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/novels/plugin_repository.dart';

/// Server palsu: URL → isi (null = 404).
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.routes);

  final Map<String, String?> routes;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final body = routes[options.uri.toString()];
    if (body == null) return ResponseBody.fromString('not found', 404);
    return ResponseBody.fromString(body, 200);
  }

  @override
  void close({bool force = false}) {}
}

String _manifest(List<(String id, String url)> plugins) => jsonEncode([
      for (final (id, url) in plugins)
        {'id': id, 'name': 'Plugin $id', 'site': 'https://$id.example', 'lang': 'English', 'version': '1.0.0', 'url': url},
    ]);

void main() {
  late Directory dir;
  late Map<String, String?> routes;
  late NovelPluginRepository repo;
  const a = 'https://a.example/plugins.min.json';
  const b = 'https://b.example/dist/plugins.min.json';

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lnr_repo_test');
    routes = {};
    final dio = Dio(BaseOptions(responseType: ResponseType.plain))..httpClientAdapter = _FakeAdapter(routes);
    repo = NovelPluginRepository(dir, dio: dio);
  });

  tearDown(() => dir.delete(recursive: true));

  test('plugin tetap ada (yatim) setelah dihapus dari manifest', () async {
    routes[a] = _manifest([('one', 'https://a.example/one.js'), ('two', 'https://a.example/two.js')]);
    routes['https://a.example/one.js'] = 'var one = 1;';
    final first = await repo.fetchManifest([a]);
    await repo.code(first.plugins.firstWhere((p) => p.id == 'one'));

    // Pemilik repo menghapus plugin "one".
    routes[a] = _manifest([('two', 'https://a.example/two.js')]);
    routes.remove('https://a.example/one.js');
    final after = await repo.fetchManifest([a]);

    final one = after.plugins.firstWhere((p) => p.id == 'one');
    expect(one.orphaned, isTrue);
    expect(one.name, 'Plugin one');
    expect(one.lang, 'en');
    expect(await repo.code(one), 'var one = 1;');
    expect(after.plugins.where((p) => p.id == 'two').single.orphaned, isFalse);
  });

  test('repo 404: memakai manifest tersimpan, error dilaporkan', () async {
    routes[a] = _manifest([('one', 'https://a.example/one.js')]);
    routes[b] = _manifest([('three', 'three.js')]);
    await repo.fetchManifest([a, b]);

    routes[a] = null;
    final after = await repo.fetchManifest([a, b]);
    expect(after.error, isNotNull);
    expect(after.plugins.map((p) => p.id), containsAll(['one', 'three']));
  });

  test('semua repo gagal tanpa cache: melempar', () async {
    expect(repo.fetchManifest([a]), throwsA(anything));
  });

  test('url relatif diselesaikan terhadap repo; repo atas menang', () async {
    routes[a] = _manifest([('dup', 'https://a.example/dup.js')]);
    routes[b] = _manifest([('dup', 'dup.js'), ('three', 'js/three.js')]);
    final cat = await repo.fetchManifest([b, a]);
    expect(cat.plugins.firstWhere((p) => p.id == 'dup').url, 'https://b.example/dist/dup.js');
    expect(cat.plugins.firstWhere((p) => p.id == 'three').url, 'https://b.example/dist/js/three.js');
    expect(cat.plugins.firstWhere((p) => p.id == 'three').repo, b);
  });

  test('cache offline + plugin lama tanpa info.json tetap muncul', () async {
    routes[a] = _manifest([('two', 'https://a.example/two.js')]);
    await repo.fetchManifest([a]);
    // Plugin lama (sebelum info disimpan) yang sudah dihapus dari repo.
    await Directory('${dir.path}/plugins').create(recursive: true);
    await File('${dir.path}/plugins/old.js').writeAsString('var old;');
    await File('${dir.path}/plugins/old.version').writeAsString('2.0.0');

    final cached = await repo.cachedManifest([a]);
    final old = cached!.plugins.firstWhere((p) => p.id == 'old');
    expect(old.orphaned, isTrue);
    expect(old.version, '2.0.0');
    expect(await repo.code(old), 'var old;');
  });

  test('plugin lama tanpa info.json: info diambil dari manifest tersimpan repo yang dihapus', () async {
    routes[a] = _manifest([('legacy', 'https://a.example/legacy.js')]);
    await repo.fetchManifest([a]);
    await Directory('${dir.path}/plugins').create(recursive: true);
    await File('${dir.path}/plugins/legacy.js').writeAsString('var legacy;');
    await File('${dir.path}/plugins/legacy.version').writeAsString('1.0.0');

    // Repo dihapus dari daftar sebelum sempat refresh.
    final cat = await repo.fetchManifest(const []);
    final legacy = cat.plugins.single;
    expect(legacy.orphaned, isTrue);
    expect(legacy.name, 'Plugin legacy');
    expect(legacy.lang, 'en');
    expect(File('${dir.path}/plugins/legacy.json').existsSync(), isTrue);
  });

  test('export → import ke perangkat lain: plugin jalan tanpa repo', () async {
    routes[a] = _manifest([('one', 'https://a.example/one.js')]);
    routes['https://a.example/one.js'] = 'var one = 1;';
    final cat = await repo.fetchManifest([a]);
    await repo.code(cat.plugins.single);
    final exported = jsonDecode(jsonEncode(await repo.exportInstalled()));
    expect((exported as List).length, 1);

    final otherDir = await Directory.systemTemp.createTemp('lnr_repo_other');
    addTearDown(() => otherDir.delete(recursive: true));
    final other = NovelPluginRepository(
      otherDir,
      dio: Dio()..httpClientAdapter = _FakeAdapter({}), // repo sudah hilang
    );
    expect(await other.importPlugins(exported), 1);
    expect(await other.importPlugins(exported), 0, reason: 'tidak menimpa yang sudah ada');

    final restored = (await other.fetchManifest(const [])).plugins.single;
    expect(restored.name, 'Plugin one');
    expect(restored.orphaned, isTrue);
    expect(await other.code(restored), 'var one = 1;');
  });

  test('tanpa repo: hanya plugin tersimpan', () async {
    final cat = await repo.fetchManifest(const []);
    expect(cat.plugins, isEmpty);
  });
}
