import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:hub_reader/sources/filters.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/sources/templates/keyoapp.dart';

// Fixture HTML disederhanakan dari situs Keyoapp asli (kewnscans, artlapsa,
// asmotoon). Tes ini memeriksa parser saja (tanpa jaringan).

const _seriesPage = '''
<div id="searched_series_page">
  <button class="group" title="Bitter Side Cranberries" tags='["Fantasy","Action"]' data-type="manhwa" data-status="ongoing">
    <a href="/series/bitter-side-cranberries/" title="Bitter Side Cranberries">
      <div style="background-image:url(https://wsrv.nl/?url=cdn.example.org/uploads/a1&w=300)"></div>
    </a>
  </button>
  <button class="group" title="Snow Mountain" tags='["Romance","Drama"]' data-type="manhwa" data-status="completed">
    <a href="/series/snow-mountain/" title="Snow Mountain"></a>
  </button>
  <button class="group" title="Some Novel" tags='["Romance"]' data-type="novel" data-status="ongoing">
    <a href="/series/some-novel/" title="Some Novel"></a>
  </button>
</div>
''';

const _classicDetail = '''
<html><body>
<div class="grid">
  <div style="--photoURL:url(https://wsrv.nl/?url=cdn.example.org/uploads/cover&w=1000)"></div>
  <a href="/series/?genre=action">Action</a>
  <h1 class="text-2xl"> Bitter Side Cranberries </h1>
</div>
<div class="grid gap-2"><div class="font-medium"><img><span>Author</span></div><div> Charcoal </div></div>
<div class="grid gap-2"><div class="font-medium"><img><span>Status</span></div><div> ongoing </div></div>
<div class="grid gap-2"><div class="font-medium"><img><span>Type</span></div><div> manhwa </div></div>
<div id="expand_content"><p>You are everything I loved.</p></div>
<div id="chapters">
  <a href="/chapter/abc-3/" title="Chapter 3" d="Aug 3, 2026"><span class="text-sm">Chapter 3</span><img alt="Coin"></a>
  <a href="/chapter/abc-2/" title="Chapter 2" d="Aug 1, 2026"><span class="text-sm">Chapter 2</span></a>
  <a href="/chapter/abc-1/" title="Chapter 1"><span class="text-sm">Chapter 1</span><span class="text-xs">2d ago</span></a>
</div>
</body></html>
''';

const _classicReader = '''
<html><body>
<div id="pages"><img src="/placeholder.svg" uid="K7AF"><img src="/placeholder.svg" uid="Q9ZZ"></div>
<script>function loadImage(img){ let realUrl = `https://cdn.example.org/uploads/\${uid}`; }</script>
</body></html>
''';

/// Persis seperti di HTML asli: kutip ganda sebagai escape JS `"` dan
/// garis miring sebagai `\\\/` (dibangun dari kode karakter supaya escape-nya
/// tidak ikut ditafsirkan).
String get _livewireReader {
  final bs = String.fromCharCode(92);
  final q = '${bs}u0022';
  final sl = '$bs$bs$bs/';
  String page(String n) => '{${q}path$q:${q}https:$sl${sl}cdn.example.com$sl$n.jpg$q}';
  return """<html><body>
<div x-data="immersiveReader({ canRead: true, pages: JSON.parse('[${page('001')},${page('002')}]') })"></div>
</body></html>""";
}

const _v2Detail = '''
<html><head><meta property="og:image" content="https://cdn.example.org/cover.webp"></head><body>
<h1 class="l2-title">The Lazy Aristocrat</h1>
<div class="l2-meta"><span>Manga · Fantasy · Ongoing</span></div>
<div class="l2-tagline"><a href="/?browse&tag%5B%5D=fantasy">Fantasy</a><a href="/?browse&tag%5B%5D=harem">Harem</a></div>
<p id="series-desc">Luke is the languid second son.</p>
</body></html>
''';

