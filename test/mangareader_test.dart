import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/sources/templates/mangareader.dart';

void main() {
  final source = MangaReaderSource(id: 'en.m', name: 'M', baseUrl: 'https://m.test', lang: 'en');

  test('daftar & halaman berikutnya', () {
    final doc = html_parser.parse('''
      <div class="manga_list-sbs"><a class="manga-poster" href="/manga/a"><img alt="Seri A" data-src="/c/a.jpg"></a></div>
      <ul class="pagination"><li class="active">1</li><li><a>2</a></li></ul>''');
    final page = source.parseList(doc, Uri.parse('https://m.test/filter/'));
    expect(page.items.single.url, 'https://m.test/manga/a');
    expect(page.items.single.title, 'Seri A');
    expect(page.items.single.thumbnailUrl, 'https://m.test/c/a.jpg');
    expect(page.hasNextPage, isTrue);
  });

  test('detail: penulis/ilustrator, status, bab dengan data-id', () {
    final doc = html_parser.parse('''
      <div id="ani_detail"><img data-src="/c.jpg"><h2 class="manga-name">Seri A</h2>
        <div class="genres"><a>Aksi</a></div><div class="description">Deskripsi</div>
        <div class="anisc-info">
          <div class="item"><span class="item-head">Authors:</span><a>Budi,</a> (Story), <a>Sari</a> (Art)</div>
          <div class="item"><span class="item-head">Status:</span><span class="name">Ongoing</span></div>
        </div></div>
      <ul id="en-chapters"><li class="chapter-item" data-id="55"><a href="/manga/a/chapter-2"><span class="name">Chapter 2</span></a></li></ul>''');
    final d = source.parseDetails(doc, Uri.parse('https://m.test/manga/a'));
    expect(d.title, 'Seri A');
    expect(d.author, 'Budi');
    expect(d.artist, 'Sari');
    expect(d.status, SourceMangaStatus.ongoing);
    expect(d.chapters.single.url, 'https://m.test/manga/a/chapter-2#55');
    expect(d.chapters.single.number, 2);
  });

  test('gambar: selector khusus dengan atribut tanpa kutip', () {
    final custom = MangaReaderSource(id: 'x', name: 'X', baseUrl: 'https://m.test', lang: 'en', vals: {
      'pageSelector': '.container-reader-chapter > .iv-card:not([data-url\$=skip.jpg])',
    });
    final pages = custom.parsePages(
      '<div class="container-reader-chapter"><div class="iv-card" data-url="https://m.test/skip.jpg"></div>'
      '<div class="iv-card" data-url="\n\t https://c.test/2.jpg"></div></div>',
      Uri.parse('https://m.test/read'),
    );
    expect(pages, ['https://c.test/2.jpg']);
  });
}
