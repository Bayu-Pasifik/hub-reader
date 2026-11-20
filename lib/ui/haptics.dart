import 'package:flutter/services.dart';

/// Umpan balik getar kecil. Gagal diam-diam (mis. perangkat tanpa motor getar).
abstract final class Haptics {
  /// Pilihan ringan: ganti tab, buka menu.
  static void tick() => _run(HapticFeedback.selectionClick);

  /// Aksi sukses/penanda: tambah favorit, tekan lama kartu.
  static void tap() => _run(HapticFeedback.lightImpact);

  /// Aksi destruktif atau batas: hapus, urungkan.
  static void thud() => _run(HapticFeedback.mediumImpact);

  static void _run(Future<void> Function() f) {
    try {
      f();
    } on Object {
      // opsional
    }
  }
}
