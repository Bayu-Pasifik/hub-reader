import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/data/local/download_store.dart';
import 'package:hub_reader/data/models/download.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tmp;
  late DownloadStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('hub_dl_');
    store = DownloadStore(tmp, await SharedPreferences.getInstance());
  });
  tearDown(() => tmp.delete(recursive: true));

  DownloadedChapter chapter(String dir) => DownloadedChapter(
        sourceId: 'id.komiku',
        mangaUrl: 'https://komiku.org/manga/one-piece/',
        mangaTitle: 'One Piece',
        chapterUrl: 'https://komiku.org/ch-1/',
        chapterName: 'Chapter 1',
        relativeDir: dir,
        files: const ['001.jpg', '002.jpg'],
        downloadedAt: DateTime(2026, 11, 12),
      );

  test('relative dir is stable and distinct per chapter', () {
    final a = DownloadStore.relativeDirFor('id.komiku', 'https://m/1', 'https://c/1');
    expect(a, DownloadStore.relativeDirFor('id.komiku', 'https://m/1', 'https://c/1'));
    expect(a, isNot(DownloadStore.relativeDirFor('id.komiku', 'https://m/1', 'https://c/2')));
    expect(a.split('/'), hasLength(3));
  });

  test('index round-trips and localPages requires every file', () async {
    final rel = DownloadStore.relativeDirFor('id.komiku', 'https://komiku.org/manga/one-piece/', 'https://komiku.org/ch-1/');
    final c = chapter(rel);
    await store.writeIndex({c.key: c});
    expect(store.readIndex()[c.key]?.files, ['001.jpg', '002.jpg']);

    final dir = store.dirOf(rel)..createSync(recursive: true);
    File('${dir.path}/001.jpg').writeAsBytesSync([1]);
    expect(store.localPages(c), isNull, reason: '002.jpg belum ada');

    File('${dir.path}/002.jpg').writeAsBytesSync([2]);
    expect(store.localPages(c), hasLength(2));

    await store.deleteDir(rel);
    expect(store.localPages(c), isNull);
  });

  test('queue round-trips; running tasks come back queued', () async {
    const ch = SourceChapter(url: 'https://komiku.org/ch-2/', name: 'Chapter 2', number: 2);
    final tasks = [
      const DownloadTask(
        sourceId: 'id.komiku',
        mangaUrl: 'https://komiku.org/manga/one-piece/',
        mangaTitle: 'One Piece',
        chapter: ch,
        status: DownloadStatus.downloading,
        done: 3,
        total: 10,
      ),
      const DownloadTask(
        sourceId: 'id.komiku',
        mangaUrl: 'https://komiku.org/manga/one-piece/',
        mangaTitle: 'One Piece',
        chapter: SourceChapter(url: 'https://komiku.org/ch-3/', name: 'Chapter 3'),
        status: DownloadStatus.failed,
        error: 'Timeout',
      ),
    ];
    await store.writeQueue(tasks);
    final back = store.readQueue();
    expect(back.map((t) => t.key), tasks.map((t) => t.key));
    expect(back[0].status, DownloadStatus.queued);
    expect(back[0].done, 0);
    expect(back[0].chapter.number, 2);
    expect(back[1].status, DownloadStatus.failed);
    expect(back[1].error, 'Timeout');

    await store.writeQueue(const []);
    expect(store.readQueue(), isEmpty);
  });
}
