import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/data/local/library_db.dart';

void main() {
  test('drift in-memory jalan di flutter test', () async {
    final db = LibraryDb.memory();
    addTearDown(db.close);
    await db.into(db.favoriteRows).insert(
          FavoriteRowsCompanion.insert(key: 's|u', json: '{}', addedAt: DateTime(2026)),
        );
    final rows = await db.select(db.favoriteRows).get();
    expect(rows.single.key, 's|u');
  });
}
