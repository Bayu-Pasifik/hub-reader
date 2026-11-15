import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/ui/widgets/page_actions.dart';

void main() {
  test('sniffImage mengenali PNG, JPEG, GIF, WebP', () {
    expect(sniffImage([0x89, 0x50, 0x4E, 0x47, 0, 0]).ext, 'png');
    expect(sniffImage([0xFF, 0xD8, 0xFF, 0xE0]).ext, 'jpg');
    expect(sniffImage([0x47, 0x49, 0x46, 0x38]).ext, 'gif');
    final webp = [0x52, 0x49, 0x46, 0x46, 1, 2, 3, 4, 0x57, 0x45, 0x42, 0x50];
    expect(sniffImage(webp), (ext: 'webp', mime: 'image/webp'));
  });

  test('sniffImage: byte kosong atau tak dikenal dianggap JPEG', () {
    expect(sniffImage(const []).mime, 'image/jpeg');
    expect(sniffImage([1, 2, 3]).ext, 'jpg');
  });

  test('pageFileName membuang karakter terlarang dan memberi nomor 3 digit', () {
    expect(pageFileName('Chapter 12: "Final"/Part?', 3, 'png'), 'Chapter 12 Final Part_p003.png');
    expect(pageFileName('', 12, 'jpg'), 'page_p012.jpg');
  });

  test('pageFileName memotong nama yang sangat panjang', () {
    final name = pageFileName('a' * 200, 1, 'jpg');
    expect(name.length, lessThanOrEqualTo(80 + '_p001.jpg'.length));
  });
}
