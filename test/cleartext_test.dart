import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/core/net/cleartext.dart';
import 'package:hub_reader/sources/html_utils.dart';

void main() {
  test('HTTP hanya diizinkan untuk jaringan lokal', () {
    for (final ok in ['https://komiku.id/', 'http://192.168.1.5:25600/opds', 'http://10.0.0.2/', 'http://localhost:8080/', 'http://nas.local/', 'http://nas/', 'http://172.20.1.1/']) {
      expect(isCleartextAllowed(Uri.parse(ok)), isTrue, reason: ok);
    }
    for (final bad in ['http://komiku.id/', 'http://8.8.8.8/', 'http://172.32.0.1/', 'http://example.com:8080/x']) {
      expect(isCleartextAllowed(Uri.parse(bad)), isFalse, reason: bad);
    }
  });

  test('upgradeCleartext menaikkan host publik ke https dan membuang port 80', () {
    expect(upgradeCleartext(Uri.parse('http://a.com/x?y=1')).toString(), 'https://a.com/x?y=1');
    expect(upgradeCleartext(Uri.parse('http://a.com:80/x')).toString(), 'https://a.com/x');
    expect(upgradeCleartext(Uri.parse('http://a.com:8080/x')).toString(), 'https://a.com:8080/x');
    expect(upgradeCleartext(Uri.parse('http://192.168.1.2/x')).toString(), 'http://192.168.1.2/x');
  });

  test('absUrl menaikkan gambar http ke https', () {
    expect(absUrl(Uri.parse('https://a.com/m/'), 'http://cdn.a.com/1.jpg'), 'https://cdn.a.com/1.jpg');
    expect(absUrl(Uri.parse('https://a.com/m/'), '/p/1.jpg'), 'https://a.com/p/1.jpg');
  });

  test('Dio opsional tidak terpengaruh (sanity)', () {
    expect(Uri.parse('http://x.com').scheme, 'http');
    expect(Dio().options.baseUrl, '');
  });
}
