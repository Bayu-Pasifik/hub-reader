import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/sources/templates/guya.dart';

void main() {
  final source = GuyaSource(id: 'en.g', name: 'G', baseUrl: 'https://g.test', lang: 'en');

  test('detail: grup terpilih menurut preferred_sort, dan satu bab per grup tanpa sort', () {
    final d = source.parseDetails({
      'slug': 'seri',
      'title': 'Seri',
      'author': 'Budi',
      'description': 'Cerita <a href="x">tautan</a> akhir',
      'cover': '/media/c.jpg',
      'groups': {'1': 'Grup Satu', '2': 'Grup Dua'},
      'chapters': {
        '1': {
          'title': 'Awal',
          'folder': 'f1',
          'groups': {
            '1': ['a.png'],
            '2': ['b.png'],
          },
          'release_date': {'1': 1700000000, '2': 1700000100},
          'preferred_sort': ['2', '1'],
        },
        '2.5': {
          'title': 'Lanjut',
          'folder': 'f2',
          'groups': {
            '1': ['c.png'],
            '2': ['d.png'],
          },
          'release_date': {'1': 1700000200, '2': 1700000300},
        },
      },
    });
    expect(d.thumbnailUrl, 'https://g.test/media/c.jpg');
    expect(d.description, 'Cerita akhir');
    // Bab 1: satu entri (grup 2). Bab 2.5: dua entri (satu per grup). Urut terbaru dulu.
    expect(d.chapters.length, 3);
    expect(d.chapters.last.scanlator, 'Grup Dua');
    expect(d.chapters.last.name, '1 - Awal');
    expect(d.chapters.first.number, 2.5);
    expect(d.chapters.first.url, contains('/read/manga/seri/2-5/1/#'));
  });

  test('gambar bab', () {
    expect(source.parsePages('seri', 'f1', '2', ['a.png', 'b.png']), [
      'https://g.test/media/manga/seri/chapters/f1/2/a.png',
      'https://g.test/media/manga/seri/chapters/f1/2/b.png',
    ]);
  });

  test('Magical Translators menyaring seri menurut bahasa', () {
    final es = GuyaSource(id: 'x', name: 'x', baseUrl: 'https://g.test', lang: 'es', vals: {'slugLangFilter': true});
    final en = GuyaSource(id: 'y', name: 'y', baseUrl: 'https://g.test', lang: 'en', vals: {'slugLangFilter': true});
    final series = {
      'A': {'slug': 'a'},
      'B': {'slug': 'b-ES'},
      'C': {'slug': 'c-PL'},
    };
    expect(es.parseSeries(series).items.map((m) => m.title), ['B']);
    expect(en.parseSeries(series).items.map((m) => m.title), ['A']);
  });
}
