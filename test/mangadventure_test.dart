import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/sources/templates/mangadventure.dart';

void main() {
  final source = MangAdventureSource(id: 'en.m', name: 'M', baseUrl: 'https://m.test', lang: 'en');

  test('daftar & halaman terakhir', () {
    final page = source.parseList({
      'last': false,
      'results': [
        {'slug': 'a', 'title': 'A', 'cover': 'c'},
        {'slug': 'b', 'title': ''},
      ],
    });
    expect(page.items.single.url, 'https://m.test/reader/a/');
    expect(page.hasNextPage, isTrue);
    expect(source.parseList({'last': true, 'results': []}).hasNextPage, isFalse);
  });

  test('detail & bab', () {
    final d = source.parseDetails({
      'slug': 'a',
      'title': 'A',
      'cover': 'c',
      'description': 'Deskripsi',
      'aliases': ['Alias'],
      'authors': ['Budi'],
      'artists': <String>[],
      'categories': ['Drama'],
      'status': 'completed',
    }, [
      {'id': 5, 'url': '/reader/a/1/2/', 'full_title': 'Vol. 1, Ch. 2: X', 'number': 2.0, 'final': true, 'published': '1714123650000', 'groups': ['G1', 'G2']},
    ]);
    expect(d.description, 'Deskripsi\n\nAlternative titles:\nAlias');
    expect(d.artist, isNull);
    expect(d.status, SourceMangaStatus.completed);
    expect(d.chapters.single.url, 'https://m.test/reader/a/1/2/#5');
    expect(d.chapters.single.name, 'Vol. 1, Ch. 2: X [END]');
    expect(d.chapters.single.scanlator, 'G1, G2');
  });

  test('gambar diurutkan menurut nomor halaman', () {
    expect(
      source.parsePages({
        'results': [
          {'number': 2, 'image': 'b'},
          {'number': 1, 'image': 'a'},
        ],
      }),
      ['a', 'b'],
    );
  });
}
