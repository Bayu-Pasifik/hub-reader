import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/ui/widgets/novel_html.dart';

void main() {
  bool check(String html, String title) => startsWithTitle(parseNovelHtml(html), title);

  test('detects a chapter title repeated at the top of the content', () {
    expect(check('<h2>Chapter 1: The Start</h2><p>Text</p>', 'Chapter 1: The Start'), isTrue);
    expect(check('<p>Chapter 1 - The Start</p><p>Text</p>', 'Chapter 1: The Start'), isTrue);
    expect(check('<h1>Chapter 12</h1><p>Text</p>', 'Chapter 12: Judul Panjang'), isTrue);
    expect(check('<h3>Novel Name</h3><h2>Chapter 3</h2><p>x</p>', 'Chapter 3'), isTrue);
  });

  test('keeps the header when the content starts differently', () {
    expect(check('<h2>Bab 1: Pisau Pembongkar</h2><p>Text</p>', 'Volume 1 Chapter 1'), isFalse);
    expect(check('<p>It was a dark night.</p>', 'Chapter 1'), isFalse);
    expect(check('<h2>Chapter</h2><p>x</p>', 'Chapter 12: A very long chapter title here'), isFalse);
    expect(check('', 'Chapter 1'), isFalse);
  });
}
