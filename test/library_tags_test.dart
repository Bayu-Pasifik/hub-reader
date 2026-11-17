import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/data/models/source_library.dart';
import 'package:hub_reader/state/core_providers.dart';
import 'package:hub_reader/state/source_library_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

SourceLibraryItem _item(String id) => SourceLibraryItem(sourceId: 's', url: 'u$id', title: 'T$id');

Future<ProviderContainer> _make() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('normalizeTags: pangkas, buang kosong dan kembar tanpa beda huruf', () {
    expect(normalizeTags([' Isekai ', 'isekai', '', '  ', 'Tamat']), ['Isekai', 'Tamat']);
  });

  test('tag favorit ikut JSON, dan format lama tanpa tag tetap terbaca', () {
    final fav = SourceFavorite(item: _item('a'), addedAt: DateTime(2026), tags: const ['isekai']);
    expect(SourceFavorite.tryParse(fav.toJson())!.tags, ['isekai']);
    final json = fav.toJson()..remove('tags');
    expect(SourceFavorite.tryParse(json)!.tags, isEmpty);
    expect(SourceFavorite(item: _item('b'), addedAt: DateTime(2026)).toJson().containsKey('tags'), isFalse);
  });

  test('setTags, daftar semua tag, ganti nama, dan hapus tag', () async {
    final c = await _make();
    final favs = c.read(sourceFavoritesProvider.notifier);
    await favs.toggle(_item('a'));
    await favs.toggle(_item('b'));
    await favs.setTags(_item('a').key, ['Isekai', 'tamat', 'isekai']);
    await favs.setTags(_item('b').key, ['Tamat']);
    // "tamat" dan "Tamat" dianggap tag yang sama: hanya satu yang muncul.
    expect(c.read(libraryTagsProvider).map((t) => t.toLowerCase()), ['isekai', 'tamat']);

    await favs.renameTag('tamat', 'Selesai');
    final byKey = {for (final f in c.read(sourceFavoritesProvider)) f.item.key: f.tags};
    expect(byKey[_item('a').key], ['Isekai', 'Selesai']);
    expect(byKey[_item('b').key], ['Selesai']);

    await favs.renameTag('Isekai', null);
    expect(c.read(sourceFavoritesProvider).any((f) => f.tags.contains('Isekai')), isFalse);
  });

  test('tag di filter tersimpan; format lama tanpa kolom tag default kosong', () {
    final v = decodeLibraryView(['added', 'all', '0', '0', '0', '0', '0', '0', '', 'isekai']);
    expect(v.tag, 'isekai');
    expect(isLibraryViewFiltered(v), isTrue);
    expect(decodeLibraryView(encodeLibraryView(v)), v);
    expect(decodeLibraryView(['added', 'all', '0', '0', '0', '0', '0', '0', 'completed']).tag, '');
  });
}
