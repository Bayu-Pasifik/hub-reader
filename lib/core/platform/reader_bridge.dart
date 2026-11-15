import 'dart:io';

import 'package:flutter/services.dart';

import '../i18n/strings.dart';

/// Orientasi layar saat membaca.
enum ReaderOrientation {
  auto('Otomatis'),
  portrait('Potret'),
  landscape('Lanskap');

  const ReaderOrientation(this._label);

  final String _label;

  String get label => tr(_label);

  static ReaderOrientation byName(Object? name) =>
      ReaderOrientation.values.where((o) => o.name == name).firstOrNull ?? ReaderOrientation.auto;
}

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

  /// FLAG_SECURE: layar tidak bisa di-screenshot/direkam dan pratinjau di
  /// daftar aplikasi terbaru dikosongkan.
  static Future<void> setSecure(bool on) async {
    if (!Platform.isAndroid) return;
    await _invoke('secure', on);
  }

  /// Kecerahan jendela 0.05…1; 0 atau null = kembali ke kecerahan sistem.
  static Future<void> setBrightness(double? value) async {
    if (!Platform.isAndroid) return;
    await _invoke('brightness', (value == null || value <= 0) ? -1.0 : value.clamp(0.05, 1.0));
  }

  /// Kunci orientasi selama membaca; [ReaderOrientation.auto] mengembalikan ke pengaturan sistem.
  static Future<void> setOrientation(ReaderOrientation o) async {
    if (!Platform.isAndroid) return;
    await SystemChrome.setPreferredOrientations(switch (o) {
      ReaderOrientation.auto => const [],
      ReaderOrientation.portrait => const [DeviceOrientation.portraitUp],
      ReaderOrientation.landscape => const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
    });
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
