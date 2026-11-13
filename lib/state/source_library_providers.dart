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

// ------------------------------------------------------------ posisi baca

/// Progres per bab: `{kunci seri: {URL bab: progres}}`.
final sourceProgressProvider = NotifierProvider<SourceProgressNotifier,
    Map<String, Map<String, SourceChapterProgress>>>(SourceProgressNotifier.new);

class SourceProgressNotifier extends Notifier<Map<String, Map<String, SourceChapterProgress>>> {
  SourceLibraryStore get _store => ref.read(sourceLibraryStoreProvider);

  @override
  Map<String, Map<String, SourceChapterProgress>> build() =>
      ref.watch(sourceLibraryStoreProvider).readProgress();

  /// Simpan halaman yang sedang terlihat. Bab yang sudah selesai tetap
  /// berstatus selesai walau dibaca ulang.
  Future<void> update(SourceItemKey series, String chapterUrl, {required int page, required int total}) async {
    final key = _key(series);
    final old = state[key]?[chapterUrl];
    final done = (old?.done ?? false) || (total > 0 && page >= total - 1);
    if (old != null && old.page == page && old.total == total && old.done == done) return;
    _set(key, chapterUrl, SourceChapterProgress(
      page: page,
      total: total,
      done: done,
      updatedAt: DateTime.now(),
    ));
    await _store.writeProgress(state);
  }

  /// Tandai sudah/belum dibaca secara manual (dari daftar bab).
  Future<void> setDone(SourceItemKey series, String chapterUrl, {required bool done}) async {
    final key = _key(series);
    final old = state[key]?[chapterUrl];
    _set(key, chapterUrl, SourceChapterProgress(
      page: done ? (old?.page ?? 0) : 0,
      total: old?.total ?? 0,
      done: done,
      updatedAt: DateTime.now(),
    ));
    await _store.writeProgress(state);
  }

  /// Tandai banyak bab sekaligus (pilihan di daftar bab).
  Future<void> setDoneMany(SourceItemKey series, Iterable<String> chapterUrls, {required bool done}) async {
    final key = _key(series);
    final now = DateTime.now();
    final current = {...?state[key]};
    for (final url in chapterUrls) {
      final old = current[url];
      current[url] = SourceChapterProgress(
        page: done ? (old?.page ?? 0) : 0,
        total: old?.total ?? 0,
        done: done,
        updatedAt: now,
      );
    }
    state = {...state, key: current};
    await _store.writeProgress(state);
  }

  void _set(String seriesKey, String chapterUrl, SourceChapterProgress progress) {
    state = {
      ...state,
      seriesKey: {...?state[seriesKey], chapterUrl: progress},
    };
  }
}

/// Progres semua bab satu seri.
final sourceSeriesProgressProvider =
    Provider.autoDispose.family<Map<String, SourceChapterProgress>, SourceItemKey>(
  (ref, k) => ref.watch(sourceProgressProvider.select((all) => all[_key(k)] ?? const {})),
);
