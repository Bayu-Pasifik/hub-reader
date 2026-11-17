import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/sources/templates/goda.dart';

void main() {
  final source = GoDaSource(id: 'en.g', name: 'G', baseUrl: 'https://g.test', lang: 'en');

  test('daftar: kunci seri, sampul dari proxy gambar, halaman berikutnya', () {
    final doc = html_parser.parse('''
      <div class="container"><div class="cardlist"><div class="pb-2">
        <a href="/manga/seri-a/"><img src="/_image?url=https%3A%2F%2Fcdn.test%2Fa.jpg"><h3>Seri A</h3></a>
      </div></div></div>
      <a aria-label="NEXT"><button>next</button></a>''');
    final page = source.parseList(doc, Uri.parse('https://g.test/hots/page/1'));
    expect(page.items.single.url, 'https://g.test/manga/seri-a');
    expect(page.items.single.title, 'Seri A');
    expect(page.items.single.thumbnailUrl, 'https://cdn.test/a.jpg');
    expect(page.hasNextPage, isTrue);
  });

  test('bab: dibalik, id bab di fragmen', () {
    final doc = html_parser.parse('''
      <div class="chapteritem"><a href="/manga/seri-a/ch-2" data-ct="Chapter 2" data-cs="22"></a></div>
      <div class="chapteritem"><a href="/manga/seri-a/ch-1" data-ct="Chapter 1" data-cs="11"></a></div>''');
    final chapters = source.parseChapters(doc, '7');
    expect(chapters.map((c) => c.name), ['Chapter 1', 'Chapter 2']);
    expect(chapters.first.url, 'https://g.test/manga/seri-a/ch-1#7/11');
  });

  test('detail: susunan elemen di sekitar h1', () {
    final doc = html_parser.parse('''
      <main><div><div>
        <div><h1><span>Ongoing</span>Seri A</h1></div>
        <div><b>Author</b><a>Budi ,</a><a>Sari</a></div>
        <div><b>Genre</b><a>Aksi ,</a><a>Drama</a></div>
        <div><a>#manhwa</a><a>#hot</a></div>
        <p>Deskripsi</p>
      </div></div><img class="object-cover" src="https://c.test/c.jpg"></main>''');
    final d = source.parseDetails(doc, Uri.parse('https://g.test/manga/seri-a'), '7', const []);
    expect(d.title, 'Seri A');
    expect(d.status, SourceMangaStatus.ongoing);
    expect(d.author, 'Budi, Sari');
    expect(d.genres, ['Aksi', 'Drama', 'manhwa', 'hot']);
    expect(d.description, 'Deskripsi\n\nID: 7');
    expect(d.thumbnailUrl, 'https://c.test/c.jpg');
  });

  test('gambar bab', () {
    final doc = html_parser.parse('<div id="chapcontent"><div><img data-src="https://c.test/1.jpg"></div><div><img src="https://c.test/2.jpg"></div></div>');
    expect(source.parsePages(doc), ['https://c.test/1.jpg', 'https://c.test/2.jpg']);
  });
}
