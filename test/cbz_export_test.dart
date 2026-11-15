import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/data/local/cbz_export.dart';
import 'package:hub_reader/data/models/download.dart';

void main() {
  test('builds a CBZ with renumbered pages and ComicInfo.xml', () async {
    final dir = await Directory.systemTemp.createTemp('cbz_test');
    addTearDown(() => dir.delete(recursive: true));
    final paths = <String>[];
    for (final (i, name) in ['b.png', 'a.jpg', 'c'].indexed) {
      final f = File('${dir.path}${Platform.pathSeparator}$name');
      await f.writeAsBytes([i, i, i]);
      paths.add(f.path);
    }
    final bytes = await CbzExport.build(pagePaths: paths, series: 'A & B', title: 'Bab <1>');
    final archive = ZipDecoder().decodeBytes(bytes);
    expect(archive.files.map((f) => f.name), ['001.png', '002.jpg', '003.jpg', 'ComicInfo.xml']);
    expect(archive.findFile('002.jpg')!.content, [1, 1, 1]);
    final info = String.fromCharCodes(archive.findFile('ComicInfo.xml')!.content);
    expect(info, contains('<Series>A &amp; B</Series>'));
    expect(info, contains('<Title>Bab &lt;1&gt;</Title>'));
    expect(info, contains('<PageCount>3</PageCount>'));
  });

  test('file name strips illegal characters', () {
    final c = DownloadedChapter(
      sourceId: 's',
      mangaUrl: '/m',
      mangaTitle: 'Judul: Seri?',
      chapterUrl: '/c',
      chapterName: 'Bab 1/2',
      relativeDir: 'd',
      files: const [],
      downloadedAt: DateTime(2026),
    );
    expect(CbzExport.fileName(c), 'Judul_ Seri_ - Bab 1_2.cbz');
  });
}
