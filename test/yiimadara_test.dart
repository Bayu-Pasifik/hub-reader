import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parse;
import 'package:hub_reader/sources/catalog.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/sources/templates/yiimadara.dart';

void main() {
  YiiMadaraSource make({String lang = 'en', Map<String, Object?> vals = const {}}) =>
      YiiMadaraSource(id: 'x', name: 'X', baseUrl: 'https://y.test', lang: lang, vals: vals);
  final base = Uri.parse('https://y.test/manga/seri');

  test('daftar menyaring entri raw menurut bahasa', () {
    final doc = parse('''
      <div class="page-item"><h3><a href="/manga/a">Judul A</a></h3><img data-src="/a.jpg" src="/x.gif"></div>
      <div class="page-item"><h3><a href="/manga/b-raw/">Judul B</a></h3><img src="/b.jpg"></div>
      <div class="page-item"><h3><a href="/manga/c">Judul C Raw</a></h3><img src="/c.jpg"></div>
      <ul id="blog-pager"><li class="next"><a href="#">Next</a></li></ul>''');
    final en = make().parseList(doc, base);
    expect(en.items.map((m) => m.title), ['Judul A']);
    expect(en.items.single.thumbnailUrl, 'https://y.test/a.jpg');
    expect(en.hasNextPage, isTrue);
    expect(make(lang: 'ko').parseList(doc, base).items.map((m) => m.title), ['Judul B', 'Judul C Raw']);
    expect(make(vals: {'rawEntries': 'show'}).parseList(doc, base).items.length, 3);
    expect(make().parseList(doc, base, rawListing: true).items.length, 3);
  });

  test('detail gaya summary-heading dan <b>', () {
    final doc = parse('''
      <div class="post-title"><h1>Seri <span>18+</span></h1></div>
      <div class="summary_image"><img src="/c.jpg"></div>
      <div class="post-content_item"><div class="summary-heading">Author(s)</div><div class="summary-content"><a>Budi</a><a>Sari</a></div></div>
      <div class="post-content_item"><b>Genre:</b><span><a>Action</a><a>Drama</a></span></div>
      <div class="post-content_item"><b>Status</b><span>Completed</span></div>
      <div class="post-content_item"><b>Alternative</b><span>Nama Lain</span></div>
      <div class="dsct"><p>Isi satu.</p><p>Dua.</p></div>
      <ul class="row-content-chapter"><li><a href="/manga/seri/ch-2">Chapter 2</a><span class="chapter-time">09 Oct 2026</span></li></ul>''');
    final d = make().parseDetails(doc, base);
    expect(d.title, 'Seri');
    expect(d.author, 'Budi, Sari');
    expect(d.genres, ['Action', 'Drama']);
    expect(d.status, SourceMangaStatus.completed);
    expect(d.description, contains('Isi satu.\n\nDua.'));
    expect(d.description, contains('Alternative names: Nama Lain'));
    expect(d.chapters.single.number, 2);
    expect(d.chapters.single.uploadedAt, DateTime(2026, 10, 9));
  });

  test('opsi katalog: directoryPath kosong = tanpa katalog, per bahasa', () {
    final fx = make(vals: {'directoryPath': ''});
    expect(fx.directoryPath, isNull);
    final cc = make(lang: 'ko', vals: {'directoryPath': 'webtoons', 'directoryPathko': 'raw'});
    expect(cc.directoryPath, 'raw');
    expect(make(vals: {'directoryPath': 'webtoons'}).directoryPath, 'webtoons');
    expect(make().directoryPath, 'manga');
  });

  test('katalog membuat YiiMadaraSource dengan genre tetap', () {
    final s = CatalogEntry.tryParse({
      'id': 'all.manga18me',
      'name': 'Manga18.me',
      'lang': 'all',
      'baseUrl': 'https://manga18.me',
      'theme': 'yiimadara',
      'options': {
        'vals': {'supportsFilterFetching': false},
        'genres': [
          ['Action', 'genre/action']
        ],
      },
    })!.create()! as YiiMadaraSource;
    expect(s.genreList.single, ('Action', 'genre/action'));
  });
}