const _v2Rows = '''
<a href="/lazy-chapter-17" class="chapter-row" data-ch-label="Chapter 17" data-ch-locked="1"></a>
<a href="/lazy-chapter-16" class="chapter-row" data-ch-label="Chapter 16" data-ch-locked="0">
  <div class="ch-date-row"><svg></svg><span class="text-xs">Oct 29, 2026</span></div>
</a>
''';

KeyoappSource _source(KeyoappVariant variant) =>
    KeyoappSource(id: 'en.x', name: 'X', baseUrl: 'https://x.org', lang: 'en', variant: variant);

void main() {
  final base = Uri.parse('https://x.org/');

  test('relative dates accept short units like "2d ago"', () {
    final now = DateTime(2026, 11, 12, 12);
    expect(parseKeyoappDate('2d ago', now: now), DateTime(2026, 11, 10, 12));
    expect(parseKeyoappDate('5 hrs ago', now: now), DateTime(2026, 11, 12, 7));
    expect(parseKeyoappDate('3mo ago', now: now), DateTime(2026, 8, 12));
    expect(parseKeyoappDate('Aug 3, 2026'), DateTime(2026, 8, 3));
  });

  test('classic /series/ is filtered on the client and skips novels', () {
    final s = _source(KeyoappVariant.classic);
    final doc = html_parser.parse(_seriesPage);
    expect(s.parseSeriesClassic(doc, base).map((m) => m.title), ['Bitter Side Cranberries', 'Snow Mountain']);
    expect(s.parseSeriesClassic(doc, base, query: 'snow').single.url, 'https://x.org/series/snow-mountain/');
    expect(
      s.parseSeriesClassic(doc, base, filters: FilterValues.empty.toggleMulti('genre', 'romance')).single.title,
      'Snow Mountain',
    );
    expect(
      s.parseSeriesClassic(doc, base, filters: FilterValues.empty.withSingle('status', 'ongoing')).single.title,
      'Bitter Side Cranberries',
    );
    expect(s.parseSeriesClassic(doc, base).first.thumbnailUrl, contains('w=480'));
  });

  test('classic details read labelled values and skip paid chapters', () {
    final d = _source(KeyoappVariant.classic).parseDetails(html_parser.parse(_classicDetail), base);
    expect(d.title, 'Bitter Side Cranberries');
    expect(d.author, 'Charcoal');
    expect(d.status, SourceMangaStatus.ongoing);
    expect(d.genres, ['Manhwa', 'Action']);
    expect(d.description, 'You are everything I loved.');
    expect(d.thumbnailUrl, contains('uploads/cover'));
    expect(d.chapters.map((c) => c.name), ['Chapter 2', 'Chapter 1']);
    expect(d.chapters.first.uploadedAt, DateTime(2026, 8, 1));
    expect(d.chapters.last.uploadedAt, isNotNull);
  });

  test('classic pages join image uids with the CDN host from the script', () {
    final pages =
        _source(KeyoappVariant.classic).parsePages(html_parser.parse(_classicReader), _classicReader, base);
    expect(pages, ['https://cdn.example.org/uploads/K7AF', 'https://cdn.example.org/uploads/Q9ZZ']);
  });

  test('livewire pages decode the JSON embedded in x-data', () {
    final pages =
        _source(KeyoappVariant.livewire).parsePages(html_parser.parse(_livewireReader), _livewireReader, base);
    expect(pages, ['https://cdn.example.com/001.jpg', 'https://cdn.example.com/002.jpg']);
  });

  test('v2 details take status from the meta line and drop locked chapters', () {
    final d = _source(KeyoappVariant.v2)
        .parseDetailsV2(html_parser.parse(_v2Detail), Uri.parse('https://x.org/lazy'), html_parser.parse(_v2Rows));
    expect(d.title, 'The Lazy Aristocrat');
    expect(d.status, SourceMangaStatus.ongoing);
    expect(d.genres, ['Fantasy', 'Harem']);
    expect(d.thumbnailUrl, 'https://cdn.example.org/cover.webp');
    expect(d.chapters.single.name, 'Chapter 16');
    expect(d.chapters.single.uploadedAt, DateTime(2026, 10, 29));
  });
}
