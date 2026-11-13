import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/state/reading_stats_provider.dart';

void main() {
  final day = DateTime(2026, 11, 13, 20);

  test('reading stats sums days, chapters and streak', () {
    var s = const ReadingStats()
        .addSeconds(day, 600)
        .addSeconds(day, 120)
        .addSeconds(day.subtract(const Duration(days: 1)), 300)
        .addSeconds(day.subtract(const Duration(days: 3)), 60)
        .addChapter(day, novel: true)
        .addChapter(day, novel: false);
    expect(s.secondsOn(day), 720);
    expect(s.secondsLast(7, now: day), 1080);
    expect(s.totalNovelChapters, 1);
    expect(s.chaptersOn(day), 2);
    expect(s.streak(now: day), 2);
    // Hari ini belum membaca: rentetan dihitung dari kemarin.
    expect(s.streak(now: day.add(const Duration(days: 1))), 2);
    expect(s.streak(now: day.add(const Duration(days: 2))), 0);

    s = ReadingStats.parse(s.encode());
    expect(s.totalSeconds, 1080);
    expect(s.pruned(keepDays: 2, now: day).totalSeconds, 1020);
  });

  test('reading session caps idle gaps', () {
    var now = DateTime(2026, 1, 1, 10);
    final flushed = <Duration>[];
    final session = ReadingSession(flushed.add, clock: () => now);
    session.activity();
    now = now.add(const Duration(seconds: 20));
    session.activity();
    expect(flushed, isEmpty); // < 30 detik: belum ditulis
    now = now.add(const Duration(hours: 1)); // ditinggal
    session.activity();
    expect(flushed.single, const Duration(seconds: 20) + ReadingSession.maxGap);
    now = now.add(const Duration(seconds: 10));
    session.pause();
    expect(flushed.last, const Duration(seconds: 10));
    now = now.add(const Duration(hours: 2));
    session.activity(); // setelah jeda, mulai lagi dari nol
    session.pause();
    expect(flushed.length, 2);
  });
}
