import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';
import 'source_library_providers.dart';

String _seriesKey(SourceItemKey k) => '${k.sourceId}|${k.url}';

/// Bab yang ditandai (bookmark) per seri, komik maupun novel. Kunci seri sama
/// dengan pustaka sumber (`<sourceId>|<url seri>`), isi = URL/path bab.
final chapterBookmarksProvider =
    NotifierProvider<ChapterBookmarksNotifier, Map<String, Set<String>>>(ChapterBookmarksNotifier.new);

class ChapterBookmarksNotifier extends Notifier<Map<String, Set<String>>> {
  static const key = 'library.bookmarks.v1';

  @override
  Map<String, Set<String>> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(key);
    if (raw == null) return const {};
    try {
      return {
        for (final e in (jsonDecode(raw) as Map).entries) '${e.key}': {for (final u in e.value as List) '$u'},
      };
    } on Object {
      return const {};
    }
  }

  Future<void> _save(Map<String, Set<String>> next) async {
    next.removeWhere((_, v) => v.isEmpty);
    state = next;
    await ref
        .read(sharedPreferencesProvider)
        .setString(key, jsonEncode({for (final e in next.entries) e.key: e.value.toList()}));
  }

  bool isBookmarked(SourceItemKey series, String chapter) => state[_seriesKey(series)]?.contains(chapter) ?? false;

  Future<void> setMany(SourceItemKey series, Iterable<String> chapters, {required bool bookmarked}) {
    final k = _seriesKey(series);
    final set = {...?state[k]};
    bookmarked ? set.addAll(chapters) : set.removeAll(chapters);
    return _save({...state, k: set});
  }

  /// Balik status bookmark; hasil = status baru.
  Future<bool> toggle(SourceItemKey series, String chapter) async {
    final now = !isBookmarked(series, chapter);
    await setMany(series, [chapter], bookmarked: now);
    return now;
  }
}

final seriesBookmarksProvider = Provider.autoDispose.family<Set<String>, SourceItemKey>(
  (ref, k) => ref.watch(chapterBookmarksProvider)[_seriesKey(k)] ?? const {},
);

/// Catatan pribadi per seri (teks bebas).
final seriesNotesProvider = NotifierProvider<SeriesNotesNotifier, Map<String, String>>(SeriesNotesNotifier.new);

class SeriesNotesNotifier extends Notifier<Map<String, String>> {
  static const key = 'library.notes.v1';

  @override
  Map<String, String> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(key);
    if (raw == null) return const {};
    try {
      return {for (final e in (jsonDecode(raw) as Map).entries) '${e.key}': '${e.value}'};
    } on Object {
      return const {};
    }
  }

  /// Teks kosong menghapus catatan.
  Future<void> set(SourceItemKey series, String text) async {
    final next = {...state};
    final trimmed = text.trim();
    trimmed.isEmpty ? next.remove(_seriesKey(series)) : next[_seriesKey(series)] = trimmed;
    state = next;
    await ref.read(sharedPreferencesProvider).setString(key, jsonEncode(next));
  }
}

final seriesNoteProvider = Provider.autoDispose.family<String?, SourceItemKey>(
  (ref, k) => ref.watch(seriesNotesProvider)[_seriesKey(k)],
);
