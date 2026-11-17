import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/sources/templates/manga18.dart';

void main() {
  final source = Manga18Source(id: 'en.m', name: 'M', baseUrl: 'https://m.test', lang: 'en');

  test('daftar & halaman berikutnya', () {
    final doc = html_parser.parse('''
      <div class="story_item"><a href="/manhwa/a"><img src="/c/a.jpg"></a>
        <div class="mg_info"><div class="mg_name"><a href="/manhwa/a">Seri A</a></div></div></div>
      <ul class="pagination"><li class="active">1</li><li><a href="/p/2">2</a></li></ul>''');
    final page = source.parseList(doc, Uri.parse('https://m.test/list-manga/1'));
    expect(page.items.single.url, 'https://m.test/manhwa/a');
    expect(page.items.single.thumbnailUrl, 'https://m.test/c/a.jpg');
    expect(page.hasNextPage, isTrue);
  });

  test('detail & bab dalam satu halaman', () {
    final doc = html_parser.parse('''
      <div class="detail_avatar"><img src="/c.jpg"></div>
      <div class="detail_name"><h1>Seri A</h1></div>
      <div class="detail_reviewContent">Deskripsi</div>
      <div class="detail_listInfo">
        <div class="item"><div class="info_label">Author</div><div class="info_value">Budi</div></div>
        <div class="item"><div class="info_label">Artist</div><div class="info_value">Updating</div></div>
        <div class="item"><div class="info_label">Status</div><div class="info_value">On Going</div></div>
        <div class="item"><div class="info_label">Other name</div><div class="info_value">Alias</div></div>
        <div class="item"><div class="info_value"><a href="/manga-list/drama">Drama</a></div></div>
      </div>
      <div class="chapter_box"><div class="item"><a href="/manhwa/a/chapter-2">Chapter 2</a><p>05-01-2026</p></div></div>''');
    final d = source.parseDetails(doc, Uri.parse('https://m.test/manhwa/a'));
    expect(d.author, 'Budi');
    expect(d.artist, isNull);
    expect(d.status, SourceMangaStatus.ongoing);
    expect(d.genres, ['Drama']);
    expect(d.description, 'Deskripsi\n\nAlternative Names:\nAlias');
    expect(d.chapters.single.url, 'https://m.test/manhwa/a/chapter-2');
    expect(d.chapters.single.uploadedAt, DateTime(2026, 1, 5));
  });

  test('gambar: base64 dalam skrip slides_p_path', () {
    // "/img/1.jpg" dan "https://cdn.test/2.jpg"
    final doc = html_parser.parse('<script>var slides_p_path = ["L2ltZy8xLmpwZw==","aHR0cHM6Ly9jZG4udGVzdC8yLmpwZw==",];</script>');
    expect(source.parsePages(doc, Uri.parse('https://m.test/x')), ['https://m.test/img/1.jpg', 'https://cdn.test/2.jpg']);
  });
}
