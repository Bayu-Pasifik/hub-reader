import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/data/models/source_library.dart';
import 'package:hub_reader/state/library_chapters.dart';
import 'package:hub_reader/state/migration.dart';

void main() {
  SourceChapterProgress p(bool done) => SourceChapterProgress(page: 0, total: 0, done: done, updatedAt: DateTime(2026));

  test('highestReadNumber picks the highest finished chapter number', () {
    final chapters = <LibraryChapter>[
      (url: 'a', name: 'Bab 1', number: 1),
      (url: 'b', name: 'Bab 2', number: 2),
      (url: 'c', name: 'Bab 3', number: 3),
      (url: 'x', name: 'Ekstra', number: null),
    ];
    expect(highestReadNumber(chapters, {'a': p(true), 'b': p(true), 'c': p(false), 'x': p(true)}), 2);
    expect(highestReadNumber(chapters, {}), isNull);
  });

  test('libraryChapterNumber falls back to the chapter title', () {
    expect(libraryChapterNumber('Chapter 12.5 - Judul', null), 12.5);
    expect(libraryChapterNumber('Bab 7', 7), 7);
    expect(libraryChapterNumber('Bab 7', -1), 7);
  });
}
