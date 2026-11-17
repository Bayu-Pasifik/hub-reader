import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parse;
import 'package:hub_reader/sources/catalog.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/sources/templates/mangabox.dart';

void main() {
  final source = MangaBoxSource(id: 'en.m', name: 'M', baseUrl: 'https://m.test', lang: 'en');
  final base = Uri.parse('https://m.test/manga/judul');

  test('normalisasi kueri cari', () {
    expect(MangaBoxSource.normalizeSearchQuery('  One Piece: Đại! '), 'one_piece_dai');
    expect(MangaBoxSource.normalizeSearchQuery('a--b'), 'a_b');
  });

  test('slug judul untuk slug berbentuk id (Mangakakalot)', () {
    final kakalot = MangaBoxSource(id: 'x', name: 'x', baseUrl: 'https://k.test', lang: 'en', titleSlugForIdSlugs: true);
    expect(kakalot.slugOf('https://k.test/manga/ab123', "Hero's  Tale!"), 'heros-tale');
    expect(kakalot.slugOf('https://k.test/manga/sudah-slug', 'Lain'), 'sudah-slug');
    expect(source.slugOf('https://m.test/manga/ab123', 'Lain'), 'ab123');
  });

  test('daftar + halaman berikutnya', () {
    final doc = parse('''
      <div class="truyen-list"><div class="list-truyen-item-wrap"><a data-id="1" href="/manga/a"><img src="/a.jpg"></a>
        <h3><a href="https://m.test/manga/a">Judul A</a></h3></div></div>
      <div class="group-page"><a>1</a><a href="?page=2">2</a></div>''');
    final page = source.parseList(doc, base);
    expect(page.items.single.url, 'https://m.test/manga/a');
    expect(page.items.single.thumbnailUrl, 'https://m.test/a.jpg');
    expect(page.hasNextPage, isTrue);
    final last = parse('<div class="group-page"><a>1</a></div>');
    expect(source.parseList(last, base).hasNextPage, isFalse);
  });

  test('detail gaya Mangakakalot dan Manganelo', () {
    final kakalot = parse('''
      <div class="manga-info-top"><h1>Seri</h1><ul>
        <li>Author(s) : <a>Budi</a></li><li>Status : Ongoing</li>
        <li>Genres : <a>Action</a> <a>Drama</a></li></ul></div>
      <span class="info-image"><img src="/c.jpg"></span><div id="noidungm">Seri summary: Cerita.</div>''');
    final d = source.parseDetails(kakalot, base, 'seri', const []);
    expect(d.author, 'Budi');
    expect(d.status, SourceMangaStatus.ongoing);
    expect(d.genres, ['Action', 'Drama']);
    expect(d.description, 'Cerita.');

    final nelo = parse('''
      <div class="panel-story-info"><h1>Seri 2</h1><table>
        <tr><td>Author(s) :</td><td><a>Sari</a></td></tr>
        <tr><td>Status :</td><td>Completed</td></tr>
        <tr><td>Genres :</td><td><a>Comedy</a></td></tr></table></div>
      <span class="info-image"><img src="/c2.jpg"></span><div id="panel-story-info-description">Isi.</div>''');
    final d2 = source.parseDetails(nelo, base, 'seri-2', const []);
    expect(d2.author, 'Sari');
    expect(d2.status, SourceMangaStatus.completed);
    expect(d2.genres, ['Comedy']);
  });

  test('bab dari API', () {
    final chapters = source.parseApiChapters([
      {'chapter_name': 'Chapter 2', 'chapter_slug': 'chapter-2', 'chapter_num': 2.0, 'updated_at': '2026-01-02T00:00:00Z'},
      {'chapter_name': 'Tanpa slug'},
    ], 'seri');
    expect(chapters.single.url, 'https://m.test/manga/seri/chapter-2');
    expect(chapters.single.number, 2);
    expect(chapters.single.uploadedAt, isNotNull);
  });

  test('gambar dari skrip cdns + chapterImages, atau img biasa', () {
    final script = parse(r'''<script>var cdns = ["https:\/\/cdn1.test\/","https:\/\/cdn2.test"]; var chapterImages = ["a\/1.webp","a\/2.webp"];</script>''');
    expect(source.parsePages(script, base), ['https://cdn1.test/a/1.webp', 'https://cdn1.test/a/2.webp']);
    final plain = parse('<div class="container-chapter-reader"><img src="/p/1.jpg"></div>');
    expect(source.parsePages(plain, base), ['https://m.test/p/1.jpg']);
  });

  test('katalog membuat MangaBoxSource', () {
    final s = CatalogEntry.tryParse({
      'id': 'en.mangakakalot',
      'name': 'Mangakakalot',
      'lang': 'en',
      'baseUrl': 'https://www.kakamanga.com',
      'theme': 'mangabox',
      'options': {'titleSlugForIdSlugs': true},
    })!.create();
    expect(s, isA<MangaBoxSource>());
    expect((s! as MangaBoxSource).titleSlugForIdSlugs, isTrue);
  });
}
