import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Grup scanlation sebuah bab: field `scanlator` dari sumber, atau awalan
/// `[Grup]` pada nama bab (kebiasaan arsip/folder lokal). Null bila tidak ada.
String? chapterGroup(SourceChapter chapter) {
  final explicit = chapter.scanlator?.trim();
  if (explicit != null && explicit.isNotEmpty) return explicit;
  final match = RegExp(r'^\s*\[([^\]]{1,40})\]').firstMatch(chapter.name);
  final fromName = match?.group(1)?.trim();
  return (fromName == null || fromName.isEmpty) ? null : fromName;
}

/// Jumlah bab per grup, terbanyak dulu. Bab tanpa grup tidak dihitung.
Map<String, int> groupCounts(Iterable<SourceChapter> chapters) {
  final counts = <String, int>{};
  for (final c in chapters) {
    final g = chapterGroup(c);
    if (g != null) counts[g] = (counts[g] ?? 0) + 1;
  }
  final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return {for (final e in sorted) e.key: e.value};
}

/// Bab ikut tampil bila grupnya tidak disembunyikan. Bab tanpa grup selalu tampil.
bool chapterVisible(SourceChapter chapter, Set<String> hidden) {
  if (hidden.isEmpty) return true;
  final g = chapterGroup(chapter);
  return g == null || !hidden.contains(g);
}

/// Pilihan grup yang disembunyikan, disimpan per seri.
abstract final class ScanlatorFilter {
  static String _key(String seriesKey) => 'series.hidden_scanlators.v1.$seriesKey';

  static Set<String> read(SharedPreferences prefs, String seriesKey) {
    try {
      final raw = prefs.getString(_key(seriesKey));
      if (raw == null) return {};
      return {for (final e in jsonDecode(raw) as List) e.toString()};
    } catch (_) {
      return {};
    }
  }

  static Future<void> write(SharedPreferences prefs, String seriesKey, Set<String> hidden) => hidden.isEmpty
      ? prefs.remove(_key(seriesKey))
      : prefs.setString(_key(seriesKey), jsonEncode(hidden.toList()));
}
