import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/core/net/image_cache.dart';

ImageCacheEntry e(String k, int len, int day) => (key: k, length: len, touched: DateTime(2026, 1, day));

void main() {
  test('membuang yang paling lama tidak dipakai sampai total di bawah batas', () {
    final entries = [e('c', 100, 3), e('a', 100, 1), e('b', 100, 2)];
    expect(keysToEvict(entries, 250), ['a']);
    expect(keysToEvict(entries, 150), ['a', 'b']);
    expect(keysToEvict(entries, 100), ['a', 'b']);
  });

  test('tidak membuang apa pun bila sudah di bawah batas atau tanpa batas', () {
    final entries = [e('a', 100, 1), e('b', 100, 2)];
    expect(keysToEvict(entries, 200), isEmpty);
    expect(keysToEvict(entries, 0), isEmpty);
    expect(keysToEvict(entries, -5), isEmpty);
    expect(keysToEvict(const [], 10), isEmpty);
  });

  test('satu entri lebih besar dari batas ikut dibuang', () {
    expect(keysToEvict([e('big', 1000, 1)], 10), ['big']);
  });
}
