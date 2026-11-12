import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:hub_reader/sources/html_utils.dart';
import 'package:hub_reader/sources/id/komiku.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/sources/registry.dart';
import 'package:hub_reader/sources/templates/mangathemesia.dart';

// Fixture HTML disederhanakan dari struktur asli tema MangaThemesia & Komiku.
// Tes ini memeriksa parser saja (tanpa jaringan).

const _themesiaList = '''
<div class="listupd">
  <div class="bs"><div class="bsx">
    <a href="https://example.com/manga/solo-leveling/" title="Solo Leveling">
      <div class="limit"><img class="ts-post-image" data-src="/wp-content/uploads/solo.jpg" src="data:image/svg+xml,x"></div>
      <div class="bigor"><div class="tt">Solo Leveling</div></div>
    </a>
  </div></div>
  <div class="bs"><div class="bsx">
    <a href="/manga/omniscient-reader/" title="Omniscient Reader"><img src="https://cdn.example.com/or.webp"></a>
  </div></div>
</div>
<div class="hpage"><a class="r" href="?page=2">Next</a></div>
''';

const _themesiaDetail = '''
<html><body>
<div class="bigcontent">
  <div class="thumb"><img src="https://cdn.example.com/solo.jpg"></div>
  <h1 class="entry-title">Solo Leveling</h1>
  <span class="alternative">나 혼자만 레벨업, Only I Level Up</span>
  <div class="tsinfo">
    <div class="imptdt">Status <i>Ongoing</i></div>
    <div class="imptdt">Type <a href="/manga/?type=manhwa">Manhwa</a></div>
  </div>
  <div class="fmed"><b>Author</b><span>Chugong</span></div>
  <div class="fmed"><b>Artist</b><span>-</span></div>
  <div class="mgen"><a href="#">action</a><a href="#">Fantasy</a></div>
  <div class="entry-content entry-content-single" itemprop="description">
    <p>Paragraf satu.</p><p>Paragraf dua.</p>
  </div>
</div>
<div id="chapterlist"><ul>
  <li data-num="201"><div class="chbox"><div class="eph-num">
    <a href="https://example.com/solo-leveling-chapter-201/"><span class="chapternum">Chapter 201</span><span class="chapterdate">November 3, 2025</span></a>
  </div></div></li>
  <li data-num="200"><div class="chbox"><div class="eph-num">
    <a href="https://example.com/solo-leveling-chapter-200/"><span class="chapternum">Chapter 200</span><span class="chapterdate">3 Oktober 2025</span></a>
  </div></div></li>
</ul></div>
</body></html>
''';

const _themesiaReaderScript = '''
<html><body><div id="readerarea"></div>
<script>ts_reader.run({"prevUrl":"","sources":[{"source":"Server 1","images":["https:\\/\\/cdn.example.com\\/1.jpg","https:\\/\\/cdn.example.com\\/2.jpg"]}]});</script>
</body></html>
''';

const _komikuList = '''
<div class="bge">
  <div class="bgei"><a href="https://komiku.org/manga/one-piece/"><img src="https://thumbnail.komiku.org/op.jpg?resize=450,235"></a></div>
  <div class="kan"><a href="https://api.komiku.org/manga/one-piece/"><h3>One Piece</h3></a></div>
</div>
''';

const _komikuDetail = '''
<html><body>
<header id="Judul"><h1>Komik One Piece</h1></header>
<div class="ims"><img src="https://thumbnail.komiku.org/op.jpg?w=225"></div>
<table class="inftable">
  <tr><td>Judul Indonesia</td><td>Bajak Laut</td></tr>
  <tr><td>Pengarang</td><td>Eiichiro Oda</td></tr>
  <tr><td>Status</td><td>Ongoing</td></tr>
</table>
<ul class="genre"><li class="genre"><a><span>Action</span></a></li></ul>
<section id="Sinopsis"><p>Petualangan Luffy.</p></section>
<table id="Daftar_Chapter">
  <tr><th>Chapter</th></tr>
  <tr><td class="judulseries"><a href="/one-piece-chapter-1100/">Chapter 1100</a></td><td class="tanggalseries">12/11/2026</td></tr>
  <tr><td class="judulseries"><a href="/one-piece-chapter-1099/">Chapter 1099</a></td><td class="tanggalseries">2 jam lalu</td></tr>
</table>
</body></html>
''';

