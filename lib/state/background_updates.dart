import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../bootstrap.dart';
import '../data/local/auto_backup.dart';
import 'core_providers.dart';
import 'library_updates_provider.dart';

/// Jadwal cek bab baru di latar belakang (Android WorkManager).
class BackgroundUpdateConfig {
  const BackgroundUpdateConfig({required this.hours, required this.wifiOnly});

  /// 0 = mati.
  final int hours;
  final bool wifiOnly;

  bool get enabled => hours > 0;

  static const choices = [0, 6, 12, 24, 48];

  static String label(int hours) => switch (hours) {
        0 => 'Mati',
        24 => 'Sehari sekali',
        48 => '2 hari sekali',
        _ => 'Tiap $hours jam',
      };

  static const _hoursKey = 'library.updates.bg.hours.v1';
  static const _wifiKey = 'library.updates.bg.wifi.v1';

  static BackgroundUpdateConfig read(SharedPreferences prefs) => BackgroundUpdateConfig(
        hours: prefs.getInt(_hoursKey) ?? 12,
        wifiOnly: prefs.getBool(_wifiKey) ?? false,
      );

  Future<void> write(SharedPreferences prefs) async {
    await prefs.setInt(_hoursKey, hours);
    await prefs.setBool(_wifiKey, wifiOnly);
  }

  BackgroundUpdateConfig copyWith({int? hours, bool? wifiOnly}) =>
      BackgroundUpdateConfig(hours: hours ?? this.hours, wifiOnly: wifiOnly ?? this.wifiOnly);
}

final backgroundUpdatesProvider =
    NotifierProvider<BackgroundUpdatesNotifier, BackgroundUpdateConfig>(BackgroundUpdatesNotifier.new);

class BackgroundUpdatesNotifier extends Notifier<BackgroundUpdateConfig> {
  @override
  BackgroundUpdateConfig build() => BackgroundUpdateConfig.read(ref.watch(sharedPreferencesProvider));

  Future<void> set(BackgroundUpdateConfig config) async {
    state = config;
    await config.write(ref.read(sharedPreferencesProvider));
    await BackgroundUpdates.schedule(config, replace: true);
  }
}

final autoBackupProvider = NotifierProvider<AutoBackupNotifier, AutoBackupConfig>(AutoBackupNotifier.new);

class AutoBackupNotifier extends Notifier<AutoBackupConfig> {
  @override
  AutoBackupConfig build() => AutoBackupConfig.read(ref.watch(sharedPreferencesProvider));

  Future<void> set(AutoBackupConfig config) async {
    state = config;
    await config.write(ref.read(sharedPreferencesProvider));
    await BackgroundUpdates.scheduleBackup(config, replace: true);
  }
}

/// Registrasi tugas WorkManager & titik masuk isolate latar.
abstract final class BackgroundUpdates {
  static const uniqueName = 'hub_reader.library_updates';
  static const taskName = 'libraryUpdates';

  static const backupUniqueName = 'hub_reader.auto_backup';
  static const backupTaskName = 'autoBackup';

  static bool _initialized = false;

  /// WorkManager cukup diinisialisasi sekali; dipakai juga oleh cadangan otomatis.
  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    await Workmanager().initialize(backgroundUpdatesDispatcher);
    _initialized = true;
  }

  /// Jadwal cadangan otomatis (tugas berkala WorkManager).
  static Future<void> scheduleBackup(AutoBackupConfig config, {bool replace = false}) async {
    try {
      await ensureInitialized();
      if (!config.enabled) {
        await Workmanager().cancelByUniqueName(backupUniqueName);
        return;
      }
      await Workmanager().registerPeriodicTask(
        backupUniqueName,
        backupTaskName,
        frequency: Duration(hours: config.hours),
        initialDelay: Duration(hours: config.hours),
        existingWorkPolicy: replace ? ExistingPeriodicWorkPolicy.update : ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(requiresBatteryNotLow: true, requiresStorageNotLow: true),
      );
    } catch (e) {
      debugPrint('BackgroundUpdates.scheduleBackup: $e');
    }
  }

  /// Satu cadangan otomatis di isolate latar.
  static Future<void> runBackupOnce() async {
    final deps = await AppDependencies.open(background: true);
    await AutoBackup.run(deps.prefs, deps.novelPlugins);
  }

  /// Dipanggil sekali dari `main()`. [replace] dipakai saat pengguna
  /// mengganti jadwal; saat aplikasi dibuka, jadwal yang ada dibiarkan agar
  /// hitungan intervalnya tidak mulai dari nol.
  static Future<void> schedule(BackgroundUpdateConfig config, {bool replace = false}) async {
    try {
      await ensureInitialized();
      if (!config.enabled) {
        await Workmanager().cancelByUniqueName(uniqueName);
        return;
      }
      await Workmanager().registerPeriodicTask(
        uniqueName,
        taskName,
        frequency: Duration(hours: config.hours),
        initialDelay: Duration(hours: config.hours),
        existingWorkPolicy: replace ? ExistingPeriodicWorkPolicy.update : ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(
          networkType: config.wifiOnly ? NetworkType.unmetered : NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
      );
    } catch (e) {
      debugPrint('BackgroundUpdates.schedule: $e');
    }
  }

  /// Satu putaran cek bab baru di isolate latar. Mengembalikan jumlah bab
  /// baru; notifikasi dikirim oleh [LibraryUpdatesNotifier].
  static Future<int> runOnce() async {
    final deps = await AppDependencies.open(background: true);
    final container = ProviderContainer(overrides: deps.overrides);
    try {
      return await container.read(libraryUpdatesProvider.notifier).checkAll(notify: true);
    } finally {
      container.dispose();
    }
  }
}

@pragma('vm:entry-point')
void backgroundUpdatesDispatcher() {
  Workmanager().executeTask((task, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    if (task == BackgroundUpdates.backupTaskName) {
      try {
        await BackgroundUpdates.runBackupOnce();
      } catch (e) {
        debugPrint('Background auto backup failed: $e');
      }
      return true;
    }
    if (task != BackgroundUpdates.taskName) return true;
    try {
      final found = await BackgroundUpdates.runOnce();
      debugPrint('Background library update: $found new chapters');
    } catch (e) {
      debugPrint('Background library update failed: $e');
    }
    // Selalu sukses: kegagalan jaringan dicoba lagi di jadwal berikutnya,
    // bukan lewat backoff WorkManager.
    return true;
  });
}
