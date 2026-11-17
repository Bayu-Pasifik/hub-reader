import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/sources/templates/wpcomics.dart';

void main() {
  final source = WPComicsSource(id: 'vi.w', name: 'W', baseUrl: 'https://w.test', lang: 'vi');
  final us = WPComicsSource(id: 'en.w', name: 'W', baseUrl: 'https://w.test', lang: 'en', vals: {'monthFirst': true});

  test('daftar: judul, url, sampul dengan atribut data-original', () {
    final doc = html_parser.parse('''
      <div class="items"><div class="item"><div class="image"><a><img data-original="//c.test/a.jpg" src=""></a></div>
        <h3><a href="/truyen/a">Truyện A</a></h3></div></div>
      <a rel="next" href="?page=2">2</a>''');
    final page = source.parseList(doc, Uri.parse('https://w.test/hot'), 'div.items div.item');
    expect(page.items.single.url, 'https://w.test/truyen/a');
    expect(page.items.single.thumbnailUrl, 'https://c.test/a.jpg');
    expect(page.hasNextPage, isTrue);
  });

  test('tanggal: relatif (en/vi) dan DMY vs MDY', () {
    final now = DateTime(2026, 6, 15, 12);
    expect(source.parseDate('3 giờ trước', now: now), DateTime(2026, 6, 15, 9));
    expect(source.parseDate('2 days ago', now: now), DateTime(2026, 6, 13, 12));
    expect(source.parseDate('20:15 - 07/11/2025 +0500'), DateTime(2025, 11, 7));
    expect(us.parseDate('07/11/2025'), DateTime(2025, 7, 11));
    expect(source.parseDate('abc'), isNull);
  });

  test('detail & bab', () {
    final doc = html_parser.parse('''
      <article id="item-detail"><h1 class="title-detail">Truyện A</h1>
        <ul><li class="author"><p class="col-xs-8">Budi</p></li><li class="status"><p class="col-xs-8">Đang tiến hành</p></li>
        <li class="kind"><p class="col-xs-8"><a>Aksi</a></p></li></ul>
        <div class="col-image"><img src="/c.jpg"></div><div class="detail-content"><p>Deskripsi</p></div></article>
      <div class="list-chapter"><ul><li class="row"><div class="col-xs-5"><a href="/truyen/a/chap-2">Chapter 2</a></div>
        <div class="col-xs-4">07/11/2025</div></li></ul></div>''');
    final base = Uri.parse('https://w.test/truyen/a');
    final chapters = source.parseChapters(doc, base);
    final d = source.parseDetails(doc, base, chapters);
    expect(d.title, 'Truyện A');
    expect(d.status, SourceMangaStatus.ongoing);
    expect(d.genres, ['Aksi']);
    expect(chapters.single.url, 'https://w.test/truyen/a/chap-2');
    expect(chapters.single.uploadedAt, DateTime(2025, 11, 7));
  });

  test('gambar: unik dan hanya URL valid', () {
    final doc = html_parser.parse('''
      <div class="page-chapter"><img data-original="https://c.test/1.jpg"><img src="https://c.test/1.jpg"><img src=""><img src="/2.jpg"></div>''');
    expect(source.parsePages(doc, Uri.parse('https://w.test/x')), ['https://c.test/1.jpg', 'https://w.test/2.jpg']);
  });
}
