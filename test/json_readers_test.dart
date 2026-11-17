import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/sources/templates/json_readers.dart';

void main() {
  test('Monochrome: URL gambar memuat id seri dan id bab', () async {
    final source = MonochromeSource(id: 'en.m', name: 'M', baseUrl: 'https://m.test', lang: 'en');
    final d = source.parseDetails({
      'id': 'seri-1',
      'title': 'Judul',
      'status': 'hiatus',
      'author': 'Budi',
      'artist': '',
      'description': 'Cerita',
      'version': 3,
    }, [
      {'id': 'bab-9', 'volume': 2, 'number': 9.0, 'name': 'Akhir', 'scanGroup': 'Grup', 'version': 4, 'length': 2, 'uploadTime': '2026-01-02T03:04:05Z'},
    ]);
    expect(d.status, SourceMangaStatus.ongoing);
    expect(d.thumbnailUrl, 'https://api.m.test/media/seri-1/cover.jpg?version=3');
    expect(d.chapters.single.name, 'Vol 2 Chapter 9 - Akhir');
    expect(d.chapters.single.scanlator, 'Grup');
    final pages = await source.pages(d.chapters.single);
    expect(pages, [
      'https://api.m.test/media/seri-1/bab-9/1.jpg?version=4',
      'https://api.m.test/media/seri-1/bab-9/2.jpg?version=4',
    ]);
  });

  test('Bakkin: urutan bab dibalik dan nama seri jatuh ke dir', () {
    final source = BakkinSource(id: 'en.b', name: 'B', baseUrl: 'https://b.test/reader', lang: 'en');
    final d = source.parseDetails({
      'dir': 'seri',
      'name': '',
      'author': 'Budi',
      'status': 'Ongoing',
      'thumb': 'static/s.jpg',
      'volumes': [
        {
          'dir': 'v1',
          'name': 'Volume 1',
          'chapters': [
            {'dir': 'c1', 'name': 'Awal', 'pages': ['p/1.jpg']},
            {'dir': 'c2', 'name': 'Lanjut', 'pages': ['p/2.jpg']},
          ],
        },
      ],
    });
    expect(d.title, 'seri');
    expect(d.thumbnailUrl, 'https://b.test/reader/static/s.jpg');
    expect(d.chapters.map((c) => c.name), ['Volume 1 - Lanjut', 'Volume 1 - Awal']);
    expect(d.chapters.first.number, 2);
    expect(d.status, SourceMangaStatus.ongoing);
  });
}
