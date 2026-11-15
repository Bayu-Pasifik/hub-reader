import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/state/onboarding_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> prefsWith(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

void main() {
  test('instalasi baru: onboarding tampil dan ditandai pending', () async {
    final p = await prefsWith({});
    expect(OnboardingState.resolve(p), isFalse);
    expect(p.getBool(OnboardingState.pendingKey), isTrue);
    expect(p.getBool(OnboardingState.doneKey), isNull);
  });

  test('tanda yang ditulis aplikasi sendiri (cache, UA) tidak dianggap pemakaian', () async {
    final p = await prefsWith({'sources.user_agent.v1': 'UA', 'sources.health.v1': '{}', 'flutter.x': 1});
    expect(OnboardingState.resolve(p), isFalse);
  });

  test('pengguna lama (punya favorit / pengaturan / riwayat) tidak melihat onboarding', () async {
    for (final key in ['source_library.favorites.v1', 'app.theme.v1', 'library.categories.v1', 'reader.mode.v1', 'app.update_checked_at.v1']) {
      final p = await prefsWith({key: 'x'});
      expect(OnboardingState.resolve(p), isTrue, reason: key);
      expect(p.getBool(OnboardingState.doneKey), isTrue, reason: key);
    }
  });

  test('ditutup di tengah onboarding: tetap tampil walau aplikasi sudah menulis pengaturan', () async {
    final p = await prefsWith({});
    expect(OnboardingState.resolve(p), isFalse); // launch pertama
    await p.setString('app.update_checked_at.v1', 'now'); // ditulis di belakang layar sambutan
    expect(OnboardingState.resolve(p), isFalse); // launch kedua: masih tampil
  });

  test('selesai: tidak tampil lagi dan pending dihapus', () async {
    final p = await prefsWith({});
    OnboardingState.resolve(p);
    await OnboardingState.complete(p);
    expect(p.getBool(OnboardingState.pendingKey), isNull);
    expect(OnboardingState.resolve(p), isTrue);
  });

  test('selesai tetap berlaku setelah restore cadangan (penanda ikut tersimpan)', () async {
    final p = await prefsWith({OnboardingState.doneKey: true});
    expect(OnboardingState.resolve(p), isTrue);
  });
}
