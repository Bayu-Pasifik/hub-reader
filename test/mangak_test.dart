import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/sources/templates/mangak.dart';

void main() {
  final source = MangaKSource(id: 'en.mk', name: 'MK', baseUrl: 'https://mk.test', lang: 'en');

  test('daftar: item API dan halaman berikutnya', () {
    final page = source.parseList({
      'items': [
        {'url': '/seri', 'name': ' Seri ', 'cover': 'https://c/x.webp'},
        {'url': '/tanpa-nama', 'name': ''},
      ],
      'pagination': {'has_next': true},
    });
    expect(page.items.length, 1);
    expect(page.items.first.url, 'https://mk.test/seri');
    expect(page.hasNextPage, isTrue);
  });

  test('detail & bab dari JSON', () {
    final d = source.parseDetails({
      'name': 'Seri',
      'cover': 'https://c/x.webp',
      'status': 'Ongoing',
      'summary': 'Ringkasan',
      'type': {'name': 'manhwa'},
      'authors': [{'name': 'Budi'}],
      'genres': [{'name': 'Action'}, {'name': 'action'}],
      'altNames': [{'name': 'Seri'}, {'name': 'Alt'}],
    }, [
      {'url': '/seri/chapter-2', 'name': 'Chapter 2', 'updated_at': '2026-01-02T00:00:00.000Z'},
    ], 'https://mk.test/seri');
    expect(d.author, 'Budi');
    expect(d.genres, ['Manhwa', 'Action']);
    expect(d.description, 'Ringkasan\n\nAlternative Names: Alt');
    expect(d.chapters.single.url, 'https://mk.test/seri/chapter-2');
    expect(d.chapters.single.number, 2);
  });

  test('gambar dari __NEXT_DATA__', () {
    const html = '<script id="__NEXT_DATA__" type="application/json">'
        '{"props":{"pageProps":{"initialChapter":{"images":["https://i/1.webp","https://i/2.webp"]}}}}</script>';
    expect(source.parsePages(html), ['https://i/1.webp', 'https://i/2.webp']);
  });
}
