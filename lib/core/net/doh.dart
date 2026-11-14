import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Penyedia DNS-over-HTTPS (seperti opsi "DNS over HTTPS" di Mihon).
///
/// Banyak provider internet memblokir situs lewat DNS. Dengan DoH, nama situs
/// ditanyakan lewat HTTPS ke penyedia ini sehingga blokir DNS provider dilewati.
enum DohProvider {
  none('Mati (DNS sistem)', '', []),
  cloudflare('Cloudflare', 'https://cloudflare-dns.com/dns-query', ['1.1.1.1', '1.0.0.1']),
  google('Google', 'https://dns.google/resolve', ['8.8.8.8', '8.8.4.4']),
  adguard('AdGuard', 'https://dns.adguard-dns.com/resolve', ['94.140.14.14', '94.140.15.15']),
  dnsSb('DNS.SB', 'https://doh.dns.sb/dns-query', ['185.222.222.222', '45.11.45.11']),
  alidns('AliDNS', 'https://dns.alidns.com/resolve', ['223.5.5.5', '223.6.6.6']),
  dnspod('DNSPod', 'https://doh.pub/dns-query', ['1.12.12.12', '120.53.53.53']),
  cloudflareSecurity('Cloudflare (blokir malware)', 'https://security.cloudflare-dns.com/dns-query', ['1.1.1.2', '1.0.0.2']),
  cloudflareFamily('Cloudflare (keluarga)', 'https://family.cloudflare-dns.com/dns-query', ['1.1.1.3', '1.0.0.3']),
  adguardUnfiltered('AdGuard (tanpa filter)', 'https://unfiltered.adguard-dns.com/resolve', ['94.140.14.140', '94.140.14.141']);

  const DohProvider(this.label, this.url, this.bootstrap);

  final String label;
  final String url;

  /// IP penyedia, dipakai langsung agar tidak butuh DNS untuk menemukan DoH.
  final List<String> bootstrap;

  static const prefsKey = 'net.doh.v1';

  static DohProvider read(SharedPreferences p) =>
      DohProvider.values.where((d) => d.name == p.getString(prefsKey)).firstOrNull ?? DohProvider.none;
}

/// Mencari alamat IP lewat DoH (format JSON `application/dns-json`).
class DohResolver {
  DohResolver(this.provider);

  final DohProvider provider;
  final _cache = <String, ({List<InternetAddress> addrs, DateTime expires})>{};

  Future<List<InternetAddress>> lookup(String host) async {
    if (InternetAddress.tryParse(host) != null) return [InternetAddress(host)];
    final hit = _cache[host];
    if (hit != null && hit.expires.isAfter(DateTime.now())) return hit.addrs;

    final addrs = <InternetAddress>[];
    var ttl = 300;
    try {
      final results = await Future.wait([_query(host, 'A'), _query(host, 'AAAA')]);
      for (final r in results) {
        addrs.addAll(r.addrs);
        if (r.addrs.isNotEmpty && r.ttl < ttl) ttl = r.ttl;
      }
    } catch (e) {
      debugPrint('DoH lookup $host gagal: $e');
    }
    if (addrs.isEmpty) return [];
    // IPv4 dulu: jaringan tanpa IPv6 tidak menunggu timeout.
    addrs.sort((a, b) => a.type == b.type ? 0 : (a.type == InternetAddressType.IPv4 ? -1 : 1));
    _cache[host] = (addrs: addrs, expires: DateTime.now().add(Duration(seconds: ttl.clamp(30, 3600))));
    return addrs;
  }

  Future<({List<InternetAddress> addrs, int ttl})> _query(String host, String type) async {
    final uri = Uri.parse(provider.url).replace(queryParameters: {'name': host, 'type': type});
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    // Sambung ke IP bootstrap, TLS tetap memakai nama host penyedia.
    client.connectionFactory = (url, proxyHost, proxyPort) {
      final ip = InternetAddress(provider.bootstrap.first);
      return secureTask(Socket.startConnect(ip, url.port), url.host);
    };
    try {
      final req = await client.getUrl(uri);
      req.headers.set('accept', 'application/dns-json');
      final res = await req.close().timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return (addrs: <InternetAddress>[], ttl: 300);
      final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
      final wanted = type == 'A' ? 1 : 28;
      final out = <InternetAddress>[];
      var ttl = 300;
      for (final a in (body['Answer'] as List? ?? const [])) {
        if (a is! Map || a['type'] != wanted) continue;
        final ip = InternetAddress.tryParse('${a['data']}');
        if (ip == null) continue;
        out.add(ip);
        final t = a['TTL'];
        if (t is int && t < ttl) ttl = t;
      }
      return (addrs: out, ttl: ttl);
    } finally {
      client.close(force: true);
    }
  }
}

/// Memasang DoH ke semua HttpClient aplikasi (Dio, gambar, dll).
///
/// Terpasang sekali; resolver aktif dibaca saat tiap koneksi dibuat sehingga
/// pergantian penyedia langsung berlaku tanpa memulai ulang aplikasi.
class DohHttpOverrides extends HttpOverrides {
  DohHttpOverrides(this._previous);

  static DohResolver? active;

  final HttpOverrides? _previous;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = _previous?.createHttpClient(context) ?? super.createHttpClient(context);
    client.connectionFactory = (url, proxyHost, proxyPort) async {
      final viaProxy = proxyHost != null;
      final host = proxyHost ?? url.host;
      final port = proxyPort ?? url.port;
      var addrs = <InternetAddress>[];
      // Lewat proxy: biarkan proxy yang menyelesaikan nama.
      if (!viaProxy) {
        try {
          addrs = await active?.lookup(host) ?? [];
        } catch (_) {}
      }
      // DoH mati / gagal: DNS sistem.
      final plain = addrs.isEmpty ? Socket.startConnect(host, port) : _connectAny(addrs, port);
      // Dengan connectionFactory, HttpClient tidak menaikkan ke TLS sendiri.
      return !viaProxy && url.scheme == 'https' ? secureTask(plain, url.host, context) : await plain;
    };
    return client;
  }

  /// Coba tiap alamat bergantian sampai ada yang tersambung.
  Future<ConnectionTask<Socket>> _connectAny(List<InternetAddress> addrs, int port) async {
    final first = await Socket.startConnect(addrs.first, port);
    if (addrs.length == 1) return first;
    var cancelled = false;
    final socket = () async {
      try {
        return await first.socket;
      } catch (_) {
        for (final a in addrs.skip(1)) {
          if (cancelled) break;
          try {
            return await (await Socket.startConnect(a, port)).socket;
          } catch (_) {}
        }
        rethrow;
      }
    }();
    return ConnectionTask.fromSocket(socket, () {
      cancelled = true;
      first.cancel();
    });
  }
}

/// Naikkan koneksi TCP ke TLS memakai nama [host] (SNI & verifikasi sertifikat).
Future<ConnectionTask<Socket>> secureTask(
  Future<ConnectionTask<Socket>> plain,
  String host, [
  SecurityContext? context,
]) async {
  final task = await plain;
  final secured = task.socket.then<Socket>((s) => SecureSocket.secure(s, host: host, context: context));
  return ConnectionTask.fromSocket(secured, task.cancel);
}

/// Pasang / ganti / lepas DoH sesuai pilihan. Aman dipanggil berulang.
void applyDoh(DohProvider provider) {
  if (HttpOverrides.current is! DohHttpOverrides) {
    HttpOverrides.global = DohHttpOverrides(HttpOverrides.current);
  }
  DohHttpOverrides.active = provider == DohProvider.none ? null : DohResolver(provider);
}
