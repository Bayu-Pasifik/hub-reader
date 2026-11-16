import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/state/auto_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime(2026, 11, 17, 12);

  Future<SharedPreferences> prefs(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  test('mati secara bawaan', () async {
    final p = await prefs({});
    expect(AutoSync.isEnabled(p), isFalse);
    expect(AutoSync.isDue(p, now: now), isFalse);
  });

  test('aktif dan belum pernah jalan: jatuh tempo', () async {
    final p = await prefs({AutoSync.enabledKey: true});
    expect(AutoSync.isDue(p, now: now), isTrue);
  });

  test('jeda minimum dihormati', () async {
    final recent = now.subtract(const Duration(minutes: 3)).millisecondsSinceEpoch;
    final old = now.subtract(const Duration(minutes: 30)).millisecondsSinceEpoch;
    expect(AutoSync.isDue(await prefs({AutoSync.enabledKey: true, AutoSync.lastKey: recent}), now: now), isFalse);
    expect(AutoSync.isDue(await prefs({AutoSync.enabledKey: true, AutoSync.lastKey: old}), now: now), isTrue);
  });
}
