import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'cleartext.dart';

/// Proxy HTTP (CONNECT) untuk semua koneksi aplikasi: sumber komik, gambar,
/// plugin novel, tracker. Tidak mendukung SOCKS maupun login proxy.
///
/// Host jaringan lokal (localhost, IP privat, `.local`) selalu langsung, jadi
/// server OPDS/WebDAV di LAN tetap terjangkau. WebView (verifikasi
/// Cloudflare) tidak lewat proxy ini.
class ProxyConfig {
  const ProxyConfig({required this.host, required this.port});

  final String host;
  final int port;

  static const prefsKey = 'net.proxy.v1';

  /// "host:port" → config; null bila tidak valid. Awalan `http://` diabaikan.
  static ProxyConfig? tryParse(String? input) {
    var s = (input ?? '').trim();
    if (s.isEmpty) return null;
    s = s.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '').replaceFirst(RegExp(r'/+$'), '');
    final i = s.lastIndexOf(':');
    if (i <= 0 || i == s.length - 1) return null;
    final host = s.substring(0, i);
    final port = int.tryParse(s.substring(i + 1));
    if (port == null || port < 1 || port > 65535) return null;
    // Host harus nama/IP biasa (tanpa spasi, path, atau kredensial).
    if (!RegExp(r'^[A-Za-z0-9.\-]+$').hasMatch(host)) return null;
    return ProxyConfig(host: host, port: port);
  }

  @override
  String toString() => '$host:$port';

  @override
  bool operator ==(Object other) => other is ProxyConfig && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);

  static ProxyConfig? read(SharedPreferences prefs) => tryParse(prefs.getString(prefsKey));

  static Future<void> write(SharedPreferences prefs, ProxyConfig? config) =>
      config == null ? prefs.remove(prefsKey) : prefs.setString(prefsKey, config.toString());
}

/// Proxy yang sedang aktif; dibaca tiap koneksi dibuat, jadi perubahan
/// langsung berlaku tanpa memulai ulang aplikasi.
abstract final class ProxyRoute {
  static ProxyConfig? active;

  /// Nilai `HttpClient.findProxy`: lewat proxy, kecuali ke host lokal.
  static String find(Uri uri) {
    final p = active;
    if (p == null || isLocalHost(uri.host)) return HttpClient.findProxyFromEnvironment(uri);
    return 'PROXY ${p.host}:${p.port}';
  }
}
