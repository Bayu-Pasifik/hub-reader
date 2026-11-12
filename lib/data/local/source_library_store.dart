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

  static const _progressKey = 'source_library.progress.v1';

  /// `{kunci seri: {URL bab: progres}}`
  Map<String, Map<String, SourceChapterProgress>> readProgress() {
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

  Future<void> writeProgress(Map<String, Map<String, SourceChapterProgress>> progress) =>
      _prefs.setString(
        _progressKey,
        jsonEncode({
          for (final s in progress.entries)
            s.key: {for (final c in s.value.entries) c.key: c.value.toJson()},
        }),
      );

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
