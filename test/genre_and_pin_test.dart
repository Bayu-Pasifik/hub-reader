import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/sources/filters.dart';
import 'package:hub_reader/state/core_providers.dart';
import 'package:hub_reader/state/pinned_sources_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('filterForGenre', () {
    const defs = <FilterDef>[
      SelectFilterDef('status', 'Status', [FilterOption('Semua', ''), FilterOption('Ongoing', 'ongoing')]),
      MultiSelectFilterDef('genre', 'Genre', [FilterOption('Action', 'action'), FilterOption('Drama', 'drama')]),
    ];

    test('mencocokkan opsi pilih-banyak tanpa membedakan huruf besar/kecil', () {
      final v = filterForGenre(defs, ' action ');
      expect(v, isNotNull);
      expect(v!.multi('genre'), ['action']);
    });

    test('mencocokkan opsi pilih-satu', () {
      final v = filterForGenre(defs, 'Ongoing');
      expect(v!.single('status'), 'ongoing');
    });

    test('null bila tidak ada yang cocok, kosong, atau opsi default', () {
      expect(filterForGenre(defs, 'Horror'), isNull);
      expect(filterForGenre(defs, ''), isNull);
      expect(filterForGenre(defs, 'Semua'), isNull);
      expect(filterForGenre(const [], 'Action'), isNull);
    });
  });

  group('pinned sources', () {
    Future<ProviderContainer> container() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      return ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    }

    test('toggle menyematkan lalu melepas, dan tersimpan', () async {
      final c = await container();
      addTearDown(c.dispose);
      final n = c.read(pinnedComicSourcesProvider.notifier);
      await n.toggle('a');
      await n.toggle('b');
      expect(c.read(pinnedComicSourcesProvider), {'a', 'b'});
      await n.toggle('a');
      expect(c.read(pinnedComicSourcesProvider), {'b'});
      expect(c.read(sharedPreferencesProvider).getStringList('sources.pinned.v1'), ['b']);
    });

    test('komik dan novel disimpan terpisah', () async {
      final c = await container();
      addTearDown(c.dispose);
      await c.read(pinnedComicSourcesProvider.notifier).toggle('x');
      expect(c.read(pinnedNovelSourcesProvider), isEmpty);
    });
  });
}
