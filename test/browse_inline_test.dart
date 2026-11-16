import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/state/browse_layout_provider.dart';
import 'package:hub_reader/ui/widgets/browse_layout.dart';

void main() {
  final items = [
    for (var i = 0; i < 5; i++) BrowseItem(title: 'Judul $i', cover: null, onTap: () {}),
  ];

  for (final display in BrowseDisplay.values) {
    for (final columns in const [0, 3]) {
      testWidgets('BrowseInline tampil tanpa error: ${display.name}, kolom $columns', (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BrowseInline(layout: (display: display, columns: columns), items: items, headers: const {}),
            ),
          ),
        ));
        expect(tester.takeException(), isNull);
        // Mode sampul saja tidak menampilkan judul.
        if (display != BrowseDisplay.coverOnly) expect(find.text('Judul 0'), findsOneWidget);
      });
    }
  }
}
