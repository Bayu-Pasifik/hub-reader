import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/ui/widgets/state_views.dart';

// File ini sengaja dibuat agar `flutter create .` tidak menghasilkan
// widget_test.dart bawaan (yang mereferensikan MyApp dan gagal dikompilasi).
void main() {
  testWidgets('EmptyView shows title, message and action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EmptyView(
          title: 'Kosong',
          message: 'Belum ada apa-apa',
          action: TextButton(onPressed: () => tapped = true, child: const Text('Tambah')),
        ),
      ),
    ));

    expect(find.text('Kosong'), findsOneWidget);
    expect(find.text('Belum ada apa-apa'), findsOneWidget);
    await tester.tap(find.text('Tambah'));
    expect(tapped, isTrue);
  });
}
