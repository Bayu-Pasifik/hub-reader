import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/sources/catalog.dart';
import 'package:hub_reader/sources/catalog_repository.dart';
import 'package:hub_reader/sources/registry.dart';
import 'package:hub_reader/sources/source.dart';

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

Map<String, Object?> _entry(String id, String baseUrl) =>
    {'id': id, 'name': 'Situs $id', 'lang': 'id', 'baseUrl': baseUrl, 'theme': 'madara'};

String _catalog(List<Map<String, Object?>> entries) => jsonEncode({'sources': entries});

void main() {
  late Directory dir;
  late Map<String, String?> routes;
  late SourceCatalogRepository repo;
  const a = 'https://a.example/catalog.json';
  const b = 'https://b.example/catalog.json';
  final bundled = SourceCatalog.fromJsonString(_catalog([
    _entry('id.bawaan', 'https://bawaan.example'),
    _entry('id.pindah', 'https://lama.example'),
  ]));

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('catalog_repo_test');
    routes = {};
    final dio = Dio(BaseOptions(responseType: ResponseType.plain))..httpClientAdapter = _FakeAdapter(routes);
    repo = SourceCatalogRepository(dir, bundled: bundled, dio: dio);
  });

  tearDown(() => dir.delete(recursive: true));

  test('tanpa salinan repo: hanya katalog bawaan', () async {
    final load = await repo.cached([a]);
    expect(load.catalog.entries.map((e) => e.id), ['id.bawaan', 'id.pindah']);
    expect(load.savedAt, DateTime.fromMillisecondsSinceEpoch(0));
  });

  test('repo menimpa domain bawaan; host lama diingat untuk URL tersimpan', () async {
    routes[a] = _catalog([_entry('id.pindah', 'https://baru.example'), _entry('id.repo', 'https://repo.example')]);
    final load = await repo.fetch([a]);
    final byId = {for (final e in load.catalog.entries) e.id: e};
    expect(byId['id.pindah']!.baseUrl, 'https://baru.example');
    expect(byId['id.pindah']!.repo, a);
    expect(byId['id.bawaan']!.repo, isNull);
    expect(byId['id.repo'], isNotNull);
    expect(load.catalog.hostHistory['id.pindah'], containsAll(['lama.example', 'baru.example']));

    final source = builtInSources(catalog: load.catalog).whereType<HttpSource>().firstWhere((s) => s.id == 'id.pindah');
    source.previousHosts = load.catalog.hostHistory['id.pindah']!;
    expect(
      source.rewriteToCurrentHost(Uri.parse('https://lama.example/manga/x/')).toString(),
      'https://baru.example/manga/x/',
    );
  });

  test('sumber tetap ada (yatim) setelah dihapus dari repo', () async {
    routes[a] = _catalog([_entry('id.repo', 'https://repo.example'), _entry('id.lain', 'https://lain.example')]);
    await repo.fetch([a]);
    routes[a] = _catalog([_entry('id.lain', 'https://lain.example')]);
    final load = await repo.fetch([a]);
    final orphan = load.catalog.entries.firstWhere((e) => e.id == 'id.repo');
    expect(orphan.orphaned, isTrue);
    expect(orphan.create(), isNotNull);
    expect(load.catalog.orphans.length, 1);

    await repo.forgetOrphans([a]);
    final after = await repo.cached([a]);
    expect(after.catalog.entries.any((e) => e.id == 'id.repo'), isFalse);
  });

  test('repo yang mati memakai salinan terakhir; prioritas sesuai urutan', () async {
    routes[a] = _catalog([_entry('id.sama', 'https://dari-a.example')]);
    routes[b] = _catalog([_entry('id.sama', 'https://dari-b.example'), _entry('id.b', 'https://b.example')]);
    await repo.fetch([a, b]);

    routes[a] = null; // repo A di-takedown
    final load = await repo.fetch([a, b]);
    expect(load.error, isNotNull);
    expect(load.catalog.entries.firstWhere((e) => e.id == 'id.sama').baseUrl, 'https://dari-a.example');

    final swapped = await repo.fetch([b, a]);
    expect(swapped.catalog.entries.firstWhere((e) => e.id == 'id.sama').baseUrl, 'https://dari-b.example');
  });

  test('semua repo gagal tanpa salinan: error', () async {
    expect(() => repo.fetch([a]), throwsA(anything));
  });

  test('signature berubah hanya bila isi berubah', () async {
    routes[a] = _catalog([_entry('id.repo', 'https://repo.example')]);
    final one = (await repo.fetch([a])).catalog.signature;
    final two = (await repo.fetch([a])).catalog.signature;
    expect(one, two);
    routes[a] = _catalog([_entry('id.repo', 'https://repo2.example')]);
    expect((await repo.fetch([a])).catalog.signature, isNot(one));
  });

  test('signature membedakan asal entri walau isinya sama dengan bawaan', () async {
    final local = (await repo.cached([a])).catalog;
    routes[a] = _catalog([_entry('id.bawaan', 'https://bawaan.example'), _entry('id.pindah', 'https://lama.example')]);
    final fetched = (await repo.fetch([a])).catalog;
    expect(fetched.signature, isNot(local.signature));
    expect(fetched.entries.every((e) => e.repo == a), isTrue);
  });
}
