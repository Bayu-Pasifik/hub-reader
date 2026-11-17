import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/source_library_store.dart';
import '../data/models/source_library.dart';
import '../sources/models.dart';
import 'app_settings_provider.dart';
import 'core_providers.dart';
import 'download_providers.dart' show downloadIndexProvider;
import 'novel_providers.dart' show isNovelSourceId;
import 'reading_stats_provider.dart';
import '../core/i18n/strings.dart';

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
    if (state.any((e) => e.item.key == item.key)) return remove(item.key);
    final now = DateTime.now();
    state = [SourceFavorite(item: item, addedAt: now), ...state];
    await _store.writeFavorites(state);
    await _setRemoved(item.key, null);
  }

  Future<void> remove(String key) async {
    state = state.where((e) => e.item.key != key).toList();
    await _store.writeFavorites(state);
    await _setRemoved(key, DateTime.now());
  }

  /// Untuk tombol "Urungkan".
  Future<void> restore(SourceFavorite entry) async {
    if (state.any((e) => e.item.key == entry.item.key)) return;
    final revived = entry.copyWith(updatedAt: DateTime.now());
    state = [...state, revived]..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    await _store.writeFavorites(state);
    await _setRemoved(entry.item.key, null);
  }

  /// Catat/hapus tombstone agar penghapusan ikut tersinkron antar perangkat.
  Future<void> _setRemoved(String key, DateTime? at) async {
    final removed = _store.readRemoved();
    if (at == null) {
      if (removed.remove(key) == null) return;
    } else {
      removed[key] = at;
    }
    await _store.writeRemoved(removed);
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
    await ref.read(libraryCategoryViewsProvider.notifier).rename(from, n);
    return true;
  }

  Future<void> remove(String name) async {
    state = state.where((c) => c != name).toList();
    await _save();
    await ref.read(sourceFavoritesProvider.notifier).renameCategory(name, null);
    await ref.read(libraryCategoryViewsProvider.notifier).rename(name, null);
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
  unread('Bab baru belum dibaca'),
  updated('Pembaruan terbaru'),
  source('Sumber A–Z');

  const LibrarySort(this._label);

  final String _label;

  String get label => tr(_label);
}

enum LibraryKind {
  all('Semua'),
  comic('Komik'),
  novel('Novel');

  const LibraryKind(this._label);

  final String _label;

  String get label => tr(_label);
}

typedef LibraryView = ({
  LibrarySort sort,
  bool reversed,
  LibraryKind kind,
  bool unreadOnly,
  bool downloadedOnly,
  bool startedOnly,
  bool unstartedOnly,
  bool trackedOnly,
  String trackStatus,
});

const defaultLibraryView = (
  sort: LibrarySort.added,
  reversed: false,
  kind: LibraryKind.all,
  unreadOnly: false,
  downloadedOnly: false,
  startedOnly: false,
  unstartedOnly: false,
  trackedOnly: false,
  trackStatus: '',
);

/// Apakah tampilan berbeda dari bawaan (untuk lencana tombol filter).
bool isLibraryViewFiltered(LibraryView v) => v != defaultLibraryView;

List<String> encodeLibraryView(LibraryView v) => [
      v.sort.name,
      v.kind.name,
      v.unreadOnly ? '1' : '0',
      v.downloadedOnly ? '1' : '0',
      v.reversed ? '1' : '0',
      v.startedOnly ? '1' : '0',
      v.unstartedOnly ? '1' : '0',
      v.trackedOnly ? '1' : '0',
      v.trackStatus,
    ];

LibraryView decodeLibraryView(List<Object?> raw) {
  T pick<T extends Enum>(List<T> values, int i, T fallback) =>
      raw.length > i ? values.where((v) => v.name == raw[i]).firstOrNull ?? fallback : fallback;
  bool flag(int i) => raw.length > i && raw[i] == '1';
  return (
    sort: pick(LibrarySort.values, 0, LibrarySort.added),
    kind: pick(LibraryKind.values, 1, LibraryKind.all),
    unreadOnly: flag(2),
    downloadedOnly: flag(3),
    reversed: flag(4),
    startedOnly: flag(5),
    unstartedOnly: flag(6),
    trackedOnly: flag(7),
    trackStatus: raw.length > 8 && raw[8] is String ? raw[8] as String : '',
  );
}

final libraryViewProvider = NotifierProvider<LibraryViewNotifier, LibraryView>(LibraryViewNotifier.new);

