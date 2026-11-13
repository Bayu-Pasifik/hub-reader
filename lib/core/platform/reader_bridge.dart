import 'dart:io';

import 'package:flutter/services.dart';

/// Fitur pembaca yang butuh kode Android (lihat MainActivity.kt):
/// layar tetap menyala dan tombol volume untuk menggulir.
class ReaderBridge {
  static const _channel = MethodChannel('hub_reader/reader');

  static void Function(bool down)? _onVolume;

  /// Tombol volume dicegat (tidak mengubah volume) selama [onVolume] diset;
  /// `down == true` untuk volume turun. Null = kembali normal.
  static Future<void> setVolumeKeys(void Function(bool down)? onVolume) async {
    _onVolume = onVolume;
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler(onVolume == null
        ? null
        : (call) async {
            if (call.method == 'volume') _onVolume?.call(call.arguments == 'down');
          });
    await _invoke('volumeKeys', onVolume != null);
  }

  static Future<void> setKeepScreenOn(bool on) async {
    if (!Platform.isAndroid) return;
    await _invoke('keepScreenOn', on);
  }

  static Future<void> _invoke(String method, Object? args) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on PlatformException {
      // fitur opsional
    } on MissingPluginException {
      // fitur opsional
    }
  }
}
