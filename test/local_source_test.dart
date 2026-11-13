import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/sources/local/local_source.dart';
import 'package:hub_reader/sources/source_exception.dart';
import 'package:hub_reader/ui/widgets/local_import.dart';

List<int> _zip(Map<String, List<int>> files) {
  final archive = Archive();
  for (final e in files.entries) {
    archive.addFile(ArchiveFile.bytes(e.key, e.value));
  }
  return ZipEncoder().encode(archive);
}

void main() {
  late Directory tmp;
  final source = LocalSource();

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('local_source_test');
    LocalSource.root = Directory('${tmp.path}/local')..createSync();
    LocalSource.cacheDir = Directory('${tmp.path}/cache');
    final series = Directory('${LocalSource.root!.path}/Solo Leveling')..createSync();
    File('${series.path}/Chapter 2.cbz').writeAsBytesSync(_zip({
      'p10.jpg': [10],
      'p2.jpg': [2],
      '../evil.jpg': [6],
      'notes.txt': [1],
    }));
    File('${series.path}/Chapter 10.zip').writeAsBytesSync(_zip({'1.png': [1]}));
    final folderChapter = Directory('${series.path}/Chapter 1')..createSync();
    File('${folderChapter.path}/02.jpg').writeAsBytesSync([2]);
    File('${folderChapter.path}/01.jpg').writeAsBytesSync([1]);
    File('${series.path}/description.txt').writeAsStringSync('Sinopsis lokal');
    File('${LocalSource.root!.path}/One Shot.cbz').writeAsBytesSync(_zip({'a.jpg': [1]}));
  });

  tearDown(() => tmp.delete(recursive: true));

  test('lists series and chapters in natural order', () async {
    final page = await source.popular(1);
    expect(page.items.map((m) => m.title), ['One Shot', 'Solo Leveling']);

    final details = await source.details(LocalSource.urlFor(['Solo Leveling']));
    expect(details.chapters.map((c) => c.name), ['Chapter 10', 'Chapter 2', 'Chapter 1']);
    expect(details.chapters.map((c) => c.number), [10, 2, 1]);
    expect(details.description, 'Sinopsis lokal');
    // Sampul dari bab folder (arsip belum diekstrak).
    expect(details.thumbnailUrl, endsWith('01.jpg'));

    final search = await source.search(1, 'solo');
    expect(search.items.single.title, 'Solo Leveling');
  });

  test('extracts archive pages safely and in order', () async {
    final details = await source.details(LocalSource.urlFor(['Solo Leveling']));
    final pages = await source.pages(details.chapters[1]); // Chapter 2
    expect(pages.length, 3); // p2, p10, ../evil (diganti nama)
    expect(File(pages.first).readAsBytesSync(), [6]); // "../evil.jpg" urut pertama
    expect(pages.every((p) => p.startsWith(LocalSource.cacheDir!.path)), isTrue);
    expect(File(pages[1]).readAsBytesSync(), [2]);
    expect(File(pages[2]).readAsBytesSync(), [10]);
    expect(File('${tmp.path}/evil.jpg').existsSync(), isFalse);

    final folder = await source.pages(details.chapters[2]); // Chapter 1 (folder)
    expect(folder.map((p) => p.split(RegExp(r'[\\/]')).last), ['01.jpg', '02.jpg']);
  });

  test('single archive at root is a one-chapter series', () async {
    final details = await source.details(LocalSource.urlFor(['One Shot.cbz']));
    expect(details.chapters.single.name, 'One Shot');
    expect(await source.pages(details.chapters.single), hasLength(1));
  });

  test('rejects URLs outside the local folder', () {
    expect(() => LocalSource.segmentsOf('local:/../secret'), throwsA(isA<SourceException>()));
    expect(() => LocalSource.segmentsOf('https://example.com'), throwsA(isA<SourceException>()));
    expect(LocalSource.segmentsOf(LocalSource.urlFor(['A/B', 'c d'])), ['A/B', 'c d']);
  });

  test('import copies files into a sanitized series folder', () async {
    final src = File('${tmp.path}/in.cbz')..writeAsBytesSync(_zip({'x.jpg': [1]}));
    final url = await LocalSource.importFiles('Judul: Baru?', [
      (name: 'Ch 1.cbz', saveTo: (String p) => src.copy(p)),
      (name: 'Ch 1.cbz', saveTo: (String p) => src.copy(p)),
    ]);
    final details = await source.details(url);
    expect(details.title, 'Judul_ Baru_');
    expect(details.chapters.map((c) => c.name).toSet(), {'Ch 1', 'Ch 1 (2)'});
  });

  test('guesses the series name from file names', () {
    expect(guessSeriesName(['Solo Leveling - Chapter 12.cbz', 'Solo Leveling - Chapter 13.cbz']), 'Solo Leveling');
    expect(guessSeriesName(['One_Piece_v01.cbz']), 'One Piece');
    expect(guessSeriesName(['Berserk.zip']), 'Berserk');
  });
}
