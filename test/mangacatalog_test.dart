import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:hub_reader/sources/templates/mangacatalog.dart';

// Fixture HTML disederhanakan dari readonepiece.com, readopm.com, dan
// thetowerofgod.com. Tes ini memeriksa parser saja (tanpa jaringan).

const _gridDetail = '''
<html><body>
<div class="container"><h1>Read One Piece Manga Online</h1></div>
<div class="flex"><img src="https://i.imgur.com/op.png" alt="One Piece"></div>
<div class="flex flex-col"><div class="text-sm uppercase">Description</div><div class="text-muted"> Gol D. Roger. </div></div>
<div class="w-full">
  <div class="bg-bg-secondary p-3"><div class="grid grid-cols-4">
    <div class="col-span-4 lg:col-span-3"><a href="/chapter/one-piece-chapter-1198/">One Piece Chapter 1198</a><div class="text-xs"></div></div>
    <div class="lg:col-span-1"><a href="/chapter/one-piece-chapter-1198/">Read</a></div>
  </div></div>
  <div class="bg-bg-secondary p-3"><div class="grid grid-cols-4">
    <div class="col-span-4"><a href="/chapter/one-piece-chapter-1197/">One Piece Chapter 1197</a><div class="text-xs">Fate</div></div>
  </div></div>
</div>
</body></html>
''';

const _tableDetail = '''
<html><body>
<div class="card-body"><h2>Manga: <span>One Punch Man</span></h2><p>Saitama.</p></div>
<img class="card-img-right" src="/cover.jpg">
<table><tbody>
  <tr><td>One Punch Man Chapter 243</td><td>Nov 05, 2026</td><td><a href="/chapter/opm-243/" class="btn btn-primary">Read</a></td></tr>
</tbody></table>
</body></html>
''';

MangaCatalogSource _source({MangaCatalogLayout layout = MangaCatalogLayout.grid}) => MangaCatalogSource(
      id: 'en.op',
      name: 'Read One Piece',
      baseUrl: 'https://op.com',
      lang: 'en',
      layout: layout,
      titles: const [
        ('One Piece', '/manga/one-piece/'),
        ('Colored', '/manga/one-piece-digital-colored-comics/'),
        ('Dup', '/manga/one-piece/'),
      ],
    );

void main() {
  test('list comes from the hand-written titles, sorted and de-duplicated', () async {
    final page = await _source().popular(1);
    expect(page.items.map((m) => m.title), ['Colored', 'One Piece']);
    expect(page.items.last.url, 'https://op.com/manga/one-piece/');
    expect((await _source().popular(2)).items, isEmpty);
  });

  test('search matches the title or the slug', () async {
    expect((await _source().search(1, 'digital colored')).items.single.title, 'Colored');
    expect((await _source().search(1, 'piece')).items.length, 2);
  });

  test('grid layout: title from the catalog, description, chapters with subtitle', () {
    final d = _source().parseDetails(html_parser.parse(_gridDetail), Uri.parse('https://op.com/manga/one-piece'));
    expect(d.title, 'One Piece');
    expect(d.description, 'Gol D. Roger.');
    expect(d.thumbnailUrl, 'https://i.imgur.com/op.png');
    expect(d.chapters.map((c) => c.name), ['One Piece Chapter 1198', 'One Piece Chapter 1197 - Fate']);
    expect(d.chapters.first.url, 'https://op.com/chapter/one-piece-chapter-1198/');
  });

  test('table layout reads name, date and the Read button', () {
    final d = _source(layout: MangaCatalogLayout.table)
        .parseDetails(html_parser.parse(_tableDetail), Uri.parse('https://op.com/manga/unknown/'));
    expect(d.title, 'One Punch Man');
    expect(d.chapters.single.url, 'https://op.com/chapter/opm-243/');
    expect(d.chapters.single.uploadedAt, DateTime(2026, 11, 5));
  });

  test('pages prefer lazy data-src and skip placeholders; blogger keeps only Blogger images', () {
    final grid = _source().parsePages(
      html_parser.parse('<img class="js-page" src="https://cdn.op.com/1.jpg">'
          '<img class="pages__img" src="data:image/gif;base64,x" data-src="https://cdn.op.com/2.jpg">'
          '<img class="js-page" src="https://cdn.op.com/1.jpg">'),
      Uri.parse('https://op.com/chapter/x/'),
    );
    expect(grid, ['https://cdn.op.com/1.jpg', 'https://cdn.op.com/2.jpg']);

    final blogger = _source(layout: MangaCatalogLayout.blogger).parsePages(
      html_parser.parse('<img src="/cover.jpg">'
          '<img src="/lazy.gif" data-src="https://blogger.googleusercontent.com/img/a/1.jpg">'
          '<img src="https://1.bp.blogspot.com/x/2.jpg">'),
      Uri.parse('https://tog.com/manga/tower-of-god-chapter-1/'),
    );
    expect(blogger, ['https://blogger.googleusercontent.com/img/a/1.jpg', 'https://1.bp.blogspot.com/x/2.jpg']);
  });
}
