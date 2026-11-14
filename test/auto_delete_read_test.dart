import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/data/local/download_store.dart';
import 'package:hub_reader/data/models/download.dart';
import 'package:hub_reader/state/app_settings_provider.dart';
import 'package:hub_reader/state/core_providers.dart';
import 'package:hub_reader/state/download_providers.dart';
import 'package:hub_reader/state/source_library_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tmp;
  late ProviderContainer c;
  late DownloadStore store;

  Future<DownloadedChapter> seed(String chapterUrl) async {
    final rel = DownloadStore.relativeDirFor('s', 'u', chapterUrl);
    final dir = store.dirOf(rel);
    await dir.create(recursive: true);
    await File('${dir.path}${Platform.pathSeparator}001.jpg').writeAsBytes([1, 2, 3]);
    final ch = DownloadedChapter(
      sourceId: 's',
      mangaUrl: 'u',
      mangaTitle: 'T',
      chapterUrl: chapterUrl,
      chapterName: chapterUrl,
      relativeDir: rel,
      files: const ['001.jpg'],
      downloadedAt: DateTime.now(),
    );
    await c.read(downloadIndexProvider.notifier).add(ch);
    return ch;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tmp = await Directory.systemTemp.createTemp('auto_delete_read');
    store = DownloadStore(tmp, prefs);
    c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      downloadStoreProvider.overrideWithValue(store),
    ]);
  });

  tearDown(() async {
    c.dispose();
    await tmp.delete(recursive: true);
  });

  test('read downloads are kept while the setting is off', () async {
    final read = await seed('c1');
    await c.read(sourceProgressProvider.notifier).setDone((sourceId: 's', url: 'u'), 'c1', done: true);
    expect(await c.read(downloadIndexProvider.notifier).purgeRead(), 0);
    expect(c.read(downloadIndexProvider), contains(read.key));
    expect(store.dirOf(read.relativeDir).existsSync(), isTrue);
  });

  test('only read chapters are deleted when the setting is on', () async {
    final read = await seed('c1');
    final unread = await seed('c2');
    await c.read(appSettingsProvider.notifier).update((s) => s.copyWith(autoDeleteRead: true));

    // Menandai selesai langsung memicu penghapusan.
    await c.read(sourceProgressProvider.notifier).setDone((sourceId: 's', url: 'u'), 'c1', done: true);

    expect(c.read(downloadIndexProvider).keys, [unread.key]);
    expect(store.dirOf(read.relativeDir).existsSync(), isFalse);
    expect(store.dirOf(unread.relativeDir).existsSync(), isTrue);
    expect(store.readIndex().keys, [unread.key]);
  });

  test('turning the setting on sweeps chapters that were already read', () async {
    final read = await seed('c1');
    await c.read(sourceProgressProvider.notifier).setDone((sourceId: 's', url: 'u'), 'c1', done: true);
    expect(c.read(downloadIndexProvider), contains(read.key));

    await c.read(appSettingsProvider.notifier).update((s) => s.copyWith(autoDeleteRead: true));
    expect(await c.read(downloadIndexProvider.notifier).purgeRead(), 1);
    expect(c.read(downloadIndexProvider), isEmpty);
  });
}
