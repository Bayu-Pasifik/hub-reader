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
