import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/data/models/source_library.dart';
import 'package:hub_reader/state/core_providers.dart';
import 'package:hub_reader/state/source_library_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('favorite categories survive JSON and follow rename/delete', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    const item = SourceLibraryItem(sourceId: 's', url: 'u', title: 'T');
    await c.read(sourceFavoritesProvider.notifier).toggle(item);
    final cats = c.read(libraryCategoriesProvider.notifier);
    expect(await cats.add('Baca'), isTrue);
    expect(await cats.add('Baca'), isFalse);
    await cats.add('Nanti');
    await c.read(sourceFavoritesProvider.notifier).setCategories(item.key, ['Baca', 'Nanti']);

    final restored = SourceFavorite.tryParse(c.read(sourceFavoritesProvider).single.toJson())!;
    expect(restored.categories, ['Baca', 'Nanti']);

    await cats.rename('Baca', 'Sedang dibaca');
    expect(c.read(sourceFavoritesProvider).single.categories, ['Sedang dibaca', 'Nanti']);
    await cats.remove('Nanti');
    expect(c.read(sourceFavoritesProvider).single.categories, ['Sedang dibaca']);
    expect(c.read(libraryCategoriesProvider), ['Sedang dibaca']);
  });

  test('downloadedOnly filter persists and defaults off for old saved views', () async {
    SharedPreferences.setMockInitialValues({
      'library.view.v1': ['title', 'novel', '1'],
    });
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    expect(c.read(libraryViewProvider).downloadedOnly, isFalse);
    expect(c.read(libraryViewProvider).unreadOnly, isTrue);

    await c.read(libraryViewProvider.notifier).set(downloadedOnly: true);
    final c2 = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c2.dispose);
    final v = c2.read(libraryViewProvider);
    expect(v.downloadedOnly, isTrue);
    expect(v.unreadOnly, isTrue);
    expect(v.kind, LibraryKind.novel);
    expect(v.sort, LibrarySort.title);
  });
}
