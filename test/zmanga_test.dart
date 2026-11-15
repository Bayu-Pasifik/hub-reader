import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/sources/catalog.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/sources/templates/small_templates.dart';
import 'package:html/parser.dart' show parse;

void main() {
  final source = ZMangaSource(id: 'id.x', name: 'X', baseUrl: 'https://x.test', lang: 'id');
  final base = Uri.parse('https://x.test/advanced-search/');

  test('daftar gaya flexbox2', () {
    final doc = parse('''
      <div class="flexbox2-item"><div class="flexbox2-content"><a href="/series/a/"><img src="/a.jpg"></a></div>
      <div class="flexbox2-title"><span>Judul A</span></div></div>
      <div class="pagination"><a class="next" href="#">Next</a></div>''');
    final page = source.parseList(doc, base);
    expect(page.items.single.title, 'Judul A');
    expect(page.items.single.url, 'https://x.test/series/a/');
    expect(page.hasNextPage, isTrue);
  });

  test('daftar gaya flexbox4 (Shiro Doujin)', () {
    final doc = parse('''
      <div class="flexbox4-item"><div class="flexbox4-content"><a href="/series/b/"><img src="/b.jpg"></a>
      <div class="flexbox4-side"><div class="title"><a href="/series/b/">Judul B</a></div></div></div></div>''');
    final page = source.parseList(doc, base);
    expect(page.items.single.title, 'Judul B');
    expect(page.hasNextPage, isFalse);
  });

  test('detail + bab (gaya klasik dan data-chapter-list)', () {
    final classic = parse('''
      <div class="series-title"><h2>Seri</h2></div><div class="series-synops">Sinopsis</div>
      <div class="series-infoz"><span class="status">Ongoing</span></div>
      <ul class="series-chapterlist"><li><div class="flexch-infoz"><a href="/c1/"><span>Chapter 1</span><span class="date">Jan 5, 2024</span></a></div></li></ul>''');
    final d = source.parseDetails(classic, Uri.parse('https://x.test/series/s/'));
    expect(d.title, 'Seri');
    expect(d.status, SourceMangaStatus.ongoing);
    expect(d.chapters.single.number, 1);
    expect(d.chapters.single.uploadedAt, isNotNull);

    final shiro = parse('''
      <h1>Seri 2</h1><ul data-chapter-list><li><a href="/c2/"><strong>Chapter 2</strong><span>9mo ago</span></a></li></ul>''');
    final d2 = source.parseDetails(shiro, Uri.parse('https://x.test/series/s2/'));
    expect(d2.chapters.single.name, 'Chapter 2');
    expect(d2.chapters.single.number, 2);
  });

  test('katalog membuat ZMangaSource dengan searchPath', () {
    final entry = CatalogEntry.tryParse({
      'id': 'th.oremanga',
      'name': 'OreManga',
      'lang': 'th',
      'baseUrl': 'https://www.oremanga.net',
      'theme': 'zmanga',
      'options': {
        'vals': {'searchPath': 'advance-search'}
      },
    });
    final s = entry!.create();
    expect(s, isA<ZMangaSource>());
    expect((s! as ZMangaSource).searchPath, 'advance-search');
  });
}
