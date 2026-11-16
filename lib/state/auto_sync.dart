import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local/progress_sync.dart';
import '../data/local/webdav_backup.dart';
import 'core_providers.dart';
import 'source_library_providers.dart';

/// Sinkron favorit/riwayat/progres lewat WebDAV secara otomatis (opsional).
///
/// Dipicu saat aplikasi dibuka dan saat kembali ke latar depan, dengan jeda
/// minimum agar tidak membebani server. Gagal secara diam-diam; sinkron manual
/// di layar Cadangan tetap tersedia dan menampilkan galatnya.
class AutoSync {
  AutoSync(this._ref);

  final Ref _ref;

  static const enabledKey = 'sync.auto.v1';
  static const lastKey = 'sync.auto.last.v1';

  /// Jeda minimum antar sinkron otomatis.
  static const minInterval = Duration(minutes: 10);

  bool _running = false;

  static bool isEnabled(SharedPreferences prefs) => prefs.getBool(enabledKey) ?? false;

  static DateTime? lastRun(SharedPreferences prefs) {
    final ms = prefs.getInt(lastKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Apakah sinkron otomatis layak jalan sekarang.
  static bool isDue(SharedPreferences prefs, {DateTime? now}) {
    if (!isEnabled(prefs)) return false;
    final last = lastRun(prefs);
    return last == null || (now ?? DateTime.now()).difference(last) >= minInterval;
  }

  /// Jalankan sinkron bila aktif dan sudah waktunya (atau [force]).
  /// Mengembalikan true bila sinkron benar-benar berjalan dan berhasil.
  Future<bool> maybeRun({bool force = false}) async {
    if (_running) return false;
    final prefs = _ref.read(sharedPreferencesProvider);
    if (!force && !isDue(prefs)) return false;
    _running = true;
    try {
      final cfg = await WebDavConfig.read(prefs);
      if (!cfg.configured) return false;
      await ProgressSync.run(prefs, library: _ref.read(sourceLibraryStoreProvider));
      await prefs.setInt(lastKey, DateTime.now().millisecondsSinceEpoch);
      _ref
        ..invalidate(sourceFavoritesProvider)
        ..invalidate(sourceHistoryProvider)
        ..invalidate(sourceProgressProvider);
      return true;
    } catch (e) {
      debugPrint('AutoSync: $e');
      return false;
    } finally {
      _running = false;
    }
  }
}

final autoSyncProvider = Provider<AutoSync>(AutoSync.new);
