import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/core/platform/network_bridge.dart';
import 'package:hub_reader/data/local/download_store.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/state/app_settings_provider.dart';
import 'package:hub_reader/state/core_providers.dart';
import 'package:hub_reader/state/download_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tmp;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tmp = await Directory.systemTemp.createTemp('download_settings');
  });

  tearDown(() async {
    NetworkBridge.debugOverride = null;
    await tmp.delete(recursive: true);
  });

  ProviderContainer container(DownloadStore store) => ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        downloadStoreProvider.overrideWithValue(store),
      ]);

  const manga = SourceMangaDetails(url: 'm', title: 'M');
  const chapter = SourceChapter(url: 'm/1', name: 'Ch 1');

  test('wifi-only keeps the queue waiting on mobile data, then runs on Wi-Fi', () async {
    var wifi = false;
    NetworkBridge.debugOverride = () async => wifi;
    final c = container(DownloadStore(Directory('${tmp.path}/dl'), prefs));
    addTearDown(c.dispose);
    await c.read(appSettingsProvider.notifier).update((s) => s.copyWith(downloadWifiOnly: true));

    c.read(downloadQueueProvider.notifier).enqueue(sourceId: 's', mangaUrl: 'm', manga: manga, chapters: [chapter]);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(c.read(downloadWaitingForWifiProvider), isTrue);
    expect(c.read(downloadQueueProvider).single.status.name, 'queued');

    // Tersambung Wi-Fi: dijalankan (gagal cepat karena sumber 's' tidak ada, tapi tidak lagi menunggu).
    wifi = true;
    c.read(downloadQueueProvider.notifier).retry(c.read(downloadQueueProvider).single.key);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(c.read(downloadWaitingForWifiProvider), isFalse);
    expect(c.read(downloadQueueProvider).single.status.name, 'failed');
  });

  test('without wifi-only the network state is not consulted', () async {
    NetworkBridge.debugOverride = () async => throw StateError('tidak boleh dipanggil');
    final c = container(DownloadStore(Directory('${tmp.path}/dl'), prefs));
    addTearDown(c.dispose);
    c.read(downloadQueueProvider.notifier).enqueue(sourceId: 's', mangaUrl: 'm', manga: manga, chapters: [chapter]);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(c.read(downloadWaitingForWifiProvider), isFalse);
  });

  test('settings round trip and parallel is clamped', () async {
    final c = container(DownloadStore(Directory('${tmp.path}/dl'), prefs));
    addTearDown(c.dispose);
    await c.read(appSettingsProvider.notifier).update((s) => s.copyWith(downloadWifiOnly: true, downloadParallel: 4));
    expect(prefs.getBool('app.download_wifi_only.v1'), isTrue);
    expect(prefs.getInt('app.download_parallel.v1'), 4);
    await prefs.setInt('app.download_parallel.v1', 99);
    final c2 = container(DownloadStore(Directory('${tmp.path}/dl'), prefs));
    addTearDown(c2.dispose);
    expect(c2.read(appSettingsProvider).downloadParallel, 4);
  });

  test('moveTo copies every file, switches root, and open() honours the choice', () async {
    final oldRoot = Directory('${tmp.path}/old')..createSync();
    final newRoot = Directory('${tmp.path}/new');
    File('${oldRoot.path}/s/a/b/001.jpg')
      ..createSync(recursive: true)
      ..writeAsStringSync('img1');
    File('${oldRoot.path}/s/a/c/chapter.html')
      ..createSync(recursive: true)
      ..writeAsStringSync('<p>x</p>');
    final store = DownloadStore(oldRoot, prefs);

    final steps = <int>[];
    await store.moveTo(newRoot, onProgress: (d, t) => steps.add(d));

    expect(steps, [1, 2]);
    expect(store.root.path, newRoot.path);
    expect(File('${newRoot.path}/s/a/b/001.jpg').readAsStringSync(), 'img1');
    expect(File('${newRoot.path}/s/a/c/chapter.html').readAsStringSync(), '<p>x</p>');
    expect(File('${oldRoot.path}/s/a/b/001.jpg').existsSync(), isFalse);
    expect(prefs.getString(DownloadStore.rootKey), newRoot.path);
    // dirOf mengikuti root baru
    expect(store.dirOf('s/a/b').path, contains('new'));
  });

  test('moveTo to the same folder is a no-op', () async {
    final root = Directory('${tmp.path}/same')..createSync();
    File('${root.path}/f.txt').writeAsStringSync('x');
    final store = DownloadStore(root, prefs);
    await store.moveTo(Directory(root.path));
    expect(File('${root.path}/f.txt').existsSync(), isTrue);
    expect(prefs.getString(DownloadStore.rootKey), isNull);
  });
}
