import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../novels/plugin_repository.dart';
import 'backup.dart';

/// Pengaturan cadangan otomatis.
class AutoBackupConfig {
  const AutoBackupConfig({
    required this.hours,
    required this.keep,
    required this.plugins,
    required this.secrets,
  });

  /// 0 = mati.
  final int hours;

  /// Jumlah cadangan otomatis terbaru yang disimpan.
  final int keep;
  final bool plugins;
  final bool secrets;

  bool get enabled => hours > 0;

  static const choices = [0, 24, 72, 168];
  static const keepChoices = [3, 5, 10];

  static String label(int hours) => switch (hours) {
        0 => 'Mati',
        24 => 'Tiap hari',
        72 => 'Tiap 3 hari',
        168 => 'Tiap minggu',
        _ => 'Tiap $hours jam',
      };

  static const _hoursKey = 'backup.auto.hours.v1';
  static const _keepKey = 'backup.auto.keep.v1';
  static const _pluginsKey = 'backup.auto.plugins.v1';
  static const _secretsKey = 'backup.auto.secrets.v1';

  static AutoBackupConfig read(SharedPreferences prefs) => AutoBackupConfig(
        hours: prefs.getInt(_hoursKey) ?? 0,
        keep: prefs.getInt(_keepKey) ?? 5,
        plugins: prefs.getBool(_pluginsKey) ?? true,
        secrets: prefs.getBool(_secretsKey) ?? false,
      );

  Future<void> write(SharedPreferences prefs) async {
    await prefs.setInt(_hoursKey, hours);
    await prefs.setInt(_keepKey, keep);
    await prefs.setBool(_pluginsKey, plugins);
    await prefs.setBool(_secretsKey, secrets);
  }

  AutoBackupConfig copyWith({int? hours, int? keep, bool? plugins, bool? secrets}) => AutoBackupConfig(
        hours: hours ?? this.hours,
        keep: keep ?? this.keep,
        plugins: plugins ?? this.plugins,
        secrets: secrets ?? this.secrets,
      );
}

/// Satu file cadangan otomatis di perangkat.
class AutoBackupEntry {
  const AutoBackupEntry({required this.file, required this.modified, required this.size});

  final File file;
  final DateTime modified;
  final int size;

  String get name => file.uri.pathSegments.last;
}

/// Cadangan berkala ke folder aplikasi (`Android/data/<paket>/files/backups`,
/// bisa diambil lewat USB / pengelola file). Berjalan dari WorkManager dan
/// sebagai cadangan susulan saat aplikasi dibuka.
abstract final class AutoBackup {
  static const _lastKey = 'backup.auto.last.v1';
  static const _prefix = 'hub_reader_auto_';

  /// Hanya untuk test: ganti folder tujuan.
  static Directory? directoryOverride;

  static Future<Directory> directory() async {
    final override = directoryOverride;
    if (override != null) {
      await override.create(recursive: true);
      return override;
    }
    Directory? base;
    try {
      base = await getExternalStorageDirectory();
    } catch (_) {
      base = null;
    }
    base ??= await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}backups');
    await dir.create(recursive: true);
    return dir;
  }

  static DateTime? lastRun(SharedPreferences prefs) {
    final ms = prefs.getInt(_lastKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static bool isDue(SharedPreferences prefs, AutoBackupConfig config, {DateTime? now}) {
    if (!config.enabled) return false;
    final last = lastRun(prefs);
    if (last == null) return true;
    return (now ?? DateTime.now()).difference(last) >= Duration(hours: config.hours);
  }

  /// Buat satu cadangan lalu hapus yang melebihi [AutoBackupConfig.keep].
  /// Ditulis ke file sementara dulu supaya cadangan setengah jadi tidak
  /// pernah tampil di daftar.
  static Future<File> run(
    SharedPreferences prefs,
    NovelPluginRepository plugins, {
    AutoBackupConfig? config,
    DateTime? now,
  }) async {
    final cfg = config ?? AutoBackupConfig.read(prefs);
    final data = await AppBackup.create(
      prefs,
      includeSecrets: cfg.secrets,
      plugins: cfg.plugins ? await plugins.exportInstalled() : null,
    );
    final stamp = now ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final name = '$_prefix${stamp.year}${two(stamp.month)}${two(stamp.day)}_'
        '${two(stamp.hour)}${two(stamp.minute)}${two(stamp.second)}.json';
    final dir = await directory();
    final target = File('${dir.path}${Platform.pathSeparator}$name');
    final temp = File('${target.path}.tmp');
    await temp.writeAsString(jsonEncode(data), flush: true);
    await temp.rename(target.path);
    await prefs.setInt(_lastKey, stamp.millisecondsSinceEpoch);
    await prune(cfg.keep);
    return target;
  }

  /// Daftar cadangan otomatis, terbaru dulu.
  static Future<List<AutoBackupEntry>> list() async {
    final dir = await directory();
    final entries = <AutoBackupEntry>[];
    await for (final e in dir.list()) {
      if (e is! File) continue;
      final name = e.uri.pathSegments.last;
      if (!name.startsWith(_prefix) || !name.endsWith('.json')) continue;
      final stat = await e.stat();
      entries.add(AutoBackupEntry(file: e, modified: stat.modified, size: stat.size));
    }
    entries.sort((a, b) => b.modified.compareTo(a.modified));
    return entries;
  }

  static Future<void> prune(int keep) async {
    final entries = await list();
    for (final old in entries.skip(keep < 1 ? 1 : keep)) {
      try {
        await old.file.delete();
      } catch (_) {
        // dicoba lagi di putaran berikutnya
      }
    }
  }
}
