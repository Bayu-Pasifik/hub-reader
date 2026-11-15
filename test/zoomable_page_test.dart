import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/state/reader_settings_provider.dart';
import 'package:hub_reader/ui/widgets/zoomable_page.dart';

void main() {
  testWidgets('ketuk dua kali memperbesar lalu mengembalikan ke 1x', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SizedBox(width: 400, height: 800, child: ZoomablePage(child: ColoredBox(color: Colors.red))),
    ));
    final viewer = find.byType(InteractiveViewer);
    double scale() => tester.widget<InteractiveViewer>(viewer).transformationController!.value.getMaxScaleOnAxis();
    expect(scale(), 1);

    await tester.tapAt(const Offset(300, 200));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(300, 200));
    await tester.pumpAndSettle();
    expect(scale(), closeTo(2.5, 0.01));

    await tester.tapAt(const Offset(300, 200));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(300, 200));
    await tester.pumpAndSettle();
    expect(scale(), 1);
  });

  test('titik ketuk tetap berada di bawah jari saat zoom', () {
    final m = zoomTarget(Matrix4.identity(), const Offset(300, 200), 2.5);
    final p = MatrixUtils.transformPoint(m, const Offset(300, 200));
    expect(p.dx, closeTo(300, 0.001));
    expect(p.dy, closeTo(200, 0.001));
  });

  testWidgets('tanpa zoom ketuk dua kali, skala tetap 1', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SizedBox(
          width: 400, height: 800, child: ZoomablePage(doubleTapZoom: false, child: ColoredBox(color: Colors.red))),
    ));
    await tester.tapAt(const Offset(300, 200));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(300, 200));
    await tester.pumpAndSettle();
    final viewer = find.byType(InteractiveViewer);
    expect(tester.widget<InteractiveViewer>(viewer).transformationController!.value.getMaxScaleOnAxis(), 1);
  });

  test('ReaderDisplay menyimpan zoom, kecerahan, dan pra-muat', () {
    const d = ReaderDisplay(doubleTapZoom: false, brightness: 0.4, preload: 5);
    final back = ReaderDisplay.fromJson(Map<String, Object?>.from(d.toJson()));
    expect(back, d);
    final old = ReaderDisplay.fromJson({'crop': true}); // data lama tanpa kunci baru
    expect([old.doubleTapZoom, old.brightness, old.preload], [true, 0, 2]);
    expect(ReaderDisplay.fromJson({'preload': 99, 'bright': 5}).preload, 6);
  });
}
