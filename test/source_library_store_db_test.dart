import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/data/local/backup.dart';
import 'package:hub_reader/data/local/library_db.dart';
import 'package:hub_reader/data/local/source_library_store.dart';
import 'package:hub_reader/data/models/source_library.dart';
import 'package:shared_preferences/shared_preferences.dart';

SourceFavorite _fav(String id, {int day = 1, List<String> cats = const []}) => SourceFavorite(
      item: SourceLibraryItem(sourceId: 's', url: 'https://x/$id', title: 'T$id'),
      addedAt: DateTime(2026, 11, day),
      categories: cats,
    );

SourceChapterProgress _prog(int page) =>
    SourceChapterProgress(page: page, total: 10, done: false, updatedAt: DateTime(2026, 11, 2));

Future<SharedPreferences> _prefs([Map<String, Object> v = const {}]) async {
  SharedPreferences.setMockInitialValues(v);
  return SharedPreferences.getInstance();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late LibraryDb db;
  setUp(() => db = LibraryDb.memory());
  tearDown(() => db.close());

  test('migrasi dari prefs lama: data pindah ke database, kunci lama tetap', () async {
    final legacy = SourceLibraryStore(await _prefs());
    await legacy.writeFavorites([_fav('a', day: 3, cats: ['Aksi']), _fav('b', day: 1)]);
    await legacy.writeProgress({
      's|https://x/a': {'c1': _prog(4)},
    });
    await legacy.writeRemoved({'s|gone': DateTime(2026, 11, 5)});
    final prefs = await SharedPreferences.getInstance();

    final store = await SourceLibraryStore.open(prefs, db);
    expect(store.usesDatabase, isTrue);
    expect(store.readFavorites().map((f) => f.item.title), ['Ta', 'Tb']); // terbaru di atas
    expect(store.readFavorites().first.categories, ['Aksi']);
    expect(store.readProgress()['s|https://x/a']!['c1']!.page, 4);
    expect(store.readRemoved()['s|gone'], DateTime(2026, 11, 5));
    expect(prefs.getString('source_library.favorites.v1'), isNotNull, reason: 'kunci lama dipertahankan untuk rollback');
  });

  test('migrasi hanya sekali: perubahan di prefs lama sesudahnya diabaikan', () async {
    final prefs = await _prefs();
    final first = await SourceLibraryStore.open(prefs, db);
    await first.writeFavorites([_fav('a')]);
    await prefs.setString('source_library.favorites.v1', '[]'); // prefs basi

    final second = await SourceLibraryStore.open(prefs, db);
    expect(second.readFavorites(), hasLength(1));
  });

  test('tulis lalu buka ulang: favorit, riwayat, progres, tombstone bertahan', () async {
    final prefs = await _prefs();
    final store = await SourceLibraryStore.open(prefs, db);
    await store.writeFavorites([_fav('a'), _fav('b')]);
    await store.writeFavorites([_fav('a')]); // b dihapus
    await store.writeProgress({
      's|a': {'c1': _prog(1), 'c2': _prog(2)},
    });
    await store.writeProgress({
      's|a': {'c1': _prog(7)}, // c1 berubah, c2 dihapus
    });
    await store.writeRemoved({'s|b': DateTime(2026, 11, 9)});

    final reopened = await SourceLibraryStore.open(prefs, db);
    expect(reopened.readFavorites().map((f) => f.item.title), ['Ta']);
    expect(reopened.readProgress()['s|a']!.keys, ['c1']);
    expect(reopened.readProgress()['s|a']!['c1']!.page, 7);
    expect(reopened.readRemoved().keys, ['s|b']);
  });

  test('cadangan memuat isi database dengan kunci lama; restore memulihkan ke database', () async {
    final prefs = await _prefs();
    final store = await SourceLibraryStore.open(prefs, db);
    await store.writeFavorites([_fav('a', cats: ['Aksi'])]);
    await store.writeProgress({
      's|a': {'c1': _prog(3)},
    });

    final backup = jsonDecode(jsonEncode(await AppBackup.create(prefs, includeSecrets: false, library: store)));
    final saved = (backup['prefs'] as Map)['source_library.favorites.v1'] as Map;
    expect(jsonDecode(saved['v'] as String), hasLength(1), reason: 'format cadangan v1 tidak berubah');

    // Pulihkan ke instalasi lain yang kosong.
    final db2 = LibraryDb.memory();
    addTearDown(db2.close);
    final prefs2 = await _prefs();
    final store2 = await SourceLibraryStore.open(prefs2, db2);
    expect(store2.readFavorites(), isEmpty);
    await AppBackup.restore(prefs2, backup, library: store2);
    expect(store2.readFavorites().single.categories, ['Aksi']);
    expect(store2.readProgress()['s|a']!['c1']!.page, 3);
  });

  test('restore menimpa isi database yang ada', () async {
    final prefs = await _prefs();
    final store = await SourceLibraryStore.open(prefs, db);
    await store.writeFavorites([_fav('lama')]);
    final backup = jsonDecode(jsonEncode({
      'format': AppBackup.format,
      'version': 1,
      'prefs': {
        'source_library.favorites.v1': {'t': 's', 'v': jsonEncode([_fav('baru').toJson()])},
      },
    }));
    await AppBackup.restore(prefs, backup, library: store);
    expect(store.readFavorites().map((f) => f.item.title), ['Tbaru']);
  });

  test('database gagal dibuka: jatuh kembali ke prefs', () async {
    final prefs = await _prefs();
    final store = await SourceLibraryStore.openOrFallback(prefs, () async => throw StateError('rusak'));
    expect(store.usesDatabase, isFalse);
    await store.writeFavorites([_fav('a')]);
    expect(store.readFavorites(), hasLength(1));
  });
}
