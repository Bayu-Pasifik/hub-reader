import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/strings.dart';
import 'core_providers.dart';

/// Cara menampilkan daftar judul di halaman jelajah sumber.
///
/// Empat pertama sama dengan tampilan Favorit; dua terakhir khusus jelajah.
enum BrowseDisplay {
  grid('Grid'),
  compact('Grid ringkas'),
  coverOnly('Sampul saja'),
  list('Daftar'),
  denseList('Daftar ringkas'),
  wideCard('Kartu lebar');

  const BrowseDisplay(this._label);

  final String _label;

  String get label => tr(_label);

  /// Satu kolom: jumlah kolom tidak berlaku.
  bool get isSingleColumn => this == list || this == denseList || this == wideCard;
}

typedef BrowseLayout = ({BrowseDisplay display, int columns});

/// Tampilan daftar judul di halaman jelajah sumber (Populer / Terbaru / hasil cari).
/// Disimpan terpisah untuk komik dan novel.
class BrowseLayoutNotifier extends Notifier<BrowseLayout> {
  BrowseLayoutNotifier(this._key);

  final String _key;
  static const maxColumns = 6;

  @override
  BrowseLayout build() {
    final raw = ref.watch(sharedPreferencesProvider).getStringList(_key) ?? const [];
    return (
      display: raw.isNotEmpty
          ? BrowseDisplay.values.where((v) => v.name == raw[0]).firstOrNull ?? BrowseDisplay.grid
          : BrowseDisplay.grid,
      columns: raw.length > 1 ? (int.tryParse(raw[1]) ?? 0).clamp(0, maxColumns) : 0,
    );
  }

  Future<void> set({BrowseDisplay? display, int? columns}) async {
    state = (display: display ?? state.display, columns: (columns ?? state.columns).clamp(0, maxColumns));
    await ref.read(sharedPreferencesProvider).setStringList(_key, [state.display.name, '${state.columns}']);
  }
}

final comicBrowseLayoutProvider = NotifierProvider<BrowseLayoutNotifier, BrowseLayout>(
  () => BrowseLayoutNotifier('browse.comic.layout.v1'),
);

final novelBrowseLayoutProvider = NotifierProvider<BrowseLayoutNotifier, BrowseLayout>(
  () => BrowseLayoutNotifier('browse.novel.layout.v1'),
);
