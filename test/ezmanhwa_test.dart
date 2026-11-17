import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/sources/templates/ezmanhwa.dart';

void main() {
  final source = EZManhwaSource(id: 'en.e', name: 'E', baseUrl: 'https://e.test', lang: 'en');

  test('apiUrl bawaan dan dari opsi', () {
    expect(source.apiUrl, 'https://api.e.test/api/v1');
    final custom = EZManhwaSource(
        id: 'x', name: 'X', baseUrl: 'https://e.test', lang: 'en', vals: {'apiUrl': 'https://v.e.test/api/v1/'});
    expect(custom.apiUrl, 'https://v.e.test/api/v1');
  });

  test('daftar: novel dilewati, halaman berikutnya', () {
    final page = source.parseList({
      'data': [
        {'slug': 'a', 'title': 'A', 'type': 'MANHWA', 'cover': 'c'},
        {'slug': 'n', 'title': 'N', 'type': 'NOVEL'},
      ],
      'current': 1,
      'totalPages': 2,
    });
    expect(page.items.single.url, 'https://e.test/series/a');
    expect(page.hasNextPage, isTrue);
  });

  test('nama bab dan bab berbayar disembunyikan', () {
    final chapters = source.parseChapters([
      {'slug': 'c1', 'number': 1.0},
      {'slug': 'c2', 'number': 2.5, 'title': 'Awal'},
      {'slug': 'c3', 'number': 3.0, 'title': 'Chapter 3: X'},
      {'slug': 'c4', 'number': 4.0, 'requiresPurchase': true},
    ], 'seri');
    expect(chapters.map((c) => c.name), ['Chapter 1', 'Chapter 2.5 - Awal', 'Chapter 3: X']);
    expect(chapters.first.url, 'https://e.test/series/seri/c1');
  });

  test('gambar bab', () {
    expect(source.parsePages({'images': [{'url': 'a'}, {'url': 'b'}]}), ['a', 'b']);
    expect(() => source.parsePages({'requiresPurchase': true}), throwsA(anything));
  });
}
