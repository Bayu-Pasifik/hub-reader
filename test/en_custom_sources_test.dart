import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:hub_reader/sources/en/asurascans.dart';
import 'package:hub_reader/sources/en/flamecomics.dart';
import 'package:hub_reader/sources/en/mangakatana.dart';
import 'package:hub_reader/sources/en/mangapill.dart';
import 'package:hub_reader/sources/en/tcbscans.dart';
import 'package:hub_reader/sources/models.dart';

void main() {
  final base = Uri.parse('https://x.test/');

  test('MangaPill: kartu daftar dan detail', () {
    final s = MangaPillSource();
    final doc = html.parse('''
<div class="grid"><div>
  <a href="/manga/1/one"><img data-src="https://c.test/1.jpg"></a>
  <div class="line-clamp-2">One</div>
</div></div>''');
    final list = s.parseDetails(
        html.parse('''
<div class="container"><div><div><img data-src="https://c.test/c.jpg"></div><div>
<h1>Judul</h1><div><p>Ringkasan</p></div>
<div><div>x</div><div><div>Publishing</div></div></div></div></div>
<a href="/search?genre=Action">Action</a>
<div id="chapters"><div><a href="/chapters/1-10/one-chapter-10">Chapter 10</a></div></div></div>'''),
        base,
        'https://x.test/manga/1/one');
    expect(doc.querySelectorAll('.grid > div:not([class])').length, 1);
    expect(list.title, 'Judul');
    expect(list.genres, ['Action']);
    expect(list.chapters.single.name, 'Chapter 10');
    expect(list.chapters.single.number, 10);
    expect(list.chapters.single.url, 'https://x.test/chapters/1-10/one-chapter-10');
  });

  test('TCB Scans: bab memakai angka akhir judul dan keterangan', () {
    final d = TcbScansSource().parseDetails(
        html.parse('''
<div class="order-1"><img src="/c.png"><h1>One Piece</h1><p>Cerita</p></div>
<div class="grid"><a href="/chapters/9/op-1100"><div class="font-bold">One Piece Chapter 1100</div>
<div class="text-gray-500">Judul bab</div></a></div>'''),
        base,
        'https://x.test/mangas/1/op');
    expect(d.title, 'One Piece');
    expect(d.thumbnailUrl, 'https://x.test/c.png');
    expect(d.chapters.single.name, 'Chapter 1100: Judul bab');
    expect(d.chapters.single.number, 1100);
  });

  test('MangaKatana: daftar, tanggal bab, dan larik gambar dari skrip', () {
    final s = MangaKatanaSource();
    final page = s.parseList(
        html.parse('''
<div id="book_list"><div class="item"><div class="cover"><img src="/t.jpg"></div>
<div class="text"><h3><a href="/manga/a.1">Judul A <span>x</span></a></h3></div></div></div>
<a class="next page-numbers" href="/page/2">Next</a>'''),
        base);
    expect(page.items.single.title, 'Judul A');
    expect(page.hasNextPage, isTrue);

    final d = s.parseDetails(
        html.parse('''
<h1 class="heading">Judul A</h1><div class="media"><div class="cover"><img src="/c.jpg"></div></div>
<div class="value status">Ongoing</div><div class="genres"><a>Action</a></div>
<table><tr><td class="chapter"><a href="/manga/a.1/c2">Chapter 2</a></td><td class="update_time">Jan-05-2024</td></tr></table>'''),
        base,
        'https://x.test/manga/a.1');
    expect(d.status, SourceMangaStatus.ongoing);
    expect(d.chapters.single.uploadedAt, DateTime(2024, 1, 5));

    expect(
        s.parsePages("var ytaw=['https://i.test/0.jpg','https://i.test/1.jpg'];var x=[1];"
            "document.getElementById('x').setAttribute('data-src', ytaw[0]);"),
        ['https://i.test/0.jpg', 'https://i.test/1.jpg']);
  });

  test('Flame Comics: detail dan halaman dari JSON Next.js', () {
    final s = FlameComicsSource();
    final d = s.parseDetails({
      'series': {
        'series_id': 2,
        'title': 'ORV',
        'altTitles': [' Alt ', ''],
        'description': '<p>Teks <b>tebal</b></p>',
        'cover': 'cover.jpg',
        'last_edit': 99,
        'type': 'Manhwa',
        'tags': ['Action'],
        'author': ['A'],
        'status': 'Ongoing',
      },
      'chapters': [
        {'chapter': '311.00', 'title': 'Judul', 'release_date': 1700000000, 'series_id': 2, 'token': 'tok'},
      ],
    }, 'https://x.test/series/2');
    expect(d.thumbnailUrl, 'https://cdn.flamecomics.xyz/uploads/images/series/2/cover.jpg?99');
    expect(d.description, contains('Teks tebal'));
    expect(d.description, contains('- Alt'));
    expect(d.genres, ['Manhwa', 'Action']);
    expect(d.status, SourceMangaStatus.ongoing);
    expect(d.chapters.single.name, 'Chapter 311 - Judul');
    expect(d.chapters.single.number, 311);
    expect(d.chapters.single.url, 'https://flamecomics.xyz/series/2/tok');

    expect(
        s.parsePages({
          'chapter': {
            'series_id': 2,
            'token': 'tok',
            'release_date': 5,
            'images': {
              '0': {'name': 'a.jpg'},
              '1': {'name': 'b.jpg'},
            },
          },
        }),
        [
          'https://cdn.flamecomics.xyz/uploads/images/series/2/tok/a.jpg?5',
          'https://cdn.flamecomics.xyz/uploads/images/series/2/tok/b.jpg?5',
        ]);
  });

  test('Asura Scans: daftar, detail tanpa bab terkunci, halaman', () {
    final s = AsuraScansSource();
    final page = s.parseList({
      'data': [
        {'public_url': '/comics/abc-7ba78ec7', 'title': 'Abc', 'cover': 'https://c.test/a.webp'},
      ],
      'meta': {'has_more': true},
    });
    expect(page.items.single.url, 'https://asurascans.com/comics/abc-7ba78ec7');
    expect(page.hasNextPage, isTrue);

    final d = s.parseDetails({
      'series': {
        'title': 'Abc',
        'public_url': '/comics/abc-7ba78ec7',
        'description': '<p>Isi</p>',
        'alternative_titles': 'A1 • A2',
        'status': 'dropped',
        'type': 'manhwa',
        'genres': [
          {'name': 'Action', 'slug': 'action'},
        ],
      },
    }, {
      'data': [
        {'number': 3, 'is_premium': true},
        {'number': 2, 'title': 'Dua', 'early_access_until': '2999-01-01T00:00:00Z'},
        {'number': 1.5, 'title': 'Satu', 'published_at': '2024-01-01T00:00:00Z'},
      ],
    }, 'https://asurascans.com/comics/abc-7ba78ec7');
    expect(d.chapters.single.name, 'Chapter 1.5 - Satu');
    expect(d.chapters.single.url, 'https://asurascans.com/comics/abc-7ba78ec7/chapter/1.5');
    expect(d.status, SourceMangaStatus.cancelled);
    expect(d.genres, ['Manhwa', 'Action']);
    expect(d.description, contains('- A2'));

    expect(
        s.parsePages({
          'data': {
            'chapter': {
              'pages': [
                {'url': 'https://i.test/1.webp'},
              ],
            },
          },
        }),
        ['https://i.test/1.webp']);
    expect(
        () => s.parsePages({
              'data': {
                'chapter': {
                  'pages': [
                    {'url': 'https://i.test/1.webp', 'tiles': [1, 2]},
                  ],
                },
              },
            }),
        throwsA(anything));
  });
}
