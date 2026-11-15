import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/core/net/doh.dart';
import 'package:hub_reader/core/net/proxy.dart';

void main() {
  group('ProxyConfig.tryParse', () {
    test('host:port valid, awalan http:// dan garis miring akhir diabaikan', () {
      expect(ProxyConfig.tryParse('192.168.1.5:8080'), const ProxyConfig(host: '192.168.1.5', port: 8080));
      expect(ProxyConfig.tryParse(' http://proxy.local:3128/ '), const ProxyConfig(host: 'proxy.local', port: 3128));
      expect(ProxyConfig.tryParse('localhost:1'), isNotNull);
    });
    test('yang tidak valid ditolak', () {
      for (final bad in [null, '', 'host', 'host:', ':8080', 'host:0', 'host:70000', 'host:abc', 'a b:80', 'u:p@host:80', 'host:80/x']) {
        expect(ProxyConfig.tryParse(bad), isNull, reason: '$bad');
      }
    });
  });

  group('ProxyRoute.find', () {
    tearDown(() => ProxyRoute.active = null);

    test('host publik lewat proxy, host lokal langsung', () {
      ProxyRoute.active = const ProxyConfig(host: '10.0.0.9', port: 8080);
      expect(ProxyRoute.find(Uri.parse('https://komiku.org/x')), 'PROXY 10.0.0.9:8080');
      expect(ProxyRoute.find(Uri.parse('http://192.168.1.5:25600/opds')), isNot(contains('PROXY 10.0.0.9')));
      expect(ProxyRoute.find(Uri.parse('http://localhost:8080/')), isNot(contains('PROXY 10.0.0.9')));
      expect(ProxyRoute.find(Uri.parse('http://nas.local/')), isNot(contains('PROXY 10.0.0.9')));
    });

    test('tanpa proxy: ikut lingkungan (bukan proxy aplikasi)', () {
      ProxyRoute.active = null;
      expect(ProxyRoute.find(Uri.parse('https://komiku.org/x')), isNot(contains('10.0.0.9')));
    });
  });

  group('lewat HttpClient sungguhan', () {
    late HttpServer fakeProxy;
    final seen = <String>[];

    setUp(() async {
      seen.clear();
      fakeProxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      fakeProxy.listen((req) {
        seen.add('${req.method} ${req.requestedUri}');
        req.response
          ..write('via-proxy')
          ..close();
      });
    });
    tearDown(() async {
      ProxyRoute.active = null;
      await fakeProxy.close(force: true);
    });

    test('permintaan http ke host publik dikirim ke proxy dengan URL penuh', () async {
      // Host tujuan publik (tidak perlu ada): proxy palsu yang menjawab.
      ProxyRoute.active = ProxyConfig(host: '127.0.0.1', port: fakeProxy.port);
      await HttpOverrides.runWithHttpOverrides(() async {
        final client = HttpClient();
        final req = await client.getUrl(Uri.parse('http://komik-publik.example/seri?x=1'));
        final res = await req.close();
        final body = await res.transform(const SystemEncoding().decoder).join();
        expect(body, 'via-proxy');
        client.close();
      }, DohHttpOverrides(null));
      expect(seen.single, 'GET http://komik-publik.example/seri?x=1');
    });

    test('permintaan https memakai CONNECT ke proxy', () async {
      final connects = Completer<String>();
      await fakeProxy.close(force: true);
      final raw = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      raw.listen((s) {
        s.listen((data) {
          if (!connects.isCompleted) connects.complete(String.fromCharCodes(data).split('\r\n').first);
          s.destroy(); // tidak melanjutkan TLS
        }, onError: (_) {});
      });
      ProxyRoute.active = ProxyConfig(host: '127.0.0.1', port: raw.port);
      await HttpOverrides.runWithHttpOverrides(() async {
        final client = HttpClient();
        try {
          final req = await client.getUrl(Uri.parse('https://komik-publik.example/seri'));
          await req.close();
        } catch (_) {
          // diharapkan gagal: proxy palsu menutup koneksi
        }
        client.close(force: true);
      }, DohHttpOverrides(null));
      expect(await connects.future.timeout(const Duration(seconds: 5)), 'CONNECT komik-publik.example:443 HTTP/1.1');
      await raw.close();
    });

    test('host lokal tidak dikirim lewat proxy', () async {
      ProxyRoute.active = const ProxyConfig(host: '127.0.0.1', port: 1); // proxy mati: pasti gagal bila dipakai
      final local = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      local.listen((r) => r.response
        ..write('langsung')
        ..close());
      addTearDown(() => local.close(force: true));
      await HttpOverrides.runWithHttpOverrides(() async {
        final client = HttpClient();
        final res = await (await client.getUrl(Uri.parse('http://127.0.0.1:${local.port}/'))).close();
        expect(await res.transform(const SystemEncoding().decoder).join(), 'langsung');
        client.close();
      }, DohHttpOverrides(null));
    });
  });
}
