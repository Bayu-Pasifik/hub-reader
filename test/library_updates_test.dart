import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/state/library_chapters.dart';
import 'package:hub_reader/state/library_updates_provider.dart';

void main() {
  rulesTests();
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

void rulesTests() {
  group('update rules', () {
    test('defaults skip completed and unstarted only', () {
      const r = LibraryUpdateRules();
      expect(LibraryUpdatesNotifier.shouldCheck(completed: true, started: true, rules: r), isFalse);
      expect(LibraryUpdatesNotifier.shouldCheck(completed: false, started: false, rules: r), isFalse);
      expect(LibraryUpdatesNotifier.shouldCheck(completed: false, started: true, hasUnread: true, rules: r), isTrue);
    });

    test('rules can be relaxed or tightened', () {
      const relaxed = LibraryUpdateRules(skipCompleted: false, skipUnstarted: false);
      expect(LibraryUpdatesNotifier.shouldCheck(completed: true, started: false, rules: relaxed), isTrue);
      const strict = LibraryUpdateRules(skipUnread: true);
      expect(LibraryUpdatesNotifier.shouldCheck(completed: false, started: true, hasUnread: true, rules: strict), isFalse);
    });

    test('excluded categories only skip when all categories are excluded', () {
      const r = LibraryUpdateRules(excludedCategories: ['Pause']);
      bool check(List<String> c) => LibraryUpdatesNotifier.shouldCheck(completed: false, started: true, categories: c, rules: r);
      expect(check(['Pause']), isFalse);
      expect(check(['Pause', 'Aktif']), isTrue);
      expect(check([]), isTrue);
    });
  });
}
