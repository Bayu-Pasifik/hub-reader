import 'dart:io';

import 'package:flutter/services.dart';

/// Simpan gambar ke galeri (Pictures/Hub Reader) lewat MediaStore (lihat MainActivity.kt).
class MediaBridge {
  static const _channel = MethodChannel('hub_reader/media');

  /// Mengembalikan URI hasil simpan, atau null bila tidak didukung (Android 9 ke bawah;
  /// pemanggil lalu memakai dialog simpan sistem) atau gagal.
  static Future<String?> saveImage(Uint8List bytes, String name, String mime) async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('saveImage', {'bytes': bytes, 'name': name, 'mime': mime});
    } on MissingPluginException {
      return null;
    }
  }
}
