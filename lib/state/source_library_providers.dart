import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/source_library_store.dart';
import '../data/models/source_library.dart';
import '../sources/models.dart';
import 'core_providers.dart';

final sourceLibraryStoreProvider = Provider<SourceLibraryStore>(
  (ref) => SourceLibraryStore(ref.watch(sharedPreferencesProvider)),
);

// ----------------------------------------------------------------- favorit

/// Favorit seri dari sumber on-device (terbaru di atas).
final sourceFavoritesProvider =
    NotifierProvider<SourceFavoritesNotifier, List<SourceFavorite>>(SourceFavoritesNotifier.new);

class SourceFavoritesNotifier extends Notifier<List<SourceFavorite>> {
  SourceLibraryStore get _store => ref.read(sourceLibraryStoreProvider);

  @override
  List<SourceFavorite> build() => ref.watch(sourceLibraryStoreProvider).readFavorites();

  Future<void> toggle(SourceLibraryItem item) async {
    final exists = state.any((e) => e.item.key == item.key);
    state = exists
        ? state.where((e) => e.item.key != item.key).toList()
        : [SourceFavorite(item: item, addedAt: DateTime.now()), ...state];
    await _store.writeFavorites(state);
  }

  Future<void> remove(String key) async {
    state = state.where((e) => e.item.key != key).toList();
    await _store.writeFavorites(state);
  }

  /// Untuk tombol "Urungkan".
  Future<void> restore(SourceFavorite entry) async {
    if (state.any((e) => e.item.key == entry.item.key)) return;
    state = [...state, entry]..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    await _store.writeFavorites(state);
  }

  /// Perbarui judul/sampul tersimpan dengan data terbaru dari situs.
  Future<void> refreshItem(SourceLibraryItem item) async {
    final index = state.indexWhere((e) => e.item.key == item.key);
    if (index < 0) return;
    final old = state[index];
    if (old.item.title == item.title && old.item.thumbnailUrl == item.thumbnailUrl) return;
    state = [...state]..[index] = SourceFavorite(item: item, addedAt: old.addedAt);
    await _store.writeFavorites(state);
  }
}

typedef SourceItemKey = ({String sourceId, String url});

String _key(SourceItemKey k) => '${k.sourceId}|${k.url}';

final isSourceFavoriteProvider = Provider.autoDispose.family<bool, SourceItemKey>(
  (ref, k) => ref.watch(sourceFavoritesProvider).any((e) => e.item.key == _key(k)),
);

// ----------------------------------------------------------------- riwayat

/// Riwayat baca: satu entri per seri, terbaru di atas.
final sourceHistoryProvider =
    NotifierProvider<SourceHistoryNotifier, List<SourceHistoryEntry>>(SourceHistoryNotifier.new);

class SourceHistoryNotifier extends Notifier<List<SourceHistoryEntry>> {
  static const maxEntries = 300;

  SourceLibraryStore get _store => ref.read(sourceLibraryStoreProvider);

  @override
  List<SourceHistoryEntry> build() => ref.watch(sourceLibraryStoreProvider).readHistory();

  Future<void> record(SourceLibraryItem item, SourceChapter chapter) async {
    final first = state.firstOrNull;
    if (first != null && first.item.key == item.key && first.chapterUrl == chapter.url) return;
    final entry = SourceHistoryEntry(
      item: item,
      chapterUrl: chapter.url,
      chapterName: chapter.name,
      readAt: DateTime.now(),
    );
    state = [entry, ...state.where((e) => e.item.key != item.key)].take(maxEntries).toList();
    await _store.writeHistory(state);
  }

  Future<void> remove(String key) async {
    state = state.where((e) => e.item.key != key).toList();
    await _store.writeHistory(state);
  }

  Future<void> clear() async {
    state = [];
    await _store.writeHistory(state);
  }
}

final sourceLastReadProvider = Provider.autoDispose.family<SourceHistoryEntry?, SourceItemKey>(
  (ref, k) {
    final key = _key(k);
    for (final e in ref.watch(sourceHistoryProvider)) {
      if (e.item.key == key) return e;
    }
    return null;
  },
);
