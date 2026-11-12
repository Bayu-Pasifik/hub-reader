import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/json.dart';
import '../models/source_library.dart';

/// Favorit & riwayat seri dari sumber on-device (JSON di SharedPreferences).
class SourceLibraryStore {
  SourceLibraryStore(this._prefs);

  final SharedPreferences _prefs;

  static const _favoritesKey = 'source_library.favorites.v1';
  static const _historyKey = 'source_library.history.v1';

  List<SourceFavorite> readFavorites() => _readList(_favoritesKey, SourceFavorite.tryParse);

  Future<void> writeFavorites(List<SourceFavorite> entries) => _write(_favoritesKey, entries.map((e) => e.toJson()));

  List<SourceHistoryEntry> readHistory() => _readList(_historyKey, SourceHistoryEntry.tryParse);

  Future<void> writeHistory(List<SourceHistoryEntry> entries) => _write(_historyKey, entries.map((e) => e.toJson()));

  Future<void> _write(String key, Iterable<JsonMap> items) =>
      _prefs.setString(key, jsonEncode(items.toList()));

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
