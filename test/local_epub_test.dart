import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/novels/local_epub.dart';
import 'package:hub_reader/sources/source_exception.dart';

List<int> _epub({bool ncx = false}) {
  final archive = Archive();
  void add(String name, String text) => archive.addFile(ArchiveFile.bytes(name, utf8.encode(text)));
  add('mimetype', 'application/epub+zip');
  add('META-INF/container.xml', '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>''');
  add('OEBPS/content.opf', '''<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Buku Uji</dc:title><dc:creator>Penulis A</dc:creator>
    <dc:description>&lt;p&gt;Sinopsis &lt;b&gt;tebal&lt;/b&gt;&lt;/p&gt;</dc:description>
    <dc:subject>Fantasi</dc:subject><dc:subject>Aksi</dc:subject>
    <meta name="cover" content="img-cover"/>
  </metadata>
  <manifest>
    ${ncx ? '<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>' : '<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>'}
    <item id="img-cover" href="images/cover.jpg" media-type="image/jpeg"/>
    <item id="cover" href="text/cover.xhtml" media-type="application/xhtml+xml"/>
    <item id="c1" href="text/ch%201.xhtml" media-type="application/xhtml+xml"/>
    <item id="c2" href="text/c2.xhtml" media-type="application/xhtml+xml"/>
    <item id="blank" href="text/blank.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine><itemref idref="cover"/><itemref idref="c1"/><itemref idref="blank"/><itemref idref="c2"/></spine>
</package>''');
  add('OEBPS/nav.xhtml', '''<html xmlns:epub="http://www.idpf.org/2007/ops"><body>
<nav epub:type="toc"><ol><li><a href="text/ch%201.xhtml">Bab Satu</a></li><li><a href="text/c2.xhtml#x">Bab Dua</a></li></ol></nav>
</body></html>''');
  add('OEBPS/toc.ncx', '''<?xml version="1.0"?><ncx xmlns="http://www.daisy.org/z3986/2005/ncx/"><navMap>
<navPoint id="a"><navLabel><text>NCX Satu</text></navLabel><content src="text/ch%201.xhtml"/></navPoint>
</navMap></ncx>''');
  add('OEBPS/text/cover.xhtml', '''<html><body><svg xmlns:xlink="http://www.w3.org/1999/xlink"><image xlink:href="../images/cover.jpg"/></svg></body></html>''');
  add('OEBPS/text/ch 1.xhtml', '''<html><body><h1>Judul</h1><p>Halo <img src="../images/cover.jpg"/> dunia.</p><img src="https://x/y.png"/></body></html>''');
  add('OEBPS/text/c2.xhtml', '<html><body><h2>Heading Dua</h2><p>Isi.</p></body></html>');
  add('OEBPS/text/blank.xhtml', '<html><body>  </body></html>');
  archive.addFile(ArchiveFile.bytes('OEBPS/images/cover.jpg', [1, 2, 3]));
  archive.addFile(ArchiveFile.bytes('../evil.txt', [6]));
  return ZipEncoder().encode(archive);
}

void main() {
  late Directory tmp;
  final source = LocalNovelSource();

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('local_epub_test');
    LocalNovelSource.root = Directory('${tmp.path}/novels')..createSync();
    LocalNovelSource.cacheDir = Directory('${tmp.path}/cache');
    File('${LocalNovelSource.root!.path}/buku.epub').writeAsBytesSync(_epub());
    File('${LocalNovelSource.root!.path}/lama.epub').writeAsBytesSync(_epub(ncx: true));
  });

  tearDown(() => tmp.delete(recursive: true));

  test('reads metadata and chapters from the nav TOC', () async {
    final details = await source.details(LocalNovelSource.novelPath('buku.epub'));
    expect(details.name, 'Buku Uji');
    expect(details.author, 'Penulis A');
    expect(details.summary, 'Sinopsis tebal');
    expect(details.genres, ['Fantasi', 'Aksi']);
    expect(details.cover, endsWith('cover.jpg'));
    // cover.xhtml hanya gambar (Sampul), blank.xhtml kosong (dilewati).
    expect(details.chapters.map((c) => c.name), ['Sampul', 'Bab Satu', 'Bab Dua']);
    expect(File('${tmp.path}/evil.txt').existsSync(), isFalse);
  });

  test('falls back to the NCX and headings', () async {
    final details = await source.details(LocalNovelSource.novelPath('lama.epub'));
    expect(details.chapters.map((c) => c.name), ['Sampul', 'NCX Satu', 'Heading Dua']);
  });

  test('chapter HTML points images at extracted files', () async {
    final details = await source.details(LocalNovelSource.novelPath('buku.epub'));
    final html = await source.chapter(details.chapters[1].path);
    expect(html, contains('<h1>Judul</h1>'));
    expect(RegExp(r'src="(file:[^"]+)"').firstMatch(html)!.group(1), endsWith('cover.jpg'));
    expect(html, contains('https://x/y.png'));
    final cover = await source.chapter(details.chapters[0].path);
    expect(cover, contains('<img src="file:'));
    expect(cover, isNot(contains('<svg')));
  });

  test('lists and searches books', () async {
    expect((await source.popular(1)).length, 2);
    expect(await source.popular(2), isEmpty);
    expect((await source.search('uji', 1)).length, 2);
    expect(await source.search('tidak ada', 1), isEmpty);
  });

  test('rejects paths outside the folder and imports with unique names', () async {
    expect(() => LocalNovelSource.parsePath('epub:/..%2Fx.epub'), throwsA(isA<SourceException>()));
    final src = File('${LocalNovelSource.root!.path}/buku.epub');
    final path = await LocalNovelSource.importFile('buku.epub', (p) => src.copy(p));
    expect(path, LocalNovelSource.novelPath('buku (2).epub'));
    await LocalNovelSource.delete(path);
    expect(File('${LocalNovelSource.root!.path}/buku (2).epub').existsSync(), isFalse);
  });
}
