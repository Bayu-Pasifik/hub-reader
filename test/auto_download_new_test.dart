import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/data/local/download_store.dart';
import 'package:hub_reader/data/models/source_library.dart';
import 'package:hub_reader/state/app_settings_provider.dart';
import 'package:hub_reader/state/core_providers.dart';
import 'package:hub_reader/state/download_providers.dart';
import 'package:hub_reader/state/library_updates_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tmp;
  late ProviderContainer c;

  LibraryUpdate update(String series, int n) => LibraryUpdate(
        item: SourceLibraryItem(sourceId: 's', url: series, title: series),
        chapterUrl: '$series/ch$n',
        chapterName: 'Ch $n',
        foundAt: DateTime(2026),
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tmp = await Directory.systemTemp.createTemp('auto_download_new');
    c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      downloadStoreProvider.overrideWithValue(DownloadStore(tmp, prefs)),
    ]);
  });

  tearDown(() async {
    c.dispose();
    await tmp.delete(recursive: true);
  });

  test('nothing is queued while the setting is off', () {
    c.read(libraryUpdatesProvider.notifier).autoDownload([update('a', 1)]);
    expect(c.read(downloadQueueProvider), isEmpty);
  });

  test('new chapters are queued, oldest first, capped per check', () async {
    await c.read(appSettingsProvider.notifier).update((s) => s.copyWith(autoDownloadNew: true));
    // Terbaru di atas, seperti daftar pembaruan.
    final found = [for (var n = 25; n >= 1; n--) update('a', n)];
    c.read(libraryUpdatesProvider.notifier).autoDownload(found);
    final queue = c.read(downloadQueueProvider);
    expect(queue.length, LibraryUpdatesNotifier.maxAutoDownload);
    expect(queue.first.chapter.url, 'a/ch1');
    // Biarkan unduhan (yang gagal cepat: sumber tidak ada) selesai sebelum dispose.
    await Future<void>.delayed(const Duration(seconds: 1));
  });
}
