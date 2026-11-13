import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/novels/epub_writer.dart';
import 'package:hub_reader/novels/local_epub.dart';
import 'package:xml/xml.dart';

void main() {
  test('sanitize turns site HTML into well-formed XHTML', () {
    final out = EpubWriter.sanitize(
      '<div class="x"><p style="a">Halo &amp; <b>dunia</b><br>baris</p><script>evil()</script>'
      '<img src="https://x/y.png"><span>teks</span></div><div>baris div</div><p>a < b</p>',
    );
    expect(out, '<p>Halo &amp; <b>dunia</b><br/>baris</p>teks<p>baris div</p><p>a &lt; b</p>');
    XmlDocument.parse('<root>$out</root>'); // tidak melempar
  });

  test('written EPUB is valid and reads back', () async {
    final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0]);
    final bytes = EpubWriter(
      title: 'Novel <Uji> & Co',
      author: 'Penulis',
      description: 'Sinopsis',
      subjects: const ['Fantasi'],
      cover: png,
      chapters: const [
        EpubChapter(title: 'Bab 1', html: '<p>Satu</p>'),
        EpubChapter(title: 'Bab 2', html: '<h2>Bab 2</h2><p>Dua</p>'),
      ],
      modified: DateTime.utc(2026, 11, 13),
    ).build();

    final archive = ZipDecoder().decodeBytes(bytes);
    expect(archive.files.first.name, 'mimetype');
    for (final f in archive.files.where((f) => f.name.endsWith('.xhtml') || f.name.endsWith('.opf'))) {
      XmlDocument.parse(String.fromCharCodes(f.content)); // semua XML valid
    }
    final ch2 = String.fromCharCodes(archive.findFile('OEBPS/chapter-0002.xhtml')!.content);
    expect(RegExp('<h2>').allMatches(ch2).length, 1); // judul tidak dobel

    final tmp = await Directory.systemTemp.createTemp('epub_writer_test');
    addTearDown(() => tmp.delete(recursive: true));
    LocalNovelSource.root = Directory('${tmp.path}/novels')..createSync();
    LocalNovelSource.cacheDir = Directory('${tmp.path}/cache');
    File('${LocalNovelSource.root!.path}/out.epub').writeAsBytesSync(bytes);
    final details = await LocalNovelSource().details(LocalNovelSource.novelPath('out.epub'));
    expect(details.name, 'Novel <Uji> & Co');
    expect(details.author, 'Penulis');
    expect(details.cover, endsWith('cover.png'));
    expect(details.chapters.map((c) => c.name), ['Sampul', 'Bab 1', 'Bab 2']);
  });
}
