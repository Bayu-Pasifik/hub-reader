import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/state/browse_layout_provider.dart';
import 'package:hub_reader/state/core_providers.dart';
import 'package:hub_reader/state/source_library_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('browse layout: default, tersimpan terpisah untuk komik dan novel, kolom dibatasi', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    ProviderContainer make() => ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);

    var c = make();
    expect(c.read(comicBrowseLayoutProvider), (display: LibraryDisplay.grid, columns: 0));
    expect(c.read(novelBrowseLayoutProvider), (display: LibraryDisplay.grid, columns: 0));

    await c.read(comicBrowseLayoutProvider.notifier).set(display: LibraryDisplay.list);
    await c.read(novelBrowseLayoutProvider.notifier).set(display: LibraryDisplay.compact, columns: 99);
    c.dispose();

    c = make();
    expect(c.read(comicBrowseLayoutProvider).display, LibraryDisplay.list);
    expect(c.read(novelBrowseLayoutProvider), (display: LibraryDisplay.compact, columns: BrowseLayoutNotifier.maxColumns));
    // Tidak mengubah tampilan Favorit.
    expect(c.read(libraryLayoutProvider).display, LibraryDisplay.grid);
    c.dispose();
  });
}
