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
}
