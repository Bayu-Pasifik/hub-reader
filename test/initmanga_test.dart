import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:hub_reader/sources/templates/initmanga.dart';

void main() {
  final source = InitMangaSource(id: 'en.i', name: 'I', baseUrl: 'https://i.test', lang: 'en', vals: {
    'mangaUrlDirectory': 'manga',
    'chapterPrefix': 'Chapter',
    'siteOffsetHours': 8,
  });

  test('dekripsi isi bab: PBKDF2-SHA512 + AES-CBC', () {
    final key = InitMangaSource.passphraseKey('MDBBQ0NDNUFGNkIzNDhBQg==', '1e832710e2bfd678ed8389e63253bec6');
    final html = InitMangaSource.decryptContent(
      'OwCUGbyUM2pGnT1YxXQSu1yXUMdPy8vzce1+aBQ/xwAyLG1jfiIQlZhfAQawNITAruV9Vu0nQZMbTnA7GbEWKaLQAZkD8VYOJV18nAiyydEm0Cj3uLufTRRfHc7WzHmb',
      'bd4db1f2682ffea84b04b88852503304',
      key,
    );
    expect(html, contains('<img src="https://i.test/1.jpg">'));
  });

  test('daftar: kartu manga dan halaman berikutnya', () {
    final doc = html_parser.parse('''
      <div class="manga-card"><h3><a href="/manga/a/">Seri A</a></h3><img data-src="/c/a.jpg" src="data:image/gif;base64,x"></div>
      <ul class="uk-pagination"><li><a href="/p/2"><span uk-pagination-next></span></a></li></ul>''');
    final page = source.parseList(doc, Uri.parse('https://i.test/manga/'));
    expect(page.items.single.url, 'https://i.test/manga/a/');
    expect(page.items.single.thumbnailUrl, 'https://i.test/c/a.jpg');
    expect(page.hasNextPage, isTrue);
  });

  test('detail & bab: bab berkunci disembunyikan, tanggal di zona situs', () {
    final doc = html_parser.parse('''
      <body class="single postid-7"><h1>Seri A</h1>
      <div id="manga-description"><p>Satu</p><p>Dua</p></div>
      <div class="manga-info-details">Author: <b>Budi</b></div>
      <div id="genre-tags"><a>Drama</a><a class="uk-disabled">X</a></div>
      <div class="story-cover-wrap"><span class="manga-status-ribbon ribbon-completed"></span></div></body>''');
    final d = source.parseDetails(doc, Uri.parse('https://i.test/manga/a/'), [
      {'slug': 'chapter-2', 'number': 2.0, 'title': '', 'created_at': '2026-01-01 08:00:00', 'lock_type': 'none', 'is_purchased': false},
      {'slug': 'chapter-3', 'number': 3.0, 'lock_type': 'coin', 'is_purchased': false},
    ], '/manga/a');
    expect(d.title, 'Seri A');
    expect(d.description, 'Satu\n\nDua');
    expect(d.genres, ['Drama']);
    expect(d.chapters.length, 1);
    expect(d.chapters.single.name, 'Chapter 2');
    expect(d.chapters.single.url, 'https://i.test/manga/a/chapter-2/');
    expect(d.chapters.single.uploadedAt!.toUtc(), DateTime.utc(2026, 1, 1));
  });

  test('pencarian: hanya tipe manga', () {
    final page = source.parseSearch([
      {'post_type': 'manga', 'title': 'A &amp; B', 'url': 'https://i.test/manga/a/', 'thumb': 't'},
      {'post_type': 'sticker', 'title': 'S', 'url': 'https://i.test/s/'},
    ]);
    expect(page.items.single.title, 'A & B');
  });
}
