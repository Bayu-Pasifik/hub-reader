import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/source_library_store.dart';
import '../data/models/source_library.dart';
import '../sources/models.dart';
import 'app_settings_provider.dart';
import 'core_providers.dart';
import 'download_providers.dart' show downloadIndexProvider;
import 'novel_providers.dart' show isNovelSourceId;
import 'reading_stats_provider.dart';

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
    state = [...state]..[index] = old.copyWith(item: item);
    await _store.writeFavorites(state);
  }

  /// Atur kategori satu favorit.
  Future<void> setCategories(String key, List<String> categories) async {
    state = [for (final f in state) f.item.key == key ? f.copyWith(categories: categories) : f];
    await _store.writeFavorites(state);
  }

  /// Ganti nama / hapus ([to] null) kategori di semua favorit.
  Future<void> renameCategory(String from, String? to) async {
    state = [
      for (final f in state)
        f.categories.contains(from)
            ? f.copyWith(categories: [
                for (final c in f.categories)
                  if (c != from) c else if (to != null && !f.categories.contains(to)) to,
              ])
            : f,
    ];
    await _store.writeFavorites(state);
  }
}

// --------------------------------------------------------------- kategori

/// Daftar kategori (urutan tab di Favorit).
final libraryCategoriesProvider =
    NotifierProvider<LibraryCategoriesNotifier, List<String>>(LibraryCategoriesNotifier.new);

class LibraryCategoriesNotifier extends Notifier<List<String>> {
  static const _key = 'library.categories.v1';

  @override
  List<String> build() => ref.watch(sharedPreferencesProvider).getStringList(_key) ?? const [];

  Future<void> _save() => ref.read(sharedPreferencesProvider).setStringList(_key, state);

  /// false bila nama kosong atau sudah ada.
  Future<bool> add(String name) async {
    final n = name.trim();
    if (n.isEmpty || state.contains(n)) return false;
    state = [...state, n];
    await _save();
    return true;
  }

  Future<bool> rename(String from, String to) async {
    final n = to.trim();
    if (n.isEmpty || (n != from && state.contains(n))) return false;
    state = [for (final c in state) c == from ? n : c];
    await _save();
    await ref.read(sourceFavoritesProvider.notifier).renameCategory(from, n);
    return true;
  }

  Future<void> remove(String name) async {
    state = state.where((c) => c != name).toList();
    await _save();
    await ref.read(sourceFavoritesProvider.notifier).renameCategory(name, null);
  }

  Future<void> move(String name, int delta) async {
    final i = state.indexOf(name);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= state.length) return;
    final list = [...state];
    list[i] = list[j];
    list[j] = name;
    state = list;
    await _save();
  }
}

// ------------------------------------------------------ tampilan favorit

enum LibrarySort {
  added('Terakhir ditambahkan'),
  title('Judul A–Z'),
  lastRead('Terakhir dibaca'),
  unread('Bab baru belum dibaca');

  const LibrarySort(this.label);

  final String label;
}

enum LibraryKind {
  all('Semua'),
  comic('Komik'),
  novel('Novel');

  const LibraryKind(this.label);

  final String label;
}

typedef LibraryView = ({LibrarySort sort, LibraryKind kind, bool unreadOnly});

final libraryViewProvider = NotifierProvider<LibraryViewNotifier, LibraryView>(LibraryViewNotifier.new);

class LibraryViewNotifier extends Notifier<LibraryView> {
  static const _key = 'library.view.v1';

  @override
  LibraryView build() {
    final raw = ref.watch(sharedPreferencesProvider).getStringList(_key) ?? const [];
    T pick<T extends Enum>(List<T> values, int i, T fallback) =>
        raw.length > i ? values.where((v) => v.name == raw[i]).firstOrNull ?? fallback : fallback;
    return (
      sort: pick(LibrarySort.values, 0, LibrarySort.added),
      kind: pick(LibraryKind.values, 1, LibraryKind.all),
      unreadOnly: raw.length > 2 && raw[2] == '1',
    );
  }

  Future<void> set({LibrarySort? sort, LibraryKind? kind, bool? unreadOnly}) async {
    state = (sort: sort ?? state.sort, kind: kind ?? state.kind, unreadOnly: unreadOnly ?? state.unreadOnly);
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_key, [state.sort.name, state.kind.name, state.unreadOnly ? '1' : '0']);
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
    // Mode samaran: riwayat tidak dicatat.
    if (ref.read(appSettingsProvider).incognito) return;
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
final sourceProgressProvider =
    NotifierProvider<SourceProgressNotifier, Map<String, Map<String, SourceChapterProgress>>>(
        SourceProgressNotifier.new);

class SourceProgressNotifier extends Notifier<Map<String, Map<String, SourceChapterProgress>>> {
  SourceLibraryStore get _store => ref.read(sourceLibraryStoreProvider);

  @override
  Map<String, Map<String, SourceChapterProgress>> build() => ref.watch(sourceLibraryStoreProvider).readProgress();

  /// Simpan halaman yang sedang terlihat. Bab yang sudah selesai tetap
  /// berstatus selesai walau dibaca ulang.
  Future<void> update(SourceItemKey series, String chapterUrl, {required int page, required int total}) async {
    // Mode samaran: posisi baca tidak dicatat (tanda manual tetap bisa).
    if (ref.read(appSettingsProvider).incognito) return;
    final key = _key(series);
    final old = state[key]?[chapterUrl];
    final done = (old?.done ?? false) || (total > 0 && page >= total - 1);
    if (old != null && old.page == page && old.total == total && old.done == done) return;
    if (done && !(old?.done ?? false)) {
      ref.read(readingStatsProvider.notifier).chapterFinished(novel: isNovelSourceId(series.sourceId));
    }
    _set(
        key,
        chapterUrl,
        SourceChapterProgress(
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
    _set(
        key,
        chapterUrl,
        SourceChapterProgress(
          page: done ? (old?.page ?? 0) : 0,
          total: old?.total ?? 0,
          done: done,
          updatedAt: DateTime.now(),
        ));
    await _store.writeProgress(state);
    if (done) await ref.read(downloadIndexProvider.notifier).purgeRead();
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
    if (done) await ref.read(downloadIndexProvider.notifier).purgeRead();
  }

  void _set(String seriesKey, String chapterUrl, SourceChapterProgress progress) {
    state = {
      ...state,
      seriesKey: {...?state[seriesKey], chapterUrl: progress},
    };
  }
}

/// Progres semua bab satu seri.
final sourceSeriesProgressProvider = Provider.autoDispose.family<Map<String, SourceChapterProgress>, SourceItemKey>(
  (ref, k) => ref.watch(sourceProgressProvider.select((all) => all[_key(k)] ?? const {})),
);
