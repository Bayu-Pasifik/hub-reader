import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/ui/widgets/novel_html.dart';

TextBlock tb(String text) => TextBlock([InlineRun(text)]);

void main() {
  group('searchBlocks', () {
    final blocks = <NovelBlock>[
      tb('Kucing itu tidur. Kucing lain bangun.'),
      const RuleBlock(),
      const ImageBlock('x.png'),
      TextBlock([InlineRun('Si '), InlineRun('KUCING', bold: true), InlineRun(' hitam')]),
      tb('Anjing menggonggong.'),
    ];

    test('tanpa membedakan huruf besar/kecil, urut dari awal bab', () {
      final m = searchBlocks(blocks, 'kucing');
      expect(m.map((e) => (e.block, e.start, e.end)).toList(), [(0, 0, 6), (0, 18, 24), (3, 3, 9)]);
    });

    test('hasil melintasi run bergaya berbeda (teks polos blok)', () {
      expect(searchBlocks(blocks, 'si kucing hitam').single.block, 3);
    });

    test('query kosong / spasi / tidak ada = kosong; blok non-teks dilewati', () {
      expect(searchBlocks(blocks, ''), isEmpty);
      expect(searchBlocks(blocks, '   '), isEmpty);
      expect(searchBlocks(blocks, 'harimau'), isEmpty);
    });

    test('karakter regex diperlakukan sebagai teks biasa', () {
      final b = [tb('harga (Rp.5.000)? [ok] a+b')];
      expect(searchBlocks(b, '(Rp.5').length, 1);
      expect(searchBlocks(b, '?').length, 1);
      expect(searchBlocks(b, '[ok]').length, 1);
      expect(searchBlocks(b, 'a+b').length, 1);
      expect(searchBlocks(b, '.*'), isEmpty);
    });

    test('huruf non-ASCII (unicode)', () {
      expect(searchBlocks([tb('Ünïcode ÉCOLE école')], 'école').length, 2);
    });

    test('dibatasi $maxChapterMatches hasil', () {
      final big = [tb('a ' * 2000)];
      expect(searchBlocks(big, 'a').length, maxChapterMatches);
    });
  });

  group('applySearchMarks', () {
    List<(String, Color?)> flat(List<TextSpan> s) => [for (final x in s) (x.text!, x.style?.backgroundColor)];
    const hl = Color(0x66FFEB3B);
    const cur = Color(0xAAFF9800);

    test('tanpa tanda: span tidak berubah', () {
      final spans = [const TextSpan(text: 'halo dunia')];
      expect(identical(applySearchMarks(spans, 0, const []), spans), isTrue);
    });

    test('memotong span di batas tanda dan membedakan hasil terpilih', () {
      final out = applySearchMarks(
        [const TextSpan(text: 'ab kucing cd kucing')],
        0,
        [(start: 3, end: 9, current: false), (start: 13, end: 19, current: true)],
      );
      expect(flat(out), [('ab ', null), ('kucing', hl), (' cd ', null), ('kucing', cur)]);
      expect(out.map((e) => e.text).join(), 'ab kucing cd kucing'); // teks utuh
    });

    test('tanda yang melintasi dua run memakai offset run', () {
      // Teks polos: "Si KUCING hitam"; tanda 3..9 jatuh seluruhnya di run ke-2 (offset 3).
      final run2 = applySearchMarks([const TextSpan(text: 'KUCING', style: TextStyle(fontWeight: FontWeight.w700))], 3, [(start: 3, end: 9, current: true)]);
      expect(flat(run2), [('KUCING', cur)]);
      expect(run2.single.style!.fontWeight, FontWeight.w700); // gaya asli dipertahankan
      // Tanda 1..5 memotong run1 ("Si ", 0..3) dan run2 ("KUCING", 3..9).
      final m = [(start: 1, end: 5, current: false)];
      expect(flat(applySearchMarks([const TextSpan(text: 'Si ')], 0, m)), [('S', null), ('i ', hl)]);
      expect(flat(applySearchMarks([const TextSpan(text: 'KUCING')], 3, m)), [('KU', hl), ('CING', null)]);
    });

    test('tanda di luar span diabaikan', () {
      final out = applySearchMarks([const TextSpan(text: 'abc')], 10, [(start: 0, end: 5, current: false)]);
      expect(flat(out), [('abc', null)]);
    });
  });
}
