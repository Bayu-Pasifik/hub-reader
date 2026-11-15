import 'dart:io';

import 'package:flutter/services.dart';

/// Status jaringan dari Android (lihat MainActivity.kt).
class NetworkBridge {
  static const _channel = MethodChannel('hub_reader/network');

  /// Hanya untuk tes.
  static Future<bool> Function()? debugOverride;

  /// True bila jaringan aktif tanpa kuota (Wi-Fi/ethernet). Di luar Android
  /// dianggap true. Bila status tidak terbaca (mis. isolate latar tanpa
  /// channel) hasilnya false, supaya opsi "hanya Wi-Fi" tidak bocor ke data
  /// seluler; antrean dilanjutkan saat aplikasi dibuka.
  static Future<bool> isUnmetered() async {
    final override = debugOverride;
    if (override != null) return override();
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('unmetered') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
