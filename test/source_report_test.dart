import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/sources/source_exception.dart';
import 'package:hub_reader/sources/source_report.dart';

void main() {
  const target = (name: 'Komiku', id: 'id.komiku', baseUrl: 'https://komiku.org');

  test('hanya error sumber yang layak dilaporkan, bukan masalah jaringan pengguna', () {
    expect(isReportable(SourceErrorKind.parse), isTrue);
    expect(isReportable(SourceErrorKind.notFound), isTrue);
    expect(isReportable(SourceErrorKind.server), isTrue);
    expect(isReportable(SourceErrorKind.unknown), isTrue);
    for (final k in [SourceErrorKind.noConnection, SourceErrorKind.timeout, SourceErrorKind.cloudflare, SourceErrorKind.rateLimited]) {
      expect(isReportable(k), isFalse, reason: k.name);
    }
  });

  test('tautan isu GitHub terisi dan hanya memuat data sumber', () {
    final e = const SourceException(SourceErrorKind.parse, statusCode: 200, detail: 'selector\n  .list tidak ditemukan');
    final uri = buildSourceReportUri(target, e, appVersion: '1.3.1');
    expect(uri.scheme, 'https');
    expect(uri.host, 'github.com');
    expect(uri.path, '/Bayu-Pasifik/hub-reader/issues/new');
    expect(uri.queryParameters['title'], '[Sumber rusak] Komiku: parse (HTTP 200)');
    final body = uri.queryParameters['body']!;
    expect(body, contains('**Sumber:** Komiku (`id.komiku`)'));
    expect(body, contains('**Domain:** https://komiku.org'));
    expect(body, contains('**Versi aplikasi:** 1.3.1'));
    expect(body, contains('**Detail:** selector .list tidak ditemukan')); // spasi dirapikan
  });

  test('detail panjang dipotong dan versi tidak diketahui ditulis jelas', () {
    final e = SourceException(SourceErrorKind.server, detail: 'x' * 1000);
    final uri = buildSourceReportUri(target, e);
    final body = uri.queryParameters['body']!;
    expect(body, contains('tidak diketahui'));
    expect(body.length, lessThan(900));
    expect(body, contains('…'));
  });

  test('karakter khusus di nama sumber tidak merusak URL', () {
    final uri = buildSourceReportUri((name: 'A&B #1 ?', id: 'x', baseUrl: 'https://a.b'), const SourceException(SourceErrorKind.parse));
    expect(Uri.parse(uri.toString()).queryParameters['title'], contains('A&B #1 ?'));
  });
}
