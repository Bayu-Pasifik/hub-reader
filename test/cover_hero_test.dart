import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/ui/widgets/cover_hero.dart';
import 'package:hub_reader/ui/widgets/source_widgets.dart';

void main() {
  test('tag Hero sama di daftar dan detail, berbeda antar sumber dan seri', () {
    expect(coverHeroTag('id.komiku', '/manga/a/'), coverHeroTag('id.komiku', '/manga/a/'));
    expect(coverHeroTag('id.komiku', '/manga/a/'), isNot(coverHeroTag('id.komiku', '/manga/b/')));
    expect(coverHeroTag('id.komiku', '/manga/a/'), isNot(coverHeroTag('lnr:x', '/manga/a/')));
  });

  test('item ganda di satu daftar: hanya kemunculan pertama yang diberi tag', () {
    final urls = ['/a', '/b', '/a', '/c', '/b', '/a'];
    final tags = [for (var i = 0; i < urls.length; i++) coverHeroTagAt(urls, i, 's', (u) => u)];
    expect(tags, [coverHeroTag('s', '/a'), coverHeroTag('s', '/b'), null, coverHeroTag('s', '/c'), null, null]);
    expect(tags.whereType<String>().toSet().length, tags.whereType<String>().length); // tanpa duplikat
  });

  testWidgets('sampul terbang dari daftar ke header detail (dua Hero bertag sama selama transisi)', (tester) async {
    final tag = coverHeroTag('s', '/a');
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SeriesPreviewHeader(
                    preview: const SeriesPreview(title: 'Seri A'),
                    heroTag: tag,
                    headers: const {},
                  ),
                ),
              ),
            )),
            child: Align(
              alignment: Alignment.bottomRight,
              child: SourceCover(url: null, headers: const {}, width: 100, heroTag: tag),
            ),
          ),
        ),
      ),
    ));
    expect(find.byType(Hero), findsOneWidget);
    final before = tester.getCenter(find.byType(Hero));

    await tester.tap(find.byType(SourceCover));
    await tester.pump(); // mulai transisi
    await tester.pump(const Duration(milliseconds: 150)); // di tengah penerbangan
    // Selama penerbangan, sampul berada di antara posisi daftar dan header detail.
    final overlay = find.descendant(of: find.byType(Overlay), matching: find.byType(SourceCover));
    expect(overlay, findsWidgets);
    final mid = tester.getCenter(overlay.last);
    expect(mid, isNot(before));

    await tester.pumpAndSettle();
    expect(find.text('Seri A'), findsOneWidget);
    // Akhirnya sampul ada di header detail (kiri atas), bukan di pojok kanan bawah.
    final end = tester.getCenter(find.byType(SourceCover).last);
    expect(end.dx, lessThan(before.dx));
    expect(end.dy, lessThan(before.dy));
  });
}