void main() {
  final themesia = MangaThemesiaSource(
    id: 'test.themesia',
    name: 'Test',
    baseUrl: 'https://example.com',
  );

  group('MangaThemesia', () {
    test('parses list with lazy images, relative links, and next page', () {
      final page = themesia.parseMangaList(
        html_parser.parse(_themesiaList),
        Uri.parse('https://example.com/manga/?page=1&order=popular'),
      );
      expect(page.items.map((m) => m.title), ['Solo Leveling', 'Omniscient Reader']);
      expect(page.items.first.thumbnailUrl, 'https://example.com/wp-content/uploads/solo.jpg');
      expect(page.items.last.url, 'https://example.com/manga/omniscient-reader/');
      expect(page.hasNextPage, isTrue);
    });

    test('builds search URL like the Kotlin template', () {
      expect(
        themesia.searchUrl(2, 'solo', order: 'popular').toString(),
        'https://example.com/manga/?title=solo&page=2&order=popular',
      );
    });

    test('parses details and chapters', () {
      final d = themesia.parseDetails(
        html_parser.parse(_themesiaDetail),
        Uri.parse('https://example.com/manga/solo-leveling/'),
      );
      expect(d.title, 'Solo Leveling');
      expect(d.author, 'Chugong');
      expect(d.artist, isNull); // "-" dianggap kosong
      expect(d.status, SourceMangaStatus.ongoing);
      expect(d.genres, containsAll(['Action', 'Fantasy', 'Manhwa']));
      expect(d.description, startsWith('Paragraf satu.\n\nParagraf dua.'));
      expect(d.description, contains('- Only I Level Up'));
      expect(d.thumbnailUrl, 'https://cdn.example.com/solo.jpg');
      expect(d.chapters, hasLength(2));
      expect(d.chapters.first.number, 201);
      expect(d.chapters.first.uploadedAt, DateTime(2025, 11, 3));
      expect(d.chapters.last.uploadedAt, DateTime(2025, 10, 3));
    });

    test('falls back to ts_reader JSON image list', () {
      const body = _themesiaReaderScript;
      final pages = themesia.parsePages(
        html_parser.parse(body),
        body,
        Uri.parse('https://example.com/solo-leveling-chapter-201/'),
      );
      expect(pages, ['https://cdn.example.com/1.jpg', 'https://cdn.example.com/2.jpg']);
    });
  });

  group('Komiku', () {
    final komiku = KomikuSource();

    test('rewrites API links onto komiku.org and strips cover query', () {
      final page = komiku.parseMangaList(
        html_parser.parse(_komikuList),
        Uri.parse('https://api.komiku.org/manga/'),
      );
      expect(page.items.single.url, 'https://komiku.org/manga/one-piece/');
      expect(page.items.single.thumbnailUrl, 'https://thumbnail.komiku.org/op.jpg');
    });

    test('parses details and chapter table', () {
      final d = komiku.parseDetails(
        html_parser.parse(_komikuDetail),
        Uri.parse('https://komiku.org/manga/one-piece/'),
      );
      expect(d.author, 'Eiichiro Oda');
      expect(d.status, SourceMangaStatus.ongoing);
      expect(d.genres, ['Action']);
      expect(d.description, 'Petualangan Luffy.\n\nJudul alternatif: Bajak Laut');
      expect(d.chapters.map((c) => c.url), [
        'https://komiku.org/one-piece-chapter-1100/',
        'https://komiku.org/one-piece-chapter-1099/',
      ]);
      expect(d.chapters.first.uploadedAt, DateTime(2026, 11, 12));
      expect(d.chapters.last.uploadedAt, isNotNull);
    });
  });

  group('html_utils', () {
    test('parseChapterNumber', () {
      expect(parseChapterNumber('Chapter 12.5 - Akhir'), 12.5);
      expect(parseChapterNumber('Ch. 7'), 7);
      expect(parseChapterNumber('Bab 3,5'), 3.5);
      expect(parseChapterNumber('Prolog'), isNull);
    });

    test('parseLooseDate handles relative dates', () {
      final now = DateTime(2026, 11, 12, 12);
      expect(parseLooseDate('2 jam lalu', now: now), DateTime(2026, 11, 12, 10));
      expect(parseLooseDate('3 days ago', now: now), DateTime(2026, 11, 9, 12));
      expect(parseLooseDate('2025-01-05'), DateTime(2025, 1, 5));
    });

    test('registry ids are unique', () {
      final ids = builtInSources().map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });
}
