import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/sources/templates/mangataro.dart';

void main() {
  final source = MangaTaroSource(id: 'en.t', name: 'T', baseUrl: 'https://t.test', lang: 'en');

  test('daftar: entri novel dan tanpa url dilewati, slug dari /manga/ dan /read/', () {
    final items = source.parseBrowse([
      {'id': '1', 'url': 'https://t.test/manga/seri-a/', 'title': 'Seri &amp;amp; A', 'cover': 'c'},
      {'id': '2', 'url': '', 'title': 'Bab'},
      {'id': '3', 'url': 'https://t.test/manga/n/', 'title': 'N', 'type': 'Novel'},
      {'id': '4', 'url': 'https://t.test/read/seri-b/ch1-9/', 'title': 'B'},
    ]);
    expect(items.map((e) => e.url), ['https://t.test/manga/seri-a#1', 'https://t.test/manga/seri-b#4']);
    expect(items.first.title, 'Seri & A');
  });

  test('pencarian cepat', () {
    final page = source.parseQuickSearch({
      'results': [
        {'id': 9, 'slug': 'x', 'title': 'X', 'thumbnail': 't', 'type': 'Manga'},
        {'id': 10, 'slug': 'n', 'title': 'N', 'type': 'Novel'},
      ],
    });
    expect(page.items.single.url, 'https://t.test/manga/x#9');
    expect(page.hasNextPage, isFalse);
  });

  test('bab: hanya bahasa sumber, judul & grup placeholder diabaikan, tanggal relatif', () {
    final now = DateTime(2026, 6, 15);
    final chapters = source.parseChapters([
      {'chapter': '91', 'title': 'N/A', 'date': '2 days ago', 'group_name': 'Grup', 'language': 'en', 'url': 'https://t.test/read/x/ch91-1/'},
      {'chapter': '5', 'title': 'Awal', 'date': '1 week ago', 'group_name': 'N/A', 'language': 'en', 'url': 'https://t.test/read/x/ch5-2/'},
      {'chapter': '1', 'language': 'es', 'url': 'https://t.test/read/x/ch1-3/'},
    ], now: now);
    expect(chapters.length, 2);
    expect(chapters.first.name, 'Chapter 91');
    expect(chapters.first.scanlator, 'Grup');
    expect(chapters.first.uploadedAt, DateTime(2026, 6, 13));
    expect(chapters.last.name, 'Chapter 5: Awal');
    expect(chapters.last.scanlator, isNull);
  });

  test('detail dari wp-json', () {
    final d = source.parseDetails({
      'type': 'manga',
      'title': {'rendered': 'Seri'},
      'content': {'rendered': '<p>Satu</p>'},
      '_embedded': {
        'wp:featuredmedia': [{'source_url': 'https://t.test/c.jpg'}],
        'wp:term': [
          [{'name': 'Aksi', 'taxonomy': 'post_tag'}],
          [{'name': 'Budi', 'taxonomy': 'manga_author'}],
        ],
      },
    }, SourceMangaStatus.ongoing, const [], 'https://t.test/manga/seri#1');
    expect(d.title, 'Seri');
    expect(d.author, 'Budi');
    expect(d.genres, ['Aksi', 'manga']);
    expect(d.thumbnailUrl, 'https://t.test/c.jpg');
    expect(d.description, 'Satu');
  });
}
