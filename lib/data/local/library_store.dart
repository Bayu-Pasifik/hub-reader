import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/json.dart';
import '../models/library_item.dart';

/// Penyimpanan lokal favorit & riwayat (JSON di SharedPreferences).
///
/// Cukup untuk ratusan entri. Bila data tumbuh besar (ribuan), ganti
/// implementasi kelas ini dengan sqflite/drift tanpa mengubah provider/UI.
class LibraryStore {
  LibraryStore(this._prefs);

  final SharedPreferences _prefs;

  static const _favoritesKey = 'library.favorites.v1';
  static const _historyKey = 'library.history.v1';

  List<FavoriteEntry> readFavorites() =>
      _readList(_favoritesKey, FavoriteEntry.tryParse);

  Future<void> writeFavorites(List<FavoriteEntry> entries) =>
      _prefs.setString(_favoritesKey, jsonEncode(entries.map((e) => e.toJson()).toList()));

  List<HistoryEntry> readHistory() => _readList(_historyKey, HistoryEntry.tryParse);

  Future<void> writeHistory(List<HistoryEntry> entries) =>
      _prefs.setString(_historyKey, jsonEncode(entries.map((e) => e.toJson()).toList()));

  List<T> _readList<T>(String key, T? Function(JsonMap) parse) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return asList(jsonDecode(raw))
          .map((e) => parse(asMap(e)))
          .whereType<T>()
          .toList();
    } catch (_) {
      return [];
    }
  }
}
