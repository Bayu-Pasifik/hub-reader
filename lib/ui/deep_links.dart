import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Tautan aplikasi `hubreader://open/<lokasi rute>`.
///
/// Hanya halaman seri/novel dan reader yang boleh dibuka dari luar. Rute lain
/// (mis. `/webview?url=`, `/backup`, `/settings`) ditolak supaya tautan dari
/// aplikasi lain tidak bisa membuka WebView ke situs sembarang dengan cookie
/// aplikasi atau mengubah data.
abstract final class DeepLinks {
  static const scheme = 'hubreader';
  static const _host = 'open';

  static final _allowed = <RegExp, List<String>>{
    RegExp(r'^/source/[^/]+/manga$'): ['url'],
    RegExp(r'^/source/[^/]+/read$'): ['manga', 'chapter'],
    RegExp(r'^/novel/[^/]+/info$'): ['path'],
    RegExp(r'^/novel/[^/]+/read$'): ['novel', 'chapter'],
  };

  /// Lokasi rute (mis. hasil `sourceMangaLocation`) → tautan aplikasi.
  static String linkFor(String location) {
    final loc = Uri.parse(location);
    return Uri(scheme: scheme, host: _host, path: loc.path, queryParameters: loc.queryParameters.isEmpty ? null : loc.queryParameters)
        .toString();
  }

  /// Tautan masuk → lokasi rute yang aman, atau null bila tidak dikenal.
  static String? locationFor(Uri uri) {
    if (uri.scheme != scheme || uri.host != _host) return null;
    final path = uri.path;
    for (final e in _allowed.entries) {
      if (!e.key.hasMatch(path)) continue;
      final query = uri.queryParameters;
      // Parameter wajib harus ada; parameter lain dibuang.
      if (e.value.any((k) => (query[k] ?? '').isEmpty)) return null;
      return Uri(path: path, queryParameters: {for (final k in e.value) k: query[k]!}).toString();
    }
    return null;
  }

  static const _channel = MethodChannel('hub_reader/links');

  /// Dengarkan tautan: yang membuka aplikasi (sekali) dan yang datang saat
  /// aplikasi sudah berjalan. [onLocation] menerima lokasi rute yang aman.
  static Future<void> listen(void Function(String location) onLocation) async {
    void handle(Object? raw) {
      final uri = raw is String ? Uri.tryParse(raw) : null;
      final location = uri == null ? null : locationFor(uri);
      if (location != null) onLocation(location);
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'open') handle(call.arguments);
    });
    try {
      handle(await _channel.invokeMethod<String>('initial'));
    } on MissingPluginException {
      // bukan Android
    } on PlatformException catch (e) {
      debugPrint('DeepLinks.initial: $e');
    }
  }

  /// Bagikan judul + URL situs + tautan aplikasi lewat share sheet.
  static Future<void> share({required String title, String? webUrl, required String location}) async {
    final text = [
      title,
      if (webUrl != null && webUrl.startsWith('http')) webUrl,
      '',
      'Buka di Hub Reader: ${linkFor(location)}',
    ].join('\n');
    await SharePlus.instance.share(ShareParams(text: text, subject: title));
  }
}
