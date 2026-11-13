import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/json.dart';

/// Cadangan data aplikasi: semua SharedPreferences (favorit, riwayat,
/// progres baca, kategori, pengaturan) + daftar pembaruan favorit.
///
/// File unduhan tidak ikut (bisa besar). Cookie login dan penyimpanan plugin
/// novel (bisa berisi sesi login) hanya ikut bila diminta.
class AppBackup {
  static const format = 'hub_reader-backup';
  static const version = 1;

  /// Indeks unduhan merujuk file di perangkat ini; tidak pernah dicadangkan.
  static const _neverKeys = {'downloads.index.v1'};

  /// Berisi sesi login / cookie situs.
  static bool isSecretKey(String key) => key == 'sources.cookies.v1' || key.startsWith('lnr.kv.');

  static Future<File> _updatesFile() async =>
      File('${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}library_updates.json');

  static Future<JsonMap> create(SharedPreferences prefs, {required bool includeSecrets}) async {
    final values = <String, Object?>{};
    for (final key in prefs.getKeys()) {
      if (_neverKeys.contains(key) || (!includeSecrets && isSecretKey(key))) continue;
      final v = prefs.get(key);
      values[key] = switch (v) {
        final String s => {'t': 's', 'v': s},
        final bool b => {'t': 'b', 'v': b},
        final int i => {'t': 'i', 'v': i},
        final double d => {'t': 'd', 'v': d},
        final List<dynamic> l => {'t': 'l', 'v': l.map((e) => '$e').toList()},
        _ => null,
      };
    }
    values.removeWhere((_, v) => v == null);
    Object? updates;
    try {
      final file = await _updatesFile();
      if (await file.exists()) updates = jsonDecode(await file.readAsString());
    } catch (_) {
      updates = null;
    }
    return {
      'format': format,
      'version': version,
      'created_at': DateTime.now().toIso8601String(),
      'secrets': includeSecrets,
      'prefs': values,
      if (updates != null) 'library_updates': updates,
    };
  }

  /// Validasi + ringkasan untuk ditampilkan sebelum memulihkan.
  static BackupSummary? inspect(Object? decoded) {
    final json = asMap(decoded);
    if (json['format'] != format) return null;
    final prefs = asMap(json['prefs']);
    int count(String key) {
      final raw = asMap(prefs[key])['v'];
      if (raw is! String) return 0;
      try {
        return asList(jsonDecode(raw)).length;
      } catch (_) {
        return 0;
      }
    }

    return BackupSummary(
      createdAt: asDate(json['created_at']),
      favorites: count('source_library.favorites.v1'),
      history: count('source_library.history.v1'),
      settings: prefs.length,
      secrets: json['secrets'] == true,
    );
  }

  /// Ganti data aplikasi dengan isi cadangan. Cookie/penyimpanan plugin di
  /// perangkat tetap dipakai bila cadangan tidak menyertakannya.
  static Future<void> restore(SharedPreferences prefs, Object? decoded) async {
    final json = asMap(decoded);
    if (json['format'] != format) throw const FormatException('Bukan file cadangan Hub Reader');
    final withSecrets = json['secrets'] == true;
    for (final key in prefs.getKeys().toList()) {
      if (_neverKeys.contains(key) || (!withSecrets && isSecretKey(key))) continue;
      await prefs.remove(key);
    }
    for (final e in asMap(json['prefs']).entries) {
      if (_neverKeys.contains(e.key)) continue;
      final m = asMap(e.value);
      final v = m['v'];
      switch (m['t']) {
        case 's' when v is String:
          await prefs.setString(e.key, v);
        case 'b' when v is bool:
          await prefs.setBool(e.key, v);
        case 'i' when v is num:
          await prefs.setInt(e.key, v.toInt());
        case 'd' when v is num:
          await prefs.setDouble(e.key, v.toDouble());
        case 'l':
          await prefs.setStringList(e.key, asStringList(v));
      }
    }
    try {
      final file = await _updatesFile();
      final updates = json['library_updates'];
      if (updates != null) {
        await file.writeAsString(jsonEncode(updates));
      } else if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // daftar pembaruan opsional
    }
  }
}

class BackupSummary {
  const BackupSummary({
    required this.createdAt,
    required this.favorites,
    required this.history,
    required this.settings,
    required this.secrets,
  });

  final DateTime? createdAt;
  final int favorites;
  final int history;
  final int settings;
  final bool secrets;
}
