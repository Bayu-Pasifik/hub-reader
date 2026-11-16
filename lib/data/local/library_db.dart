import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'library_db.g.dart';

/// Favorit. [json] = `SourceFavorite.toJson()`; kolom lain hanya untuk
/// pengurutan/pencarian.
class FavoriteRows extends Table {
  TextColumn get key => text()();
  TextColumn get json => text()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Riwayat baca. [json] = `SourceHistoryEntry.toJson()`.
class HistoryRows extends Table {
  TextColumn get key => text()();
  TextColumn get json => text()();
  DateTimeColumn get readAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Progres per bab. [json] = `SourceChapterProgress.toJson()`.
class ProgressRows extends Table {
  TextColumn get seriesKey => text()();
  TextColumn get chapterUrl => text()();
  TextColumn get json => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {seriesKey, chapterUrl};
}

/// Tombstone favorit untuk sinkron penghapusan.
class RemovedRows extends Table {
  TextColumn get key => text()();
  DateTimeColumn get removedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Penanda sekali-jalan (mis. migrasi dari SharedPreferences sudah selesai).
class MetaRows extends Table {
  TextColumn get name => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {name};
}

@DriftDatabase(tables: [FavoriteRows, HistoryRows, ProgressRows, RemovedRows, MetaRows])
class LibraryDb extends _$LibraryDb {
  LibraryDb(super.e);

  /// Database di penyimpanan aplikasi.
  static Future<LibraryDb> open() async {
    final dir = await getApplicationSupportDirectory();
    return LibraryDb(
      NativeDatabase.createInBackground(
        File(p.join(dir.path, 'library.sqlite')),
        // Isolate latar (WorkManager) membuka berkas yang sama.
        setup: (db) {
          db.execute('PRAGMA journal_mode=WAL');
          db.execute('PRAGMA busy_timeout=5000');
        },
      ),
    );
  }

  /// Untuk tes.
  factory LibraryDb.memory() => LibraryDb(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Versi berikutnya: tambahkan langkah `if (from < N)` di sini.
        },
      );
}
