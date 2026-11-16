import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/json.dart';
import '../models/source_library.dart';
import 'library_db.dart';

/// Favorit, riwayat, progres baca, dan tombstone dari sumber on-device.
///
/// Penyimpanan utama adalah database SQLite ([LibraryDb]). Pembacaan tetap
/// sinkron lewat cache memori yang dimuat saat [open]; penulisan memperbarui
/// cache lalu menulis selisihnya ke database. Tanpa database (tes, atau
/// database gagal dibuka) data disimpan sebagai JSON di SharedPreferences
/// seperti sebelum 3.0.
class SourceLibraryStore {
  SourceLibraryStore(this._prefs) : _db = null;

  SourceLibraryStore._withDb(this._prefs, LibraryDb this._db);

  final SharedPreferences _prefs;
  final LibraryDb? _db;

  static const _favoritesKey = 'source_library.favorites.v1';
  static const _historyKey = 'source_library.history.v1';
  static const _progressKey = 'source_library.progress.v1';
  static const _removedKey = 'source_library.removed.v1';
  static const _migratedMeta = 'migrated_from_prefs.v1';

  /// Kunci prefs lama (dipakai juga oleh cadangan agar formatnya tidak berubah).
  static const legacyKeys = [_favoritesKey, _historyKey, _progressKey, _removedKey];

  // Cache (hanya terisi bila memakai database).
  List<SourceFavorite> _favorites = const [];
  List<SourceHistoryEntry> _history = const [];
  Map<String, Map<String, SourceChapterProgress>> _progress = const {};
  Map<String, DateTime> _removed = const {};

  bool get usesDatabase => _db != null;

  /// Buka penyimpanan. Memigrasikan data dari SharedPreferences sekali saja;
  /// kunci lama dibiarkan sebagai cadangan untuk rollback.
  static Future<SourceLibraryStore> open(SharedPreferences prefs, LibraryDb db) async {
    final store = SourceLibraryStore._withDb(prefs, db);
    final migrated = await (db.select(db.metaRows)..where((t) => t.name.equals(_migratedMeta))).getSingleOrNull();
    if (migrated == null) {
      await store._importFromPrefs();
      await db.into(db.metaRows).insertOnConflictUpdate(MetaRowsCompanion.insert(name: _migratedMeta, value: '1'));
    }
    await store._load();
    return store;
  }

  /// Buka database; bila gagal, jatuh kembali ke penyimpanan prefs.
  static Future<SourceLibraryStore> openOrFallback(SharedPreferences prefs, Future<LibraryDb> Function() openDb) async {
    try {
      return await open(prefs, await openDb());
    } catch (e, st) {
      debugPrint('SourceLibraryStore: database gagal dibuka, pakai prefs ($e)\n$st');
      return SourceLibraryStore(prefs);
    }
  }

  // ----------------------------------------------------------------- baca

  List<SourceFavorite> readFavorites() => usesDatabase ? _favorites : _readList(_favoritesKey, SourceFavorite.tryParse);

  List<SourceHistoryEntry> readHistory() => usesDatabase ? _history : _readList(_historyKey, SourceHistoryEntry.tryParse);

  /// `{kunci seri: {URL bab: progres}}`
  Map<String, Map<String, SourceChapterProgress>> readProgress() => usesDatabase ? _progress : _readProgressPrefs();

  /// Penanda hapus favorit (tombstone): `{kunci seri: waktu dihapus}`.
  Map<String, DateTime> readRemoved() => usesDatabase ? Map.of(_removed) : _readRemovedPrefs();

  // ---------------------------------------------------------------- tulis

