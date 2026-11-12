import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/core/network/api_exception.dart';
import 'package:hub_reader/ui/widgets/state_views.dart';

// File ini sengaja dibuat agar `flutter create .` tidak menghasilkan
// widget_test.dart bawaan (yang mereferensikan MyApp dan gagal dikompilasi).
void main() {
  testWidgets('ErrorView shows Indonesian message for offline error', (tester) async {
    var retried = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ErrorView(
          error: const ApiException(ApiErrorKind.noConnection),
          onRetry: () => retried = true,
        ),
      ),
    ));

    expect(find.text('Tidak dapat terhubung ke server'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    expect(retried, isTrue);
  });
}
