import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';
import 'source_library_providers.dart' show LibraryDisplay, LibraryLayout;

/// Tampilan daftar judul di halaman jelajah sumber (Populer / Terbaru / hasil cari).
///
/// Memakai pilihan yang sama dengan tampilan Favorit (grid, grid ringkas, sampul
/// saja, daftar) + jumlah kolom, tetapi disimpan terpisah untuk komik dan novel.
class BrowseLayoutNotifier extends Notifier<LibraryLayout> {
  BrowseLayoutNotifier(this._key);

  final String _key;
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

final comicBrowseLayoutProvider = NotifierProvider<BrowseLayoutNotifier, LibraryLayout>(
  () => BrowseLayoutNotifier('browse.comic.layout.v1'),
);

final novelBrowseLayoutProvider = NotifierProvider<BrowseLayoutNotifier, LibraryLayout>(
  () => BrowseLayoutNotifier('browse.novel.layout.v1'),
);