class LibraryViewNotifier extends Notifier<LibraryView> {
  static const _key = 'library.view.v1';

  @override
  LibraryView build() => decodeLibraryView(ref.watch(sharedPreferencesProvider).getStringList(_key) ?? const []);

  Future<void> set({
    LibrarySort? sort,
    bool? reversed,
    LibraryKind? kind,
    bool? unreadOnly,
    bool? downloadedOnly,
    bool? startedOnly,
    bool? unstartedOnly,
    bool? trackedOnly,
    String? trackStatus,
  }) async {
    state = (
      sort: sort ?? state.sort,
      reversed: reversed ?? state.reversed,
      kind: kind ?? state.kind,
      unreadOnly: unreadOnly ?? state.unreadOnly,
      downloadedOnly: downloadedOnly ?? state.downloadedOnly,
      startedOnly: startedOnly ?? state.startedOnly,
      unstartedOnly: unstartedOnly ?? state.unstartedOnly,
      trackedOnly: trackedOnly ?? state.trackedOnly,
      trackStatus: trackStatus ?? state.trackStatus,
    );
    await ref.read(sharedPreferencesProvider).setStringList(_key, encodeLibraryView(state));
  }
}

/// Urutan & filter khusus satu kategori; kategori tanpa entri ikut tampilan umum.
final libraryCategoryViewsProvider =
    NotifierProvider<LibraryCategoryViewsNotifier, Map<String, LibraryView>>(LibraryCategoryViewsNotifier.new);

class LibraryCategoryViewsNotifier extends Notifier<Map<String, LibraryView>> {
  static const _key = 'library.view.categories.v1';

  @override
  Map<String, LibraryView> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const {};
    try {
      final map = jsonDecode(raw) as Map;
      return {for (final e in map.entries) '${e.key}': decodeLibraryView((e.value as List).cast<Object?>())};
    } on Object {
      return const {};
    }
  }

  /// Simpan tampilan kategori; null menghapusnya (kembali ke tampilan umum).
  Future<void> set(String category, LibraryView? view) async {
    final next = {...state};
    view == null ? next.remove(category) : next[category] = view;
    state = next;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_key, jsonEncode({for (final e in next.entries) e.key: encodeLibraryView(e.value)}));
  }

  /// Kategori dihapus / diganti nama: pindahkan atau buang pengaturannya.
  Future<void> rename(String from, String? to) async {
    final v = state[from];
    if (v == null) return;
    await set(from, null);
    if (to != null) await set(to, v);
  }
}

/// Tampilan efektif untuk satu tab: milik kategori bila ada, kalau tidak yang umum.
LibraryView effectiveLibraryView(LibraryView global, Map<String, LibraryView> perCategory, String? category) =>
    (category == null ? null : perCategory[category]) ?? global;

/// Cara menampilkan favorit.
enum LibraryDisplay {
  grid('Grid'),
  compact('Grid ringkas'),
  coverOnly('Sampul saja'),
  list('Daftar');

  const LibraryDisplay(this._label);

  final String _label;

  String get label => tr(_label);
}

typedef LibraryLayout = ({LibraryDisplay display, int columns});

/// Mode tampilan + jumlah kolom grid (0 = otomatis menurut lebar layar).
final libraryLayoutProvider = NotifierProvider<LibraryLayoutNotifier, LibraryLayout>(LibraryLayoutNotifier.new);

class LibraryLayoutNotifier extends Notifier<LibraryLayout> {
  static const _key = 'library.layout.v1';
  static const maxColumns = 6;

  @override
  LibraryLayout build() {
    final raw = ref.watch(sharedPreferencesProvider).getStringList(_key) ?? const [];
    return (
      display: raw.isNotEmpty
          ? LibraryDisplay.values.where((v) => v.name == raw[0]).firstOrNull ?? LibraryDisplay.grid
          : LibraryDisplay.grid,
      columns: raw.length > 1 ? (int.tryParse(raw[1]) ?? 0).clamp(0, maxColumns) : 0,
    );
  }

  Future<void> set({LibraryDisplay? display, int? columns}) async {
    state = (display: display ?? state.display, columns: (columns ?? state.columns).clamp(0, maxColumns));
    await ref.read(sharedPreferencesProvider).setStringList(_key, [state.display.name, '${state.columns}']);
  }
}

typedef SourceItemKey =({String sourceId, String url});

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
