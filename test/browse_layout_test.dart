import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/state/browse_layout_provider.dart';
import 'package:hub_reader/state/core_providers.dart';
import 'package:hub_reader/state/source_library_providers.dart' show LibraryDisplay, libraryLayoutProvider;
import 'package:hub_reader/state/browse_layout_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('browse layout: default, tersimpan terpisah untuk komik dan novel, kolom dibatasi', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    ProviderContainer make() => ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);

    var c = make();
    expect(c.read(comicBrowseLayoutProvider), (display: BrowseDisplay.grid, columns: 0));
    expect(c.read(novelBrowseLayoutProvider), (display: BrowseDisplay.grid, columns: 0));

    await c.read(comicBrowseLayoutProvider.notifier).set(display: BrowseDisplay.list);
    await c.read(novelBrowseLayoutProvider.notifier).set(display: BrowseDisplay.compact, columns: 99);
    c.dispose();

    c = make();
    expect(c.read(comicBrowseLayoutProvider).display, BrowseDisplay.list);
    expect(c.read(novelBrowseLayoutProvider), (display: BrowseDisplay.compact, columns: BrowseLayoutNotifier.maxColumns));
    // Tidak mengubah tampilan Favorit.
    expect(c.read(libraryLayoutProvider).display, LibraryDisplay.grid);
    c.dispose();
  });

  test('mode satu kolom tersimpan dan nama lama tetap terbaca', () async {
    SharedPreferences.setMockInitialValues({
      'browse.novel.layout.v1': ['coverOnly', '3'],
    });
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    expect(c.read(novelBrowseLayoutProvider), (display: BrowseDisplay.coverOnly, columns: 3));
    await c.read(novelBrowseLayoutProvider.notifier).set(display: BrowseDisplay.wideCard);
    expect(c.read(novelBrowseLayoutProvider).display.isSingleColumn, isTrue);
    await c.read(novelBrowseLayoutProvider.notifier).set(display: BrowseDisplay.denseList);
    expect(c.read(novelBrowseLayoutProvider).display, BrowseDisplay.denseList);
    expect(BrowseDisplay.grid.isSingleColumn, isFalse);
    c.dispose();
  });
}
