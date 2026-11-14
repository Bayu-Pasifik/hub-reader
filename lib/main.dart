import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'app_restart.dart';
import 'bootstrap.dart';
import 'data/local/auto_backup.dart';
import 'state/background_updates.dart';

/// Titik masuk aplikasi.
///
/// SharedPreferences dan folder cache dibuka sekali di sini (async), lalu
/// disuntikkan ke Riverpod lewat `overrides` sehingga provider lain bisa
/// memakainya secara sinkron.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final deps = await AppDependencies.open();
  // Jadwal cek bab baru di latar (tidak ditunggu: WorkManager lambat start).
  BackgroundUpdates.schedule(BackgroundUpdateConfig.read(deps.prefs));
  // Cadangan otomatis: jadwal berkala + cadangan susulan bila WorkManager
  // terlewat (mis. dibatasi hemat baterai).
  final backupConfig = AutoBackupConfig.read(deps.prefs);
  BackgroundUpdates.scheduleBackup(backupConfig);
  if (AutoBackup.isDue(deps.prefs, backupConfig)) {
    () async {
      try {
        await AutoBackup.run(deps.prefs, deps.novelPlugins, config: backupConfig);
      } catch (e) {
        debugPrint('Auto backup on start failed: $e');
      }
    }();
  }

  runApp(
    AppRestart(
      // Setelah memulihkan cadangan: cookie & semua provider dibaca ulang.
      onRestart: deps.loadCookies,
      builder: (_) => ProviderScope(
        overrides: deps.overrides,
        child: const HubReaderApp(),
      ),
    ),
  );
}