  Future<void> writeFavorites(List<SourceFavorite> entries) async {
    final db = _db;
    if (db == null) return _write(_favoritesKey, entries.map((e) => e.toJson()));
    final next = {for (final e in entries) e.item.key: e};
    final old = {for (final e in _favorites) e.item.key: e};
    _favorites = List.unmodifiable(entries);
    await db.batch((b) {
      for (final e in next.entries) {
        if (old[e.key] case final prev? when identical(prev, e.value) || _same(prev.toJson(), e.value.toJson())) continue;
        b.insert(
          db.favoriteRows,
          FavoriteRowsCompanion.insert(key: e.key, json: jsonEncode(e.value.toJson()), addedAt: e.value.addedAt),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final k in old.keys) {
        if (!next.containsKey(k)) b.deleteWhere(db.favoriteRows, (t) => t.key.equals(k));
      }
    });
  }

  Future<void> writeHistory(List<SourceHistoryEntry> entries) async {
    final db = _db;
    if (db == null) return _write(_historyKey, entries.map((e) => e.toJson()));
    final next = {for (final e in entries) e.item.key: e};
    final old = {for (final e in _history) e.item.key: e};
    _history = List.unmodifiable(entries);
    await db.batch((b) {
      for (final e in next.entries) {
        if (old[e.key] case final prev? when identical(prev, e.value) || _same(prev.toJson(), e.value.toJson())) continue;
        b.insert(
          db.historyRows,
          HistoryRowsCompanion.insert(key: e.key, json: jsonEncode(e.value.toJson()), readAt: e.value.readAt),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final k in old.keys) {
        if (!next.containsKey(k)) b.deleteWhere(db.historyRows, (t) => t.key.equals(k));
      }
    });
  }

  Future<void> writeProgress(Map<String, Map<String, SourceChapterProgress>> progress) async {
    final db = _db;
    if (db == null) {
      return _prefs.setString(
        _progressKey,
        jsonEncode({
          for (final s in progress.entries) s.key: {for (final c in s.value.entries) c.key: c.value.toJson()},
        }),
      ).then((_) {});
    }
    final old = _progress;
    _progress = progress;
    await db.batch((b) {
      for (final s in progress.entries) {
        final before = old[s.key];
        if (identical(before, s.value)) continue;
        for (final c in s.value.entries) {
          final prev = before?[c.key];
          if (prev != null && (identical(prev, c.value) || _same(prev.toJson(), c.value.toJson()))) continue;
          b.insert(
            db.progressRows,
            ProgressRowsCompanion.insert(
              seriesKey: s.key,
              chapterUrl: c.key,
              json: jsonEncode(c.value.toJson()),
              updatedAt: c.value.updatedAt,
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      }
      for (final s in old.entries) {
        final now = progress[s.key];
        for (final c in s.value.keys) {
          if (now == null || !now.containsKey(c)) {
            b.deleteWhere(db.progressRows, (t) => t.seriesKey.equals(s.key) & t.chapterUrl.equals(c));
          }
        }
      }
    });
  }

  Future<void> writeRemoved(Map<String, DateTime> removed) async {
    final db = _db;
    if (db == null) {
      return _prefs
          .setString(_removedKey, jsonEncode({for (final e in removed.entries) e.key: e.value.toIso8601String()}))
          .then((_) {});
    }
    final old = _removed;
    _removed = Map.of(removed);
    await db.batch((b) {
      for (final e in removed.entries) {
        if (old[e.key] == e.value) continue;
        b.insert(
          db.removedRows,
          RemovedRowsCompanion.insert(key: e.key, removedAt: e.value),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final k in old.keys) {
        if (!removed.containsKey(k)) b.deleteWhere(db.removedRows, (t) => t.key.equals(k));
      }
    });
  }

  // ----------------------------------------------------- cadangan / impor

  /// Isi penyimpanan sebagai string JSON berformat prefs lama, untuk cadangan.
  Map<String, String> exportLegacy() => {
        _favoritesKey: jsonEncode(readFavorites().map((e) => e.toJson()).toList()),
        _historyKey: jsonEncode(readHistory().map((e) => e.toJson()).toList()),
        _progressKey: jsonEncode({
          for (final s in readProgress().entries) s.key: {for (final c in s.value.entries) c.key: c.value.toJson()},
        }),
        _removedKey: jsonEncode({for (final e in readRemoved().entries) e.key: e.value.toIso8601String()}),
      };

  /// Ganti seluruh isi database dengan kunci prefs lama (setelah memulihkan
  /// cadangan). Tidak berbuat apa-apa bila memakai prefs.
  Future<void> reloadFromPrefs() async {
    final db = _db;
    if (db == null) return;
    await db.transaction(() async {
      await db.delete(db.favoriteRows).go();
      await db.delete(db.historyRows).go();
      await db.delete(db.progressRows).go();
      await db.delete(db.removedRows).go();
    });
    await _importFromPrefs();
    await _load();
  }

  // ------------------------------------------------------------- internal

  Future<void> _importFromPrefs() async {
    final db = _db!;
    final favorites = _readList(_favoritesKey, SourceFavorite.tryParse);
    final history = _readList(_historyKey, SourceHistoryEntry.tryParse);
    final progress = _readProgressPrefs();
    final removed = _readRemovedPrefs();
    await db.batch((b) {
      for (final e in favorites) {
        b.insert(
          db.favoriteRows,
          FavoriteRowsCompanion.insert(key: e.item.key, json: jsonEncode(e.toJson()), addedAt: e.addedAt),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final e in history) {
        b.insert(
          db.historyRows,
          HistoryRowsCompanion.insert(key: e.item.key, json: jsonEncode(e.toJson()), readAt: e.readAt),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final s in progress.entries) {
        for (final c in s.value.entries) {
          b.insert(
            db.progressRows,
            ProgressRowsCompanion.insert(
              seriesKey: s.key,
              chapterUrl: c.key,
              json: jsonEncode(c.value.toJson()),
              updatedAt: c.value.updatedAt,
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      }
      for (final e in removed.entries) {
        b.insert(
          db.removedRows,
          RemovedRowsCompanion.insert(key: e.key, removedAt: e.value),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<void> _load() async {
    final db = _db!;
    T? parse<T>(String json, T? Function(JsonMap) f) {
      try {
        return f(asMap(jsonDecode(json)));
      } catch (_) {
        return null;
      }
    }

    // Urutan sama dengan yang disimpan sebelumnya: favorit & riwayat terbaru di atas.
    final fav = await (db.select(db.favoriteRows)..orderBy([(t) => OrderingTerm.desc(t.addedAt)])).get();
    _favorites = List.unmodifiable(fav.map((r) => parse(r.json, SourceFavorite.tryParse)).whereType<SourceFavorite>());
    final his = await (db.select(db.historyRows)..orderBy([(t) => OrderingTerm.desc(t.readAt)])).get();
    _history =
        List.unmodifiable(his.map((r) => parse(r.json, SourceHistoryEntry.tryParse)).whereType<SourceHistoryEntry>());
    final prog = <String, Map<String, SourceChapterProgress>>{};
    for (final r in await db.select(db.progressRows).get()) {
      final p = parse(r.json, SourceChapterProgress.tryParse);
      if (p != null) (prog[r.seriesKey] ??= {})[r.chapterUrl] = p;
    }
    _progress = prog;
    _removed = {for (final r in await db.select(db.removedRows).get()) r.key: r.removedAt};
  }

  static bool _same(JsonMap a, JsonMap b) => jsonEncode(a) == jsonEncode(b);

  Map<String, Map<String, SourceChapterProgress>> _readProgressPrefs() {
    final raw = _prefs.getString(_progressKey);
    if (raw == null) return {};
    try {
      return {
        for (final series in asMap(jsonDecode(raw)).entries)
          series.key: {
            for (final ch in asMap(series.value).entries)
              if (SourceChapterProgress.tryParse(asMap(ch.value)) case final p?) ch.key: p,
          },
      };
    } catch (_) {
      return {};
    }
  }

  Map<String, DateTime> _readRemovedPrefs() {
    final raw = _prefs.getString(_removedKey);
    if (raw == null) return {};
    try {
      return {
        for (final e in asMap(jsonDecode(raw)).entries)
          if (asDate(e.value) case final d?) e.key: d,
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _write(String key, Iterable<JsonMap> items) => _prefs.setString(key, jsonEncode(items.toList()));

  List<T> _readList<T>(String key, T? Function(JsonMap) parse) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return asList(jsonDecode(raw)).map((e) => parse(asMap(e))).whereType<T>().toList();
    } catch (_) {
      return [];
    }
  }
}
