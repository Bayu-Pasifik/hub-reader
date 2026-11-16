import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/core/platform/reader_bridge.dart';
import 'package:hub_reader/data/local/download_store.dart';
import 'package:hub_reader/data/models/download.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/state/core_providers.dart';
import 'package:hub_reader/state/download_providers.dart';
import 'package:hub_reader/state/reader_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tmp;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tmp = await Directory.systemTemp.createTemp('download_manager');
  });

  tearDown(() async => tmp.delete(recursive: true));

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      downloadStoreProvider.overrideWithValue(DownloadStore(Directory('${tmp.path}/dl'), prefs)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  const manga = SourceMangaDetails(url: 'm', title: 'M');
  const chapters = [SourceChapter(url: 'm/1', name: 'Ch 1'), SourceChapter(url: 'm/2', name: 'Ch 2')];

  test('antrean dijeda: tidak ada yang dimulai, tersimpan, dan jalan lagi setelah dilanjutkan', () async {
    final c = container();
    await c.read(downloadPausedProvider.notifier).set(true);
    expect(prefs.getBool('download.paused.v1'), isTrue);

    c.read(downloadQueueProvider.notifier).enqueue(sourceId: 's', mangaUrl: 'm', manga: manga, chapters: chapters);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(c.read(downloadQueueProvider).map((t) => t.status.name), ['queued', 'queued']);

    // Aplikasi dibuka lagi: masih dijeda.
    final c2 = container();
    expect(c2.read(downloadPausedProvider), isTrue);

    // Lanjut: sumber 's' tidak ada, jadi tugas berjalan lalu gagal cepat.
    await c.read(downloadPausedProvider.notifier).set(false);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(c.read(downloadQueueProvider).every((t) => t.status == DownloadStatus.failed), isTrue);
  });

  test('coba lagi semua, buang yang gagal, dan batalkan semua', () async {
    final c = container();
    await c.read(downloadPausedProvider.notifier).set(true);
    final q = c.read(downloadQueueProvider.notifier);
    q.enqueue(sourceId: 's', mangaUrl: 'm', manga: manga, chapters: chapters);
    expect(c.read(downloadQueueProvider), hasLength(2));

    q.cancelAll();
    expect(c.read(downloadQueueProvider), isEmpty);

    q.enqueue(sourceId: 's', mangaUrl: 'm', manga: manga, chapters: chapters);
    await c.read(downloadPausedProvider.notifier).set(false);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(c.read(downloadQueueProvider).every((t) => t.status == DownloadStatus.failed), isTrue);

    await c.read(downloadPausedProvider.notifier).set(true);
    q.retryAllFailed();
    expect(c.read(downloadQueueProvider).every((t) => t.status == DownloadStatus.queued), isTrue);

    await c.read(downloadPausedProvider.notifier).set(false);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    q.clearFailed();
    expect(c.read(downloadQueueProvider), isEmpty);
  });

  test('ukuran unduhan dihitung dari file di disk, total dan per seri', () async {
    final c = container();
    final store = c.read(downloadStoreProvider);
    final dir = store.dirOf('s/a/b')..createSync(recursive: true);
    File('${dir.path}/001.jpg').writeAsBytesSync(List.filled(1500, 1));
    File('${dir.path}/002.jpg').writeAsBytesSync(List.filled(500, 1));
    await c.read(downloadIndexProvider.notifier).add(DownloadedChapter(
          sourceId: 's',
          mangaUrl: 'm',
          mangaTitle: 'M',
          chapterUrl: 'm/1',
          chapterName: 'Ch 1',
          relativeDir: 's/a/b',
          files: const ['001.jpg', '002.jpg', 'hilang.jpg'],
          downloadedAt: DateTime(2026),
        ));
    final sizes = await c.read(downloadSizesProvider.future);
    expect(sizes.total, 2000);
    expect(sizes.bySeries['s|m'], 2000);
    expect(formatBytes(512), '512 B');
    expect(formatBytes(2048), '2 KB');
    expect(formatBytes(3 * 1024 * 1024), '3.0 MB');
  });

  test('override reader per seri: JSON bolak-balik dan hanya kolom terisi yang menimpa', () {
    const base = ReaderDisplay(orientation: ReaderOrientation.portrait, transition: PageTransitionStyle.fade);
    const o = SeriesReaderOverride(mode: ReaderMode.pagedRtl, grayscale: true, dim: 0.4);
    final restored = SeriesReaderOverride.fromJson(o.toJson());
    expect((restored.mode, restored.grayscale, restored.dim), (ReaderMode.pagedRtl, true, 0.4));
    expect(restored.orientation, isNull);

    final shown = restored.applyTo(base);
    expect(shown.grayscale, isTrue);
    expect(shown.dim, 0.4);
    expect(shown.orientation, ReaderOrientation.portrait); // tidak diisi: ikut umum
    expect(shown.transition, PageTransitionStyle.fade);

    final snap = SeriesReaderOverride.snapshot(ReaderMode.webtoon, base);
    expect(SeriesReaderOverride.fromJson(snap.toJson()).orientation, ReaderOrientation.portrait);
    expect(snap.withDisplay(base.copyWith(invert: true)).invert, isTrue);
    expect(snap.withMode(ReaderMode.pagedLtr).mode, ReaderMode.pagedLtr);
  });

  test('override reader lama (hanya mode & crop) tetap terbaca', () {
    final o = SeriesReaderOverride.fromJson({'mode': 'pagedLtr', 'crop': true});
    expect(o.cropBorders, isTrue);
    expect(o.orientation, isNull);
    expect(o.applyTo(const ReaderDisplay()).cropBorders, isTrue);
  });
}
