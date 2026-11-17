import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/sources/templates/heancms.dart';

void main() {
  final source = HeanCmsSource(id: 'en.h', name: 'H', baseUrl: 'https://h.test', lang: 'en');

  test('daftar: url seri, sampul absolut/relatif, halaman berikutnya', () {
    final page = source.parseList({
      'data': [
        {'series_slug': 'a', 'title': 'A', 'thumbnail': 'https://cdn/a.webp'},
        {'series_slug': 'b', 'title': 'B', 'thumbnail': 'b.webp'},
        {'series_slug': 'c', 'title': ''},
      ],
      'meta': {'current_page': 1, 'last_page': 3},
    });
    expect(page.items.map((e) => e.url), ['https://h.test/series/a', 'https://h.test/series/b']);
    expect(page.items.first.thumbnailUrl, 'https://cdn/a.webp');
    expect(page.items.last.thumbnailUrl, 'https://api.h.test/b.webp');
    expect(page.hasNextPage, isTrue);
  });

  test('bab: lewati berbayar dan yang belum tayang', () {
    final now = DateTime.utc(2026, 1, 10);
    final chapters = source.parseChapters([
      {'id': 1, 'chapter_name': 'Chapter 2', 'chapter_title': 'Judul', 'chapter_slug': 'chapter-2', 'price': 0, 'created_at': '2026-01-01T00:00:00Z'},
      {'id': 2, 'chapter_name': 'Chapter 3', 'chapter_slug': 'chapter-3', 'price': 50, 'created_at': '2026-01-02T00:00:00Z'},
      {'id': 3, 'chapter_name': 'Chapter 4', 'chapter_slug': 'chapter-4', 'price': 0, 'created_at': '2026-02-01T00:00:00Z'},
    ], 'seri', now: now);
    expect(chapters.length, 1);
    expect(chapters.single.name, 'Chapter 2 - Judul');
    expect(chapters.single.url, 'https://h.test/series/seri/chapter-2#1');
  });

  test('detail: kredit, deskripsi, format dari badge', () {
    final d = source.parseDetails({
      'title': 'Seri',
      'author': '-',
      'studio': ' Studio ',
      'status': 'Hiatus',
      'description': '<p>Satu</p><p>Dua</p>',
      'alternative_names': 'Seri | Nama Lain',
      'rating': 4.5,
      'tags': [{'name': 'Zeta'}, {'name': 'Alfa'}],
    }, const [], 'Manga', 'https://h.test/series/seri');
    expect(d.author, isNull);
    expect(d.artist, 'Studio');
    expect(d.description, 'Satu\n\nDua\n\nRating: 4.50\n\nAlternative names:\n- Nama Lain');
    expect(d.genres, ['Alfa', 'Zeta', 'Manga']);
    expect(HeanCmsSource.parseBadge({'data': [{'id': 7, 'badge': 'Doujinhsi'}]}, 7), 'Doujinshi');
  });

  test('gambar bab', () {
    expect(
      source.parsePages({'chapter': {'chapter_data': {'images': ['https://i/1.webp', '2.webp']}}}),
      ['https://i/1.webp', 'https://api.h.test/2.webp'],
    );
  });
}
