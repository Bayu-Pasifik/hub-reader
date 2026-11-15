import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Log error lokal: kesalahan Flutter dan error async yang tidak tertangkap
/// ditulis ke `crash.log` di penyimpanan aplikasi. Tidak ada yang dikirim ke
/// jaringan; pengguna bisa melihat, membagikan, atau menghapusnya sendiri.
class CrashLog {
  CrashLog._();

  /// Batas ukuran berkas; bila lewat, separuh terlama dibuang.
  static const maxBytes = 128 * 1024;

  static File? _file;

  static File? get file => _file;

  /// Pasang pengait error. [dir] hanya untuk tes.
  static Future<void> install({Directory? dir}) async {
    dir ??= await getApplicationSupportDirectory();
    _file = File('${dir.path}${Platform.pathSeparator}crash.log');

    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      record(details.exception, details.stack, context: details.context?.toDescription());
      if (previous != null) {
        previous(details);
      } else {
        FlutterError.presentError(details);
      }
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      record(error, stack);
      return true; // sudah dicatat; jangan matikan aplikasi
    };
  }

  /// Tambahkan satu entri. Tidak pernah melempar.
  static void record(Object error, StackTrace? stack, {String? context, DateTime? now}) {
    final f = _file;
    if (f == null) return;
    try {
      final t = (now ?? DateTime.now()).toIso8601String();
      final entry = StringBuffer('[$t]')
        ..write(context == null ? '' : ' $context')
        ..writeln()
        ..writeln(error)
        ..writeln(stack ?? '')
        ..writeln('---');
      f.writeAsStringSync(entry.toString(), mode: FileMode.append, flush: true);
      if (f.lengthSync() > maxBytes) {
        final text = f.readAsStringSync();
        final cut = text.indexOf('---\n', text.length ~/ 2);
        f.writeAsStringSync(cut < 0 ? '' : text.substring(cut + 4));
      }
    } on Object {
      // Pencatat tidak boleh jadi sumber error baru.
    }
  }

  static String read() {
    try {
      final f = _file;
      return f != null && f.existsSync() ? f.readAsStringSync() : '';
    } on Object {
      return '';
    }
  }

  static void clear() {
    try {
      final f = _file;
      if (f != null && f.existsSync()) f.deleteSync();
    } on Object {
      // abaikan
    }
  }
}
