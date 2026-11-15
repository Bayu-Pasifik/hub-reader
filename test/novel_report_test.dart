import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/novels/novel_models.dart';
import 'package:hub_reader/novels/novel_source.dart';
import 'package:hub_reader/sources/source_exception.dart';
import 'package:hub_reader/sources/source_report.dart';
import 'package:hub_reader/ui/widgets/source_widgets.dart';

void main() {
  const info = NovelPluginInfo(
    id: 'IDWN.id',
    name: 'IDWebNovel',
    site: 'https://idwebnovel.example',
    lang: 'id',
    version: '1.2.3',
    url: 'https://x/plugin.js',
  );

  test('target laporan plugin memuat id dan versi plugin', () {
    final t = novelInfoReportTarget(info)!;
    expect(t.name, 'IDWebNovel');
    expect(t.id, 'lnr:IDWN.id v1.2.3');
    expect(t.baseUrl, 'https://idwebnovel.example');
  });

  test('tanpa data plugin tidak ada target', () {
    expect(novelInfoReportTarget(null), isNull);
    expect(novelReportTarget(null), isNull);
  });

  test('isu GitHub berisi nama, id plugin, versi, dan domain', () {
    final uri = buildSourceReportUri(
      novelInfoReportTarget(info)!,
      const SourceException(SourceErrorKind.parse, detail: 'popularNovels gagal'),
      appVersion: '1.4.0',
      repo: 'owner/repo',
    );
    expect(uri.host, 'github.com');
    expect(uri.path, '/owner/repo/issues/new');
    final body = uri.queryParameters['body']!;
    expect(body, contains('lnr:IDWN.id v1.2.3'));
    expect(body, contains('https://idwebnovel.example'));
    expect(uri.queryParameters['title'], contains('IDWebNovel'));
  });

  Widget host(Object error, SourceReportTarget? target) => MaterialApp(
        home: Scaffold(body: SourceErrorView(error: error, reportSource: target)),
      );

  testWidgets('error plugin (TypeError di JS) menampilkan tombol lapor untuk plugin novel', (tester) async {
    final error = novelError(Exception("TypeError: Cannot read property 'text' of undefined"));
    expect(error.kind, SourceErrorKind.parse);
    await tester.pumpWidget(host(error, novelInfoReportTarget(info)));
    expect(find.text('Laporkan sumber ini'), findsOneWidget);
  });

  testWidgets('error koneksi plugin tidak menampilkan tombol lapor', (tester) async {
    await tester.pumpWidget(host(novelError(Exception('Network request failed')), novelInfoReportTarget(info)));
    expect(find.text('Laporkan sumber ini'), findsNothing);
  });

  testWidgets('sumber lokal (tanpa target) tidak menampilkan tombol lapor', (tester) async {
    await tester.pumpWidget(host(novelError(Exception('TypeError: x is undefined')), null));
    expect(find.text('Laporkan sumber ini'), findsNothing);
  });
}
