import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/data/local/progress_sync.dart';
import 'package:hub_reader/data/models/source_library.dart';

SourceChapterProgress _p(int page, int minute, {bool done = false}) =>
    SourceChapterProgress(page: page, total: 10, done: done, updatedAt: DateTime(2026, 11, 17, 10, minute));

void main() {
  test('progres: cap waktu terbaru menang per bab, seri lain digabung', () {
    final local = SyncSnapshot(progress: {
      's|a': {'c1': _p(3, 5), 'c2': _p(9, 1, done: true)},
    });
    final remote = SyncSnapshot(progress: {
      's|a': {'c1': _p(7, 9), 'c3': _p(1, 2)},
      's|b': {'x': _p(2, 2)},
    });
    final m = ProgressSync.merge(local, remote);
    expect(m.progress['s|a']!['c1']!.page, 7);
    expect(m.progress['s|a']!['c2']!.done, isTrue);
    expect(m.progress['s|a']!.containsKey('c3'), isTrue);
    expect(m.progress['s|b']!['x']!.page, 2);
  });

  SourceFavorite fav(String key, DateTime added, {DateTime? updated}) {
    final parts = key.split('|');
    return SourceFavorite(
      item: SourceLibraryItem(sourceId: parts[0], url: parts[1], title: key),
      addedAt: added,
      updatedAt: updated,
    );
  }

  group('tombstone favorit', () {
    final t0 = DateTime(2026, 11, 1);
    final t1 = DateTime(2026, 11, 5);
    final t2 = DateTime(2026, 11, 9);
    final now = DateTime(2026, 11, 17);

    test('hapus di satu perangkat ikut menghapus di perangkat lain', () {
      final a = fav('s|x', t0);
      final local = SyncSnapshot(removed: {a.item.key: t1});
      final remote = SyncSnapshot(favorites: [a]);
      final m = ProgressSync.merge(local, remote, now: now);
      expect(m.favorites, isEmpty);
      expect(m.removed.containsKey(a.item.key), isTrue);
    });

    test('difavoritkan ulang setelah dihapus tetap hidup dan tombstone dibuang', () {
      final a = fav('s|x', t2);
      final local = SyncSnapshot(favorites: [a]);
      final remote = SyncSnapshot(removed: {a.item.key: t1});
      final m = ProgressSync.merge(local, remote, now: now);
      expect(m.favorites, hasLength(1));
      expect(m.removed, isEmpty);
    });

    test('urungkan (updatedAt baru) mengalahkan tombstone lama', () {
      final a = fav('s|x', t0, updated: t2);
      final m = ProgressSync.merge(
        SyncSnapshot(favorites: [a]),
        SyncSnapshot(removed: {a.item.key: t1}),
        now: now,
      );
      expect(m.favorites, hasLength(1));
    });

    test('tombstone kedaluwarsa dibuang', () {
      final m = ProgressSync.merge(
        SyncSnapshot(removed: {'s|old': DateTime(2026, 1, 1)}),
        const SyncSnapshot(),
        now: now,
      );
      expect(m.removed, isEmpty);
    });

    test('round-trip JSON membawa tombstone dan updatedAt', () {
      final snap = SyncSnapshot(removed: {'s|x': t1}, favorites: [fav('s|y', t0, updated: t2)]);
      final back = SyncSnapshot.parse(snap.toJson());
      expect(back.removed['s|x'], t1);
      expect(back.favorites.single.updatedAt, t2);
    });
  });

  test('snapshot round-trip lewat JSON', () {
    final snap = SyncSnapshot(progress: {'s|a': {'c1': _p(3, 5)}});
    final back = SyncSnapshot.parse(snap.toJson());
    expect(back.progress['s|a']!['c1']!.page, 3);
  });
}
