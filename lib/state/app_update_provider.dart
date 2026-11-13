import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/update/app_update.dart';
import 'core_providers.dart';

/// versionName aplikasi yang terpasang (null di luar Android / tes).
final appVersionProvider = FutureProvider<String?>((ref) => AppUpdate.currentVersion());

final checkUpdatesProvider = NotifierProvider<CheckUpdatesNotifier, bool>(CheckUpdatesNotifier.new);

/// Cek pembaruan otomatis saat aplikasi dibuka (bawaan: nyala).
class CheckUpdatesNotifier extends Notifier<bool> {
  static const key = 'app.check_updates.v1';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(key) ?? true;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(key, value);
  }
}

/// Aturan cek otomatis: paling sering sekali per [interval], dan rilis yang
/// sudah ditolak ("Nanti") tidak ditawarkan lagi sampai ada versi lebih baru.
abstract final class UpdatePolicy {
  static const lastCheckKey = 'app.update_checked_at.v1';
  static const skippedKey = 'app.update_skipped.v1';
  static const interval = Duration(hours: 24);

  static Future<AppRelease?> autoCheck(
    SharedPreferences prefs, {
    required String? current,
    required Future<AppRelease?> Function() fetch,
    DateTime? now,
  }) async {
    if (current == null) return null;
    final at = now ?? DateTime.now();
    final last = prefs.getInt(lastCheckKey);
    if (last != null && at.difference(DateTime.fromMillisecondsSinceEpoch(last)) < interval) return null;
    final AppRelease? release;
    try {
      release = await fetch();
    } on Object {
      return null; // Offline / GitHub tidak bisa dijangkau: coba lagi lain kali.
    }
    await prefs.setInt(lastCheckKey, at.millisecondsSinceEpoch);
    if (release == null || AppUpdate.compare(release.version, current) <= 0) return null;
    final skipped = prefs.getString(skippedKey);
    if (skipped != null && AppUpdate.compare(release.version, skipped) <= 0) return null;
    return release;
  }

  static Future<void> skip(SharedPreferences prefs, AppRelease release) => prefs.setString(skippedKey, release.version);
}
