import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/state/core_providers.dart';
import 'package:hub_reader/state/source_library_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('layout defaults, persists, and clamps columns', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    ProviderContainer make() => ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);

    var c = make();
    expect(c.read(libraryLayoutProvider), (display: LibraryDisplay.grid, columns: 0));
    await c.read(libraryLayoutProvider.notifier).set(display: LibraryDisplay.compact, columns: 99);
    expect(c.read(libraryLayoutProvider), (display: LibraryDisplay.compact, columns: LibraryLayoutNotifier.maxColumns));
    c.dispose();

    c = make();
    expect(c.read(libraryLayoutProvider).display, LibraryDisplay.compact);
    await c.read(libraryLayoutProvider.notifier).set(display: LibraryDisplay.list);
    expect(c.read(libraryLayoutProvider).columns, LibraryLayoutNotifier.maxColumns);
    c.dispose();
  });
}
