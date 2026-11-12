import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/library_store.dart';
import '../data/models/chapter.dart';
import '../data/models/library_item.dart';
import 'catalog_providers.dart';
import 'core_providers.dart';

/// Favorit lokal (terbaru di atas). Tidak bergantung pada API.
final favoritesProvider =
    NotifierProvider<FavoritesNotifier, List<FavoriteEntry>>(FavoritesNotifier.new);

class FavoritesNotifier extends Notifier<List<FavoriteEntry>> {
  LibraryStore get _store => ref.read(libraryStoreProvider);

  @override
  List<FavoriteEntry> build() => ref.watch(libraryStoreProvider).readFavorites();

  Future<void> toggle(LibraryItem item) async {
    final exists = state.any((e) => e.item.key == item.key);
    state = exists
        ? state.where((e) => e.item.key != item.key).toList()
        : [FavoriteEntry(item: item, addedAt: DateTime.now()), ...state];
    await _store.writeFavorites(state);
  }

  Future<void> remove(String key) async {
    state = state.where((e) => e.item.key != key).toList();
    await _store.writeFavorites(state);
  }

  /// Untuk tombol "Urungkan" setelah menghapus.
  Future<void> restore(FavoriteEntry entry) async {
    if (state.any((e) => e.item.key == entry.item.key)) return;
    state = [...state, entry]..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    await _store.writeFavorites(state);
  }

  /// Perbarui judul/sampul tersimpan dengan data terbaru dari server.
  Future<void> refreshItem(LibraryItem item) async {
    final index = state.indexWhere((e) => e.item.key == item.key);
    if (index < 0) return;
    final old = state[index];
    if (old.item.title == item.title &&
        old.item.coverUrl == item.coverUrl &&
        old.item.status == item.status) {
      return;
    }
    final next = [...state];
    next[index] = FavoriteEntry(item: item, addedAt: old.addedAt);
    state = next;
    await _store.writeFavorites(state);
  }
}

final isFavoriteProvider = Provider.autoDispose.family<bool, SeriesRef>(
  (ref, r) => ref.watch(favoritesProvider).any((e) => e.item.type == r.type && e.item.id == r.id),
);

/// Riwayat baca lokal: satu entri per seri, terbaru di atas.
final historyProvider =
    NotifierProvider<HistoryNotifier, List<HistoryEntry>>(HistoryNotifier.new);

class HistoryNotifier extends Notifier<List<HistoryEntry>> {
  static const _maxEntries = 300;

  LibraryStore get _store => ref.read(libraryStoreProvider);

  @override
  List<HistoryEntry> build() => ref.watch(libraryStoreProvider).readHistory();

  Future<void> record(LibraryItem item, Chapter chapter) async {
    final entry = HistoryEntry.create(item, chapter);
    state = [entry, ...state.where((e) => e.item.key != item.key)].take(_maxEntries).toList();
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

final lastReadProvider = Provider.autoDispose.family<HistoryEntry?, SeriesRef>((ref, r) {
  for (final entry in ref.watch(historyProvider)) {
    if (entry.item.type == r.type && entry.item.id == r.id) return entry;
  }
  return null;
});
