import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/state/library_updates_provider.dart';

void main() {
  List<({String url, String name})> ch(List<String> urls) => [for (final u in urls) (url: u, name: 'Bab $u')];

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
}
