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

  test('tampilan per kategori tersimpan, diwarisi bila tidak ada, dan ikut rename/hapus kategori', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    ProviderContainer make() {
      final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(c.dispose);
      return c;
    }

    final c = make();
    await c.read(libraryCategoriesProvider.notifier).add('Baca');
    await c.read(libraryViewProvider.notifier).set(sort: LibrarySort.title);
    final custom = (
      sort: LibrarySort.lastRead,
      reversed: true,
      kind: LibraryKind.comic,
      unreadOnly: false,
      downloadedOnly: true,
      startedOnly: true,
      unstartedOnly: false,
      trackedOnly: true,
      trackStatus: 'completed',
    );
    await c.read(libraryCategoryViewsProvider.notifier).set('Baca', custom);

    final c2 = make();
    final global = c2.read(libraryViewProvider);
    final per = c2.read(libraryCategoryViewsProvider);
    expect(effectiveLibraryView(global, per, 'Baca'), custom);
    expect(effectiveLibraryView(global, per, 'Lain').sort, LibrarySort.title); // diwarisi
    expect(effectiveLibraryView(global, per, null).sort, LibrarySort.title); // tab Semua

    await c2.read(libraryCategoriesProvider.notifier).rename('Baca', 'Sedang dibaca');
    expect(c2.read(libraryCategoryViewsProvider).keys, ['Sedang dibaca']);
    expect(c2.read(libraryCategoryViewsProvider)['Sedang dibaca'], custom);
    await c2.read(libraryCategoriesProvider.notifier).remove('Sedang dibaca');
    expect(c2.read(libraryCategoryViewsProvider), isEmpty);
  });

  test('tampilan lama (4 kolom) tetap terbaca; balik urutan & sudah dimulai default mati', () {
    final v = decodeLibraryView(['title', 'novel', '1', '0']);
    expect([v.reversed, v.startedOnly], [false, false]);
    expect(isLibraryViewFiltered(defaultLibraryView), isFalse);
    expect(isLibraryViewFiltered(decodeLibraryView(['added', 'all', '0', '0', '1'])), isTrue);
    expect(decodeLibraryView(encodeLibraryView(v)), v);
  });

  test('filter belum-dibaca & dilacak serta urutan baru tersimpan; tampilan 6 kolom lama default mati', () {
    final old = decodeLibraryView(['title', 'all', '0', '0', '0', '1']);
    expect([old.unstartedOnly, old.trackedOnly], [false, false]);
    final v = decodeLibraryView(['source', 'all', '0', '0', '0', '0', '1', '1']);
    expect([v.sort, v.unstartedOnly, v.trackedOnly], [LibrarySort.source, true, true]);
    expect(decodeLibraryView(encodeLibraryView(v)), v);
    expect(isLibraryViewFiltered(v), isTrue);
    expect(decodeLibraryView(['updated']).sort, LibrarySort.updated);
    // Status tracker: format lama tanpa kolom ke-9 = tidak memfilter.
    expect(decodeLibraryView(['added', 'all', '0', '0', '0', '0', '0', '1']).trackStatus, '');
    final withStatus = decodeLibraryView(['added', 'all', '0', '0', '0', '0', '0', '0', 'completed']);
    expect(withStatus.trackStatus, 'completed');
    expect(isLibraryViewFiltered(withStatus), isTrue);
    expect(decodeLibraryView(encodeLibraryView(withStatus)), withStatus);
  });
}
