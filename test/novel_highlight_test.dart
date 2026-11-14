import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/novels/lookup.dart';
import 'package:hub_reader/ui/widgets/novel_html.dart';

void main() {
  test('tanpa sorotan: satu span utuh', () {
    final spans = highlightRuns('halo dunia', const [], const TextStyle());
    expect(spans.length, 1);
    expect(spans.single.text, 'halo dunia');
  });

  test('bagian yang cocok diberi latar, sisanya tidak', () {
    final spans = highlightRuns('halo dunia yang indah', const ['dunia'], const TextStyle());
    expect(spans.map((s) => s.text).toList(), ['halo ', 'dunia', ' yang indah']);
    expect(spans[0].style?.backgroundColor, isNull);
    expect(spans[1].style?.backgroundColor, isNotNull);
  });

  test('beberapa kemunculan dan beberapa sorotan', () {
    final spans = highlightRuns('aa bb aa', const ['aa', 'bb'], const TextStyle());
    expect(spans.map((s) => s.text).join(), 'aa bb aa');
    expect(spans.where((s) => s.style?.backgroundColor != null).map((s) => s.text).join(), 'aa bb aa'.replaceAll(' ', ''));
  });

  test('deteksi satu kata kamus', () {
    expect(TextLookup.isSingleWord('serendipity'), isTrue);
    expect(TextLookup.isSingleWord("don't"), isTrue);
    expect(TextLookup.isSingleWord('two words'), isFalse);
    expect(TextLookup.isSingleWord('漢字'), isFalse);
  });
}
