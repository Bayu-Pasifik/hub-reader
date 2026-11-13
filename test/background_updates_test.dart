import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/state/background_updates.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('background update config defaults and round-trips', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final initial = BackgroundUpdateConfig.read(prefs);
    expect(initial.hours, 12);
    expect(initial.enabled, isTrue);
    expect(initial.wifiOnly, isFalse);

    await initial.copyWith(hours: 0, wifiOnly: true).write(prefs);
    final saved = BackgroundUpdateConfig.read(prefs);
    expect(saved.enabled, isFalse);
    expect(saved.wifiOnly, isTrue);
  });

  test('background update labels', () {
    expect(BackgroundUpdateConfig.label(0), 'Mati');
    expect(BackgroundUpdateConfig.label(6), 'Tiap 6 jam');
    expect(BackgroundUpdateConfig.label(24), 'Sehari sekali');
  });
}
