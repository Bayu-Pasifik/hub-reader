import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';

/// Kunci sorotan: `<pluginId>|<path bab>`.
String highlightKey(String pluginId, String chapterPath) => '$pluginId|$chapterPath';

/// Teks yang disorot pembaca novel, per bab.
final novelHighlightsProvider =
    NotifierProvider<NovelHighlightsNotifier, Map<String, List<String>>>(NovelHighlightsNotifier.new);

class NovelHighlightsNotifier extends Notifier<Map<String, List<String>>> {
  static const _key = 'novel.highlights.v1';

  @override
  Map<String, List<String>> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const {};
    try {
      final map = jsonDecode(raw) as Map;
      return {
        for (final e in map.entries) '${e.key}': [for (final t in e.value as List) '$t'],
      };
    } on Object {
      return const {};
    }
  }

  Future<void> add(String key, String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    final list = state[key] ?? const [];
    if (list.contains(t)) return;
    await _save({
      ...state,
      key: [...list, t],
    });
  }

  /// Hapus sorotan yang sama dengan, atau terkandung dalam, [text].
  Future<void> remove(String key, String text) async {
    final list = state[key];
    if (list == null) return;
    final t = text.trim();
    final next = list.where((h) => !(h == t || t.contains(h))).toList();
    if (next.length == list.length) return;
    final map = {...state};
    if (next.isEmpty) {
      map.remove(key);
    } else {
      map[key] = next;
    }
    await _save(map);
  }

  Future<void> _save(Map<String, List<String>> next) async {
    state = next;
    await ref.read(sharedPreferencesProvider).setString(_key, jsonEncode(next));
  }
}

/// Teks sorotan di [highlights] yang cocok dengan pilihan [selected] (sama, atau
/// terkandung di dalamnya); null bila belum disorot.
String? matchingHighlight(List<String> highlights, String selected) {
  final t = selected.trim();
  if (t.isEmpty) return null;
  for (final h in highlights) {
    if (h == t || t.contains(h)) return h;
  }
  return null;
}

/// Catatan pribadi pada sorotan: `{kunci bab: {teks sorotan: catatan}}`.
/// Disimpan terpisah dari sorotan supaya data sorotan lama tetap kompatibel.
final novelHighlightNotesProvider =
    NotifierProvider<NovelHighlightNotesNotifier, Map<String, Map<String, String>>>(NovelHighlightNotesNotifier.new);

class NovelHighlightNotesNotifier extends Notifier<Map<String, Map<String, String>>> {
  static const _key = 'novel.highlight_notes.v1';

  @override
  Map<String, Map<String, String>> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const {};
    try {
      final map = jsonDecode(raw) as Map;
      return {
        for (final e in map.entries)
          '${e.key}': {for (final n in (e.value as Map).entries) '${n.key}': '${n.value}'},
      };
    } on Object {
      return const {};
    }
  }

  String? noteFor(String key, String highlight) => state[key]?[highlight];

  /// Simpan catatan; catatan kosong menghapusnya.
  Future<void> set(String key, String highlight, String note) async {
    final n = note.trim();
    final map = {...state};
    final notes = {...?map[key]};
    if (n.isEmpty) {
      notes.remove(highlight);
    } else {
      notes[highlight] = n;
    }
    if (notes.isEmpty) {
      map.remove(key);
    } else {
      map[key] = notes;
    }
    await _save(map);
  }

  /// Hapus catatan sorotan yang sama dengan, atau terkandung dalam, [text]
  /// (dipanggil saat sorotan dihapus).
  Future<void> removeFor(String key, String text) async {
    final notes = state[key];
    if (notes == null) return;
    final t = text.trim();
    final keep = {
      for (final e in notes.entries)
        if (!(e.key == t || t.contains(e.key))) e.key: e.value,
    };
    if (keep.length == notes.length) return;
    final map = {...state};
    if (keep.isEmpty) {
      map.remove(key);
    } else {
      map[key] = keep;
    }
    await _save(map);
  }

  Future<void> _save(Map<String, Map<String, String>> next) async {
    state = next;
    await ref.read(sharedPreferencesProvider).setString(_key, jsonEncode(next));
  }
}
