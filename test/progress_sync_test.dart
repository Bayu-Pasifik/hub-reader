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

  test('snapshot round-trip lewat JSON', () {
    final snap = SyncSnapshot(progress: {'s|a': {'c1': _p(3, 5)}});
    final back = SyncSnapshot.parse(snap.toJson());
    expect(back.progress['s|a']!['c1']!.page, 3);
  });
}
