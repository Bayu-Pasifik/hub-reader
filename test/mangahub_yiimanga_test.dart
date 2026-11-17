import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parse;
import 'package:hub_reader/sources/catalog.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/sources/source.dart';
import 'package:hub_reader/sources/templates/mangahub.dart';
import 'package:hub_reader/sources/templates/yiimanga.dart';
import 'package:pointycastle/export.dart';

void main() {
  imageHeaderTests();
  group('Yiimanga', () {
    final source = YiimangaSource(id: 'en.x', name: 'X', baseUrl: 'https://x.test', lang: 'en');
    final base = Uri.parse('https://x.test/manhwa/seri/');

    test('daftar gaya latest-item dan list-item', () {
      final doc = parse('''
        <div class="latest-list"><div class="latest-item">
          <div class="latest-left"><img src="/a.jpg"></div>
          <div class="latest-right"><a href="/genre/x/"><span>Aksi</span></a><a href="/manhwa/a/"><h3>Judul A</h3></a></div>
        </div></div>
        <div class="list"><div class="list-item"><div class="item-img"><img src="/b.jpg"></div>
          <div class="item-title"><a href="/manhwa/b/">Judul B</a></div></div></div>
        <div id="pagination"><ul><li class="next"><a href="#">Next</a></li></ul></div>''');
      final page = source.parseList(doc, base);
      expect(page.items.map((m) => m.title), ['Judul A', 'Judul B']);
      expect(page.items.first.url, 'https://x.test/manhwa/a/');
      expect(page.items.first.thumbnailUrl, 'https://x.test/a.jpg');
      expect(page.hasNextPage, isTrue);
    });

    test('detail + bab', () {
      final doc = parse('''
        <h1 class="main-info-title">Seri</h1><img class="img-cover" src="/c.jpg">
        <ul class="main-info-list">
          <li><h5>Author(s):</h5><span><a href="/a/1">Budi</a>, <a href="/a/2">Sari</a></span></li>
          <li><h5>Genres</h5><span><a href="/genre/a">Action</a><a href="/genre/b">Drama</a></span></li>
          <li><h5>Status</h5><span>Ongoing</span></li>
          <li><h5>Alternative</h5><span>Nama Lain</span></li>
        </ul>
        <div class="short-desc-content"><p>Sinopsis satu.</p><p>Dua.</p></div>
        <ul class="chapter-list">
          <li><a href="/ch/2/"><span class="chapter-name">Chapter 2</span><span class="ct-update">06 Oct 2026</span></a></li>
          <li><a href="/ch/1/"><span class="chapter-name">Chapter 1</span><span class="ct-update">Oct 26</span></a></li>
        </ul>''');
      final d = source.parseDetails(doc, base);
      expect(d.title, 'Seri');
      expect(d.author, 'Budi, Sari');
      expect(d.genres, ['Action', 'Drama']);
      expect(d.status, SourceMangaStatus.ongoing);
      expect(d.description, contains('Sinopsis satu.\n\nDua.'));
      expect(d.description, contains('Alternative names: Nama Lain'));
      expect(d.thumbnailUrl, 'https://x.test/c.jpg');
      expect(d.chapters.map((c) => c.number), [2, 1]);
      expect(d.chapters.first.uploadedAt, DateTime(2026, 10, 6));
      expect(d.chapters.last.uploadedAt, DateTime(2026, 10, 1));
    });

    test('gambar bab + genre', () {
      final doc = parse('<div class="reading-content"><img src="/p/1.jpg"><img data-src="/p/2.jpg"></div>');
      expect(source.parsePages(doc, base), ['https://x.test/p/1.jpg', 'https://x.test/p/2.jpg']);
      final home = parse('<div class="genre-list"><a href="/genre/b/">Zed</a><a href="/genre/a/">Alpha</a><a href="/genre/a/">Alpha</a></div>');
      expect(source.parseGenres(home, Uri.parse('https://x.test/')).map((o) => o.value), ['a', 'b']);
    });

    test('katalog memetakan opsi', () {
      final s = CatalogEntry.tryParse({
        'id': 'en.toongodcc',
        'name': 'ToonGod',
        'lang': 'en',
        'baseUrl': 'https://toongod.cc',
        'theme': 'yiimanga',
        'options': {
          'genreWithoutPageSegment': true,
          'vals': {'popularPath': 'webtoons'},
        },
      })!.create()! as YiimangaSource;
      expect(s.popularPath, 'webtoons');
      expect(s.genreWithoutPageSegment, isTrue);
      expect(s.supportsLatest, isTrue);
    });
  });

  group('MangaHub', () {
    final source = MangaHubSource(id: 'en.h', name: 'H', baseUrl: 'https://h.test', lang: 'en', mangaSource: 'm01');

    test('nama bab', () {
      expect(MangaHubSource.chapterName('', 12), 'Chapter 12');
      expect(MangaHubSource.chapterName('  The   End ', 12.5), 'Chapter 12.5 - The End');
      expect(MangaHubSource.chapterName('Chapter 3: Awal', 3), 'Chapter 3: Awal');
    });

    test('detail: bab dibalik jadi terbaru dulu', () {
      final d = source.parseDetails({
        'title': 'Judul',
        'status': 'completed',
        'image': 'm/a.jpg',
        'author': 'Penulis',
        'artist': 'N/A',
        'genres': 'Action, Drama',
        'description': 'Cerita',
        'alternativeTitle': 'A; B',
        'chapters': [
          {'number': 1.0, 'title': '', 'date': '2026-01-02T03:04:05Z'},
          {'number': 2.0, 'title': 'Dua', 'date': '2026-02-02T03:04:05Z'},
        ],
      }, 'slug-a');
      expect(d.status, SourceMangaStatus.completed);
      expect(d.thumbnailUrl, 'https://thumb.mghcdn.com/m/a.jpg');
      expect(d.genres, ['Action', 'Drama']);
      expect(d.description, 'Cerita\n\nAlternative Names:\n- A\n- B');
      expect(d.chapters.map((c) => c.url), [
        'https://h.test/chapter/slug-a/chapter-2.0',
        'https://h.test/chapter/slug-a/chapter-1.0',
      ]);
      expect(d.chapters.first.name, 'Chapter 2 - Dua');
    });

    test('daftar gambar tiga bentuk', () {
      expect(source.parsePages('{"p":"/a/","i":["1.jpg","2.jpg"]}'),
          ['https://imgx.mghcdn.com/a/1.jpg', 'https://imgx.mghcdn.com/a/2.jpg']);
      expect(source.parsePages('["x/1.jpg","https://o.test/2.jpg"]'),
          ['https://imgx.mghcdn.com/x/1.jpg', 'https://o.test/2.jpg']);
      expect(source.parsePages('{"1":"x/1.jpg"}'), ['https://imgx.mghcdn.com/x/1.jpg']);
    });

    test('dekripsi AES-GCM', () {
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final iv = Uint8List.fromList(List.generate(12, (i) => 100 + i));
      final plain = '{"p":"/a/","i":["1.jpg"]}';
      final gcm = GCMBlockCipher(AESEngine())..init(true, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
      final out = gcm.process(Uint8List.fromList(utf8.encode(plain)));
      final cipher = out.sublist(0, out.length - 16);
      final tag = out.sublist(out.length - 16);
      expect(MangaHubSource.decryptGcm(key, iv, tag, cipher), plain);
    });
  });
}

void imageHeaderTests() {
  group('imageHeadersFor', () {
    const base = {'Referer': 'https://mangafox.fun/', 'Cookie': 'cf_clearance=abc', 'User-Agent': 'Mozilla/5.0 (wv)'};

    test('cookie dibuang untuk CDN beda situs', () {
      final h = imageHeadersFor(base, 'https://thumb.mghcdn.com/mf/a.jpg');
      expect(h.containsKey('Cookie'), isFalse);
      expect(h['Referer'], 'https://mangafox.fun/');
      expect(h['User-Agent'], HttpSource.fallbackUserAgent);
    });

    test('cookie tetap untuk situs yang sama dan subdomainnya', () {
      expect(imageHeadersFor(base, 'https://mangafox.fun/a.jpg')['Cookie'], 'cf_clearance=abc');
      expect(imageHeadersFor(base, 'https://mangafox.fun/a.jpg')['User-Agent'], 'Mozilla/5.0 (wv)');
      expect(imageHeadersFor(base, 'https://img-1.mangafox.fun/a.jpg')['Cookie'], 'cf_clearance=abc');
    });

    test('UA WebView diganti walau tidak ada cookie', () {
      const noCookie = {'Referer': 'https://mangafox.fun/', 'User-Agent': 'Mozilla/5.0 (Linux; wv) Chrome'};
      expect(imageHeadersFor(noCookie, 'https://thumb.mghcdn.com/a.jpg')['User-Agent'], HttpSource.fallbackUserAgent);
      expect(imageHeadersFor(noCookie, 'https://mangafox.fun/a.jpg')['User-Agent'], 'Mozilla/5.0 (Linux; wv) Chrome');
    });

    test('tanpa cookie atau tanpa referer: tidak diubah', () {
      expect(imageHeadersFor(const {'Referer': 'https://a.test/'}, 'https://b.test/x'), const {'Referer': 'https://a.test/'});
      expect(imageHeadersFor(const {'Cookie': 'c=1'}, 'https://b.test/x')['Cookie'], 'c=1');
    });
  });
}
