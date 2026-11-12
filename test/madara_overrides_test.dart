import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/sources/source_exception.dart';
import 'package:hub_reader/sources/templates/madara.dart';

// Override selector dari Kotlin (options.vals), cadangan judul og:title,
// dekripsi "chapter protector", dan cadangan gambar bab.

final _base = Uri.parse('https://ex.com/manga/x/');

MadaraSource _source([Map<String, Object?> vals = const {}]) =>
    MadaraSource(id: 'en.ex', name: 'Ex', baseUrl: 'https://ex.com', lang: 'en', vals: vals);

void main() {
  test('only selectors the Dart parser understands are used', () {
    final s = _source({
      'mangaDetailsSelectorTitle': '.aqua-series-info__title',
      'mangaDetailsSelectorStatus': 'div.summary-heading:contains(Status) + div',
      'flag': true,
    });
    expect(s.sel('mangaDetailsSelectorTitle'), '.aqua-series-info__title');
    expect(s.sel('mangaDetailsSelectorStatus'), isNull);
    expect(s.sel('flag'), isNull);
  });

  test('detail overrides win over the defaults', () {
    final doc = html_parser.parse('''
      <h1 class="aqua-series-info__title">Aqua Title</h1>
      <div class="aqua-series-synopsis">Story.</div>
      <img class="aqua-series-cover__img" src="/cover.jpg">
      <span class="aqua-series-meta__status">Ongoing</span>
      <a class="aqua-series-genre-pill">Action</a>
    ''');
    final d = _source({
      'mangaDetailsSelectorTitle': '.aqua-series-info__title',
      'mangaDetailsSelectorDescription': '.aqua-series-synopsis',
      'mangaDetailsSelectorThumbnail': '.aqua-series-cover__img',
      'mangaDetailsSelectorStatus': '.aqua-series-meta__status',
      'mangaDetailsSelectorGenre': '.aqua-series-genre-pill',
    }).parseDetails(doc, _base);
    expect(d.title, 'Aqua Title');
    expect(d.description, 'Story.');
    expect(d.thumbnailUrl, 'https://ex.com/cover.jpg');
    expect(d.status, SourceMangaStatus.ongoing);
    expect(d.genres, ['Action']);
  });

  test('custom archive cards are read through archiveUrlSelector', () {
    final doc = html_parser.parse('''
      <div class="aqua-archive-card"><img src="/a.jpg">
        <h3 class="aqua-archive-card__title"><a href="/manga/a/">Series A</a></h3></div>
    ''');
    final items = _source({'archiveUrlSelector': '.aqua-archive-card__title a'}).parseArchive(doc, _base);
    expect(items.single.title, 'Series A');
    expect(items.single.thumbnailUrl, 'https://ex.com/a.jpg');
  });

  test('title falls back to og:title without the site suffix', () {
    final doc = html_parser.parse('''<head>
      <meta property="og:site_name" content="Toonizy">
      <meta property="og:title" content="My Stepmom - Toonizy"></head>''');
    expect(_source().parseDetails(doc, _base).title, 'My Stepmom');
  });

  test('chapter protector data decrypts like CryptoJS', () {
    // Dibuat dengan Node crypto (AES-256-CBC, EVP_BytesToKey MD5).
    const ct = 'ko9j4nx+uSxnzCknE/sPB8IRblt6vdUcp7u/CMRdWUpaqhW5NXiZOCt/1cpUbQfKJ9LoYO5NYzKholtHvMwqAg==';
    final doc = html_parser.parse('''<script id="chapter-protector-data">
      var wpmangaprotectornonce='abc123nonce';var chapter_data='{"ct":"$ct","s":"0011223344556677"}';
    </script>''');
    expect(MadaraSource.decryptProtectedPages(doc.getElementById('chapter-protector-data')!),
        ['https://x.com/1.jpg', 'https://x.com/2.jpg']);
  });

  test('pages fall back to canvas data-page-url and plain reading-content images', () {
    final canvas = html_parser.parse('<div class="reading-content">'
        '<canvas class="protected-chapter-canvas" data-page-url="/p/01.webp"></canvas>'
        '<canvas data-page-url="/p/02.webp"></canvas></div>');
    expect(_source().parsePages(canvas, _base), ['https://ex.com/p/01.webp', 'https://ex.com/p/02.webp']);

    final plain = html_parser.parse("<div class='reading-content'><div class='text-center'>"
        "<img src='https://img.ex.com/1.jpg' /><img src='https://img.ex.com/2.jpg' /></div></div>");
    expect(_source().parsePages(plain, _base), ['https://img.ex.com/1.jpg', 'https://img.ex.com/2.jpg']);
  });

  test('a TLS handshake reset is reported as no connection', () {
    final error = DioException(
      requestOptions: RequestOptions(path: 'https://ex.com'),
      error: const HandshakeException('TLSV1_ALERT_INTERNAL_ERROR'),
    );
    expect(toSourceException(error).kind, SourceErrorKind.noConnection);
  });
}
