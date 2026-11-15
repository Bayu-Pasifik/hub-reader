import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core_providers.dart';

/// Status layar sambutan (onboarding): hanya untuk instalasi baru.
abstract final class OnboardingState {
  static const doneKey = 'onboarding.done.v1';

  /// Instalasi baru yang belum menyelesaikan onboarding. Tanpa ini, aplikasi yang
  /// ditutup di tengah onboarding akan dianggap pengguna lama (sudah ada
  /// pengaturan yang tertulis di belakang layar sambutan).
  static const pendingKey = 'onboarding.pending.v1';

  /// Tanda aplikasi sudah pernah dipakai sebelum ada onboarding (versi ≤1.3.0).
  static bool _looksUsed(SharedPreferences p) => p.getKeys().any(
        (k) => k.startsWith('source_library.') || k.startsWith('app.') || k.startsWith('library.') || k.startsWith('reader.'),
      );

  /// Apakah onboarding sudah selesai / tidak perlu. Dipanggil sekali saat
  /// aplikasi dibuka; menyimpan penanda supaya keputusan tetap sama.
  static bool resolve(SharedPreferences p) {
    if (p.getBool(doneKey) == true) return true;
    if (p.getBool(pendingKey) == true) return false; // instalasi baru, belum selesai
    if (_looksUsed(p)) {
      // Pengguna lama yang baru memperbarui: tidak perlu sambutan.
      p.setBool(doneKey, true);
      return true;
    }
    p.setBool(pendingKey, true);
    return false;
  }

  static Future<void> complete(SharedPreferences p) async {
    await p.setBool(doneKey, true);
    await p.remove(pendingKey);
  }
}

/// True bila onboarding sudah selesai (atau tidak perlu ditampilkan).
final onboardingDoneProvider = NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);

class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() => OnboardingState.resolve(ref.read(sharedPreferencesProvider));

  Future<void> complete() async {
    state = true;
    await OnboardingState.complete(ref.read(sharedPreferencesProvider));
  }
}
