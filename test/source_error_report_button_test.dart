import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/sources/source_exception.dart';
import 'package:hub_reader/ui/widgets/source_widgets.dart';

Widget host(Object error, {bool withReport = true}) => MaterialApp(
      home: Scaffold(
        body: SourceErrorView(
          error: error,
          reportSource: withReport ? (name: 'Komiku', id: 'id.komiku', baseUrl: 'https://komiku.org') : null,
        ),
      ),
    );

void main() {
  testWidgets('error parse menampilkan tombol lapor', (tester) async {
    await tester.pumpWidget(host(const SourceException(SourceErrorKind.parse)));
    expect(find.text('Laporkan sumber ini'), findsOneWidget);
  });

  testWidgets('error jaringan pengguna tidak menampilkan tombol lapor', (tester) async {
    for (final k in [SourceErrorKind.noConnection, SourceErrorKind.timeout, SourceErrorKind.cloudflare]) {
      await tester.pumpWidget(host(SourceException(k)));
      expect(find.text('Laporkan sumber ini'), findsNothing, reason: k.name);
    }
  });

  testWidgets('tanpa sumber (mis. novel) tidak ada tombol lapor', (tester) async {
    await tester.pumpWidget(host(const SourceException(SourceErrorKind.parse), withReport: false));
    expect(find.text('Laporkan sumber ini'), findsNothing);
  });
}
