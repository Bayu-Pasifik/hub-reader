import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/sources/templates/hiper.dart';

void main() {
  final source = HiperSource(id: 'en.h', name: 'H', baseUrl: 'https://h.test', lang: 'en', vals: {
    'authHeader': 'x-key',
    'authValue': 'abc',
  });

  test('header kunci dari opsi', () {
    expect(source.extraHeaders['x-key'], 'abc');
  });

  test('hasil pencarian tRPC', () {
    final page = source.parseSearch({
      'hits': [
        {'id': 7, 'slug': 'seri-a', 'title': 'Seri A', 'coverUrl': 'c'},
        {'id': 8, 'slug': 'x', 'title': ''},
      ],
    });
    expect(page.items.single.url, 'https://h.test/manga/seri-a#7');
    expect(page.hasNextPage, isTrue);
    expect(source.parseSearch(null).items, isEmpty);
  });

  test('detail & bab: nama bab menurut judul/nomor', () {
    final d = source.parseDetails({
      'id': 7,
      'title': 'Seri A',
      'synopsis': 'Ringkasan',
      'status': 'Ongoing',
      'genres': ['Aksi'],
      'type': 'manhwa',
      'authors': ['Budi'],
      'artists': <String>[],
    }, [
      {'id': 1, 'number': 2.0, 'title': null, 'createdAt': '2026-01-01T00:00:00Z'},
      {'id': 2, 'number': 3.5, 'title': 'Awal', 'createdAt': '2026-01-02T00:00:00Z'},
      {'id': 3, 'number': 4.0, 'title': 'Bab 4: X', 'createdAt': '2026-01-03T00:00:00Z'},
    ], 'seri-a');
    expect(d.genres, ['Aksi', 'manhwa']);
    expect(d.status, SourceMangaStatus.ongoing);
    expect(d.chapters.map((c) => c.name), ['Chapter 2', 'Chapter 3.5 Awal', 'Bab 4: X']);
    expect(d.chapters.first.url, 'https://h.test/manga/seri-a/2#1');
  });

  test('gambar: avif diutamakan, urut halaman, error ditolak', () {
    expect(
      source.parsePages([
        {'result': {'data': {'json': null}}},
        {
          'result': {
            'data': {
              'json': [
                {'pageOrder': 2, 'webpUrl': 'b.webp', 'avifUrl': null},
                {'pageOrder': 1, 'webpUrl': 'a.webp', 'avifUrl': 'a.avif'},
              ],
            },
          },
        },
      ]),
      ['a.avif', 'b.webp'],
    );
    expect(() => source.parsePages([{'error': 'x'}]), throwsA(anything));
  });
}
