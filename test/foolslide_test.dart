import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parse;
import 'package:hub_reader/sources/templates/foolslide.dart';

void main() {
  final source = FoolSlideSource(id: 'en.f', name: 'F', baseUrl: 'https://f.test', lang: 'en');
  final base = Uri.parse('https://f.test/series/seri/');

  test('daftar: sampul thumb_ diganti dan halaman berikutnya', () {
    final doc = parse('''
      <div class="group"><a title="Seri A" href="/series/a/">Seri A</a><img src="/u/thumb_a.jpg"></div>
      <div class="next"><a href="#">Next</a></div>''');
    final page = source.parseList(doc, Uri.parse('https://f.test/directory/1/'));
    expect(page.items.single.title, 'Seri A');
    expect(page.items.single.thumbnailUrl, 'https://f.test/u/a.jpg');
    expect(page.hasNextPage, isTrue);
  });

  test('detail + bab', () {
    final doc = parse('''
      <h1 class="title">Seri</h1>
      <div class="thumbnail"><img src="/c/thumb_s.jpg"></div>
      <div class="info"><ul><li><b>Author</b>: Budi</li><li><b>Artist</b>: Sari</li><li><b>Description</b>: Cerita.</li></ul></div>
      <div class="list"><div class="element"><div class="title"><a title="Ch 2" href="/read/seri/en/0/2/">Ch 2</a></div>
        <div class="meta_r">by Grup, 2026.10.09</div></div></div>''');
    final chapters = source.parseChapters(doc, base);
    final d = source.parseDetails(doc, base, chapters, 'https://f.test/c/s.jpg');
    expect(d.title, 'Seri');
    expect(d.author, 'Budi');
    expect(d.artist, 'Sari');
    expect(d.description, 'Cerita.');
    expect(chapters.single.number, 2);
    expect(chapters.single.uploadedAt, DateTime(2026, 10, 9));
  });

  test('tanggal bab: relatif dan berimbuhan ordinal', () {
    final now = DateTime(2026, 11, 17, 10);
    expect(FoolSlideSource.parseChapterDate('Yesterday', now: now), DateTime(2026, 11, 16));
    expect(FoolSlideSource.parseChapterDate('Today', now: now), DateTime(2026, 11, 17));
    expect(FoolSlideSource.parseChapterDate('9th October, 2025', now: now), DateTime(2025, 10, 9));
    expect(FoolSlideSource.parseChapterDate('', now: now), isNull);
  });

  test('gambar dari var pages', () {
    final doc = parse('<script>var pages = [{"url":"/img/1.jpg"},{"url":"https://c.test/2.jpg"}]; var x=1;</script>');
    expect(source.parsePages(doc, base), ['https://f.test/img/1.jpg', 'https://c.test/2.jpg']);
  });
}
