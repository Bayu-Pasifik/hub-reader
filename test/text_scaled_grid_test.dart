import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/ui/widgets/layout.dart';

Future<Size> firstCell(WidgetTester tester, SliverGridDelegate delegate, {double width = 400}) async {
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: width,
        height: 800,
        child: CustomScrollView(slivers: [
          SliverGrid.builder(
            gridDelegate: delegate,
            itemCount: 4,
            itemBuilder: (_, i) => Container(key: ValueKey('cell$i')),
          ),
        ]),
      ),
    ),
  ));
  return tester.getSize(find.byKey(const ValueKey('cell0')));
}

void main() {
  testWidgets('skala 1x: ukuran sel sama dengan grid lama (MaxCrossAxisExtent + rasio)', (tester) async {
    for (final width in [360.0, 400.0, 600.0, 900.0]) {
      final old = await firstCell(
        tester,
        const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 160,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.56,
        ),
        width: width,
      );
      final scaled = await firstCell(tester, const TextScaledGridDelegate(), width: width);
      expect(scaled.width, closeTo(old.width, 0.01), reason: 'lebar @$width');
      expect(scaled.height, closeTo(old.height, 0.01), reason: 'tinggi @$width');
    }
  });

  testWidgets('skala 2x: sel lebih tinggi sebesar blok teks, lebar tetap', (tester) async {
    final one = await firstCell(tester, const TextScaledGridDelegate(textScale: 1));
    final two = await firstCell(tester, const TextScaledGridDelegate(textScale: 2));
    expect(two.width, one.width);
    expect(two.height - one.height, closeTo(62, 0.01));
  });

  testWidgets('skala di bawah 1 tidak memperkecil sel; skala ekstrem dibatasi 3x', (tester) async {
    final one = await firstCell(tester, const TextScaledGridDelegate(textScale: 1));
    expect((await firstCell(tester, const TextScaledGridDelegate(textScale: 0.5))).height, one.height);
    final three = await firstCell(tester, const TextScaledGridDelegate(textScale: 3));
    expect((await firstCell(tester, const TextScaledGridDelegate(textScale: 10))).height, three.height);
  });
}
