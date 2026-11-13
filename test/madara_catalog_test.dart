import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:hub_reader/sources/catalog.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/sources/registry.dart';
import 'package:hub_reader/sources/source.dart';
import 'package:hub_reader/sources/templates/madara.dart';
import 'package:hub_reader/sources/templates/mangathemesia.dart';

const _archive = '''
<div class="page-item-detail manga" data-post-id="10">
  <div class="item-thumb"><a href="https://ex.com/manga/solo/"><img data-src="  https://ex.com/c/solo.jpg  " src="data:image/gif;base64,x"></a></div>
  <div class="post-title font-title"><h3 class="h5"><a href="https://ex.com/manga/solo/">Solo Leveling</a></h3></div>
</div>
<div class="page-item-detail manga">
  <div class="post-title"><h3><a href="/manga/omni/">Omniscient</a></h3></div>
  <img srcset="https://ex.com/c/o-110.jpg 110w, https://ex.com/c/o-350.jpg 350w">
</div>
''';

const _detail = '''
<html><body>
<div class="post-title"><h1>Solo Leveling <span class="manga-title-badges hot">HOT</span></h1></div>
<div class="summary_image"><img data-lazy-src="https://ex.com/c/solo-big.jpg"></div>
<div class="post-content_item"><div class="summary-heading"><h5>Alternative</h5></div><div class="summary-content">나 혼자만 레벨업</div></div>
<div class="post-content_item"><div class="summary-heading"><h5>Type</h5></div><div class="summary-content">Manhwa</div></div>
<div class="author-content"><a>Chugong</a></div>
<div class="artist-content"><a>Updating</a></div>
<div class="genres-content"><a href="/manga-genre/action/">Action</a></div>
<div class="post-content_item"><div class="summary-heading"><h5>Status</h5></div><div class="summary-content">OnGoing</div></div>
<div class="description-summary"><div class="summary__content"><p>Satu.</p><p>Dua.</p></div></div>
<div class="listing-chapters_wrap"><ul>
  <li class="wp-manga-chapter"><a href="https://ex.com/manga/solo/chapter-2/">Chapter 2</a><span class="chapter-release-date"><i>2 hours ago</i></span></li>
  <li class="wp-manga-chapter"><a href="https://ex.com/manga/solo/chapter-1/">Chapter 1</a><span class="chapter-release-date"><i>March 3, 2024</i></span></li>
</ul></div>
</body></html>
''';

void main() {
  final madara = MadaraSource(id: 'en.ex', name: 'Ex', baseUrl: 'https://ex.com', lang: 'en');

  group('Madara', () {
    test('ajax form matches the Kotlin madara_load_more request', () {
      final popular = madara.ajaxForm(2, sortKey: '_wp_manga_views');
      expect(popular['action'], 'madara_load_more');
      expect(popular['page'], '1');
      expect(popular['vars[meta_key]'], '_wp_manga_views');
      expect(popular['vars[meta_query][0][key]'], '_wp_manga_chapter_type');

      final search = madara.ajaxForm(1,
          query: 'solo',
          search: true,
          filters: FilterValues.empty.toggleMulti('genre', 'action').toggleMulti('status', 'end').withSingle('order', 'alphabet'));
      expect(search['vars[s]'], 'solo');
      expect(search['vars[tax_query][0][terms][0]'], 'action');
      expect(search['vars[meta_query][1][key]'], '_wp_manga_status');
      expect(search['vars[meta_query][1][value][0]'], 'end');
      expect(search['vars[orderby]'], 'post_title');
    });

    test('parses archive with lazy src, srcset and relative links', () {
      final items = madara.parseArchive(html_parser.parse(_archive), Uri.parse('https://ex.com/wp-admin/admin-ajax.php'));
      expect(items.map((m) => m.title), ['Solo Leveling', 'Omniscient']);
      expect(items.first.thumbnailUrl, 'https://ex.com/c/solo.jpg');
      expect(items.last.url, 'https://ex.com/manga/omni/');
      expect(items.last.thumbnailUrl, 'https://ex.com/c/o-350.jpg');
    });

    test('parses details and chapter list', () {
      final doc = html_parser.parse(_detail);
      final url = Uri.parse('https://ex.com/manga/solo/');
      final d = madara.parseDetails(doc, url);
      expect(d.title, 'Solo Leveling');
      expect(d.author, 'Chugong');
      expect(d.artist, isNull, reason: '"Updating" diabaikan');
      expect(d.status, SourceMangaStatus.ongoing);
      expect(d.genres, containsAll(['Action', 'Manhwa']));
      expect(d.description, 'Satu.\n\nDua.\n\nJudul alternatif: 나 혼자만 레벨업');
      expect(d.thumbnailUrl, 'https://ex.com/c/solo-big.jpg');

      final chapters = madara.parseChapters(doc, url);
      expect(chapters.map((c) => c.number), [2, 1]);
      expect(chapters.last.uploadedAt, DateTime(2024, 3, 3));
      expect(chapters.first.uploadedAt, isNotNull);
    });

    test('relative dates in several languages', () {
      final now = DateTime(2026, 11, 12, 12);
      expect(madaraDate('3 días', now: now), DateTime(2026, 11, 9, 12));
      expect(madaraDate('2 saat önce', now: now), DateTime(2026, 11, 12, 10));
      expect(madaraDate('yesterday', now: now), DateTime(2026, 11, 11));
      expect(madaraDate('1 ay önce', now: now), DateTime(2026, 10, 13, 12));
    });
  });

  group('catalog', () {
    test('bundled catalog parses and builds every entry', () {
      final catalog = SourceCatalog.fromJsonString(File('assets/sources/catalog.json').readAsStringSync());
      expect(catalog.entries.length, greaterThan(300));
      final sources = builtInSources(catalog: catalog);
      final ids = sources.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'ID sumber harus unik');
      expect(sources.whereType<MadaraSource>(), isNotEmpty);
      expect(sources.whereType<MangaThemesiaSource>(), isNotEmpty);
      // Sumber lokal lalu sumber kustom tetap di depan.
      expect(ids.take(3), ['local', 'id.komiku', 'id.shinigami']);
    });

    test('entry options map to template settings', () {
      final entry = CatalogEntry.tryParse({
        'id': 'en.x',
        'name': 'X',
        'lang': 'en',
        'baseUrl': 'https://x.com',
        'theme': 'madara',
        'contentWarning': 'mixed',
        'options': {'noAjax': true, 'chapterMode': 'AdminAjax', 'mangaSubString': 'series', 'customized': true},
      })!;
      final s = entry.create()! as MadaraSource;
      expect((s.noAjax, s.chapterMode, s.mangaSubString), (true, MadaraChapterMode.adminAjax, 'series'));
      expect(s.contentWarning, ContentWarning.mixed);
      expect(entry.customized, isTrue);
    });
  });
}
