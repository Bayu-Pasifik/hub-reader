import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/opds/opds_client.dart';

const _feed = '''<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xmlns:opds="http://opds-spec.org/2010/catalog">
  <title>Perpustakaan</title>
  <link rel="self" href="/opds/v1.2/catalog" type="application/atom+xml;profile=opds-catalog;kind=navigation"/>
  <link rel="search" href="/opds/v1.2/search?query={searchTerms}" type="application/atom+xml"/>
  <link rel="next" href="/opds/v1.2/catalog?page=2" type="application/atom+xml;profile=opds-catalog"/>
  <entry>
    <title>Komik Baru</title>
    <summary>Terbaru</summary>
    <link rel="subsection" href="/opds/v1.2/new" type="application/atom+xml;profile=opds-catalog;kind=acquisition"/>
  </entry>
  <entry>
    <title>Buku Satu</title>
    <author><name>Penulis A</name></author>
    <link rel="http://opds-spec.org/image/thumbnail" href="/cover/1.jpg" type="image/jpeg"/>
    <link rel="http://opds-spec.org/acquisition" href="/dl/1.epub" type="application/epub+zip"/>
    <link rel="http://opds-spec.org/acquisition/open-access" href="/dl/1.pdf" type="application/pdf"/>
  </entry>
</feed>''';

void main() {
  final base = Uri.parse('http://nas.local:8080/opds/v1.2/catalog');
  final feed = OpdsClient.parse(_feed, base);

  test('judul, halaman berikut, dan templat pencarian', () {
    expect(feed.title, 'Perpustakaan');
    expect(feed.next, 'http://nas.local:8080/opds/v1.2/catalog?page=2');
    expect(feed.searchTemplate, 'http://nas.local:8080/opds/v1.2/search?query={searchTerms}');
  });

  test('sub-katalog menjadi navigasi', () {
    final e = feed.entries.first;
    expect(e.isBook, isFalse);
    expect(e.navigateTo, 'http://nas.local:8080/opds/v1.2/new');
  });

  test('buku punya sampul, penulis, dan format unduhan', () {
    final e = feed.entries.last;
    expect(e.isBook, isTrue);
    expect(e.navigateTo, isNull);
    expect(e.author, 'Penulis A');
    expect(e.thumbnail, 'http://nas.local:8080/cover/1.jpg');
    expect(e.acquisitions.map((a) => a.extension), ['epub', 'pdf']);
    expect(e.acquisitions.map((a) => a.importable), [true, false]);
  });

  test('header Basic auth hanya bila ada pengguna', () {
    expect(const OpdsServer(id: '1', name: 'a', url: 'http://x').headers, isEmpty);
    expect(
      const OpdsServer(id: '1', name: 'a', url: 'http://x', username: 'u', password: 'p').headers['Authorization'],
      'Basic dTpw',
    );
  });
}
