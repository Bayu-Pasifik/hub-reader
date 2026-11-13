import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/state/novel_health_provider.dart';
import 'package:hub_reader/state/source_health_provider.dart';

void main() {
  test('parseNovelHealthBaseline reads status, detail and date', () {
    final map = parseNovelHealthBaseline(
      '{"checked_at":"2026-11-13T05:00:00Z","plugins":{"a":{"s":"ok"},"b":{"s":"dead","d":"HTTP 522"},"c":{"s":"??"}}}',
    );
    expect(map.keys, ['a', 'b']);
    expect(map['a']!.status, HealthStatus.ok);
    expect(map['b']!.status, HealthStatus.dead);
    expect(map['b']!.detail, 'HTTP 522');
    expect(map['a']!.checkedAt.toUtc(), DateTime.utc(2026, 11, 13, 5));
  });

  test('novelUsable hides only broken and dead plugins', () {
    final now = DateTime.now();
    expect(novelUsable(null), isTrue);
    expect(novelUsable(SourceHealth(HealthStatus.ok, now)), isTrue);
    expect(novelUsable(SourceHealth(HealthStatus.cloudflare, now)), isTrue);
    expect(novelUsable(SourceHealth(HealthStatus.broken, now)), isFalse);
    expect(novelUsable(SourceHealth(HealthStatus.dead, now)), isFalse);
  });
}
