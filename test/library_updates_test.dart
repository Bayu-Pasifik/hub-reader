import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/state/library_chapters.dart';
import 'package:hub_reader/state/library_updates_provider.dart';

void main() {
  List<({String url, String name, double? number})> ch(List<String> urls) => [for (final u in urls) (url: u, name: 'Bab $u', number: null)];

  test('first check records chapters without reporting them as new', () {
    expect(LibraryUpdatesNotifier.newChapters(null, ch(['a', 'b'])), isEmpty);
  });

  test('reports only chapters that were not known', () {
    final fresh = LibraryUpdatesNotifier.newChapters({'a', 'b'}, ch(['c', 'b', 'a']));
    expect(fresh.map((c) => c.url), ['c']);
  });

  test('ignores a site that changed every chapter URL', () {
    expect(LibraryUpdatesNotifier.newChapters({'a', 'b'}, ch(['x', 'y'])), isEmpty);
  });

  test('skips completed and never-read series', () {
    expect(LibraryUpdatesNotifier.shouldCheck(completed: false, started: true), isTrue);
    expect(LibraryUpdatesNotifier.shouldCheck(completed: true, started: true), isFalse);
    expect(LibraryUpdatesNotifier.shouldCheck(completed: false, started: false), isFalse);
  });

  test('detects completed status text from novel sources', () {
    expect(isCompletedStatusText('Completed'), isTrue);
    expect(isCompletedStatusText('Tamat'), isTrue);
    expect(isCompletedStatusText('Ongoing'), isFalse);
    expect(isCompletedStatusText('Not Completed'), isFalse);
    expect(isCompletedStatusText('Incomplete'), isFalse);
    expect(isCompletedStatusText(null), isFalse);
  });
}
