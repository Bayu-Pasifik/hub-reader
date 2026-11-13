import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

/// Rilis terbaru di GitHub.
class AppRelease {
  const AppRelease({required this.version, required this.tag, required this.page, required this.apk});

  /// Versi tanpa awalan "v", mis. "1.2.0".
  final String version;
  final String tag;
  final Uri page;

  /// APK yang dilampirkan CI (`hub-reader-<versi>.apk`).
  final Uri apk;
}

/// Cek pembaruan dari GitHub Releases.
///
/// Tidak memakai REST API (batas 60 request/jam per IP, sering habis di
/// jaringan bersama). `releases/latest` di github.com dialihkan ke
/// `releases/tag/<tag>`; tag dibaca dari header Location.
abstract final class AppUpdate {
  static const repo = 'Bayu-Pasifik/hub-reader';
  static const _channel = MethodChannel('hub_reader/links');

  static final _tagPath = RegExp(r'/releases/tag/([^/?#]+)/?$');

  /// Tag dari header Location; null bila belum ada rilis (dialihkan ke
  /// daftar rilis).
  static String? tagFromLocation(String? location) {
    if (location == null) return null;
    final match = _tagPath.firstMatch(Uri.tryParse(location)?.path ?? '');
    return match == null ? null : Uri.decodeComponent(match.group(1)!);
  }

  static AppRelease releaseFor(String tag) {
    final version = tag.startsWith(RegExp('[vV]')) ? tag.substring(1) : tag;
    return AppRelease(
      version: version,
      tag: tag,
      page: Uri.parse('https://github.com/$repo/releases/tag/${Uri.encodeComponent(tag)}'),
      apk: Uri.parse(
        'https://github.com/$repo/releases/download/${Uri.encodeComponent(tag)}/hub-reader-$version.apk',
      ),
    );
  }

  /// Bandingkan versi "1.2.3" (bagian build "+4" dan pra-rilis "-beta"
  /// diabaikan). Negatif bila [a] lebih lama.
  static int compare(String a, String b) {
    List<int> parts(String v) => v
        .replaceFirst(RegExp('^[vV]'), '')
        .split(RegExp('[+-]'))
        .first
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    final x = parts(a), y = parts(b);
    for (var i = 0; i < (x.length > y.length ? x.length : y.length); i++) {
      final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
      if (d != 0) return d;
    }
    return 0;
  }

  /// Rilis terbaru, atau null bila repo belum punya rilis.
  static Future<AppRelease?> latest({Dio? dio}) async {
    final client = dio ??
        Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));
    final res = await client.get<void>(
      'https://github.com/$repo/releases/latest',
      options: Options(
        followRedirects: false,
        validateStatus: (s) => s != null && s < 400,
        responseType: ResponseType.stream,
      ),
    );
    final tag = tagFromLocation(res.headers.value('location'));
    return tag == null ? null : releaseFor(tag);
  }

  /// versionName dari Android (sama dengan `version:` di pubspec).
  static Future<String?> currentVersion() async {
    try {
      return await _channel.invokeMethod<String>('appVersion');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Buka URL https di browser. false bila tidak ada aplikasi yang bisa.
  static Future<bool> open(Uri url) async {
    try {
      return await _channel.invokeMethod<bool>('openUrl', url.toString()) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
