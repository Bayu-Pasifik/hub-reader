import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/sources/templates/liliana.dart';

void main() {
  final source = LilianaSource(id: 'en.l', name: 'L', baseUrl: 'https://l.test', lang: 'en');

  test('daftar & halaman berikutnya', () {
    final doc = html_parser.parse('''
      <div id="main"><div class="grid"><div><img data-src="/c/a.jpg"><div class="text-center"><a href="/manga/a">Seri A</a></div></div></div></div>
      <div class="blog-pager"><span class="pagecurrent">1</span><span>2</span></div>''');
    final page = source.parseList(doc, Uri.parse('https://l.test/ranking/week/1'));
    expect(page.items.single.url, 'https://l.test/manga/a');
    expect(page.items.single.thumbnailUrl, 'https://l.test/c/a.jpg');
    expect(page.hasNextPage, isTrue);
  });

  test('pencarian POST', () {
    final page = source.parsePostSearch('{"list":[{"name":"Seri A","url":"/manga/a","cover":"/c.jpg"}]}');
    expect(page.items.single.url, 'https://l.test/manga/a');
    expect(page.items.single.thumbnailUrl, 'https://l.test/c.jpg');
  });

  test('detail & bab dengan waktu epoch', () {
    final doc = html_parser.parse('''
      <div class="a1"><figure><img src="/c.jpg"></figure></div>
      <div class="a2"><header><h1>Seri A</h1></header><div><a rel="tag" class="label">Aksi</a></div></div>
      <div id="syn-target">Deskripsi</div>
      <div class="y6x11p"><i class="fas fa-user"></i><span class="dt">Updating</span><i class="fas fa-rss"></i><span class="dt">Ongoing</span></div>
      <ul><li class="chapter"><a href="/manga/a/chapter-2">Chapter 2</a><time datetime="1700000000"></time></li></ul>''');
    final d = source.parseDetails(doc, Uri.parse('https://l.test/manga/a'));
    expect(d.title, 'Seri A');
    expect(d.author, isNull);
    expect(d.status, SourceMangaStatus.ongoing);
    expect(d.genres, ['Aksi']);
    expect(d.chapters.single.uploadedAt, DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000));
  });

  test('gambar: urut data-index, lewati svg', () {
    final pages = source.parsePages(
      '<div class="separator" data-index="2"><a href="https://c.test/2.jpg"></a></div>'
      '<div class="separator" data-index="1"><a href="https://c.test/1.jpg"></a></div>'
      '<div class="separator" data-index="3"><a href="https://c.test/x.svg"></a></div>',
      Uri.parse('https://l.test/manga/a/chapter-2'),
    );
    expect(pages, ['https://c.test/1.jpg', 'https://c.test/2.jpg']);
  });
}
