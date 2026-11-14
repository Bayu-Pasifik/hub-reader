import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';

enum ReaderMode {
  /// Gulir vertikal tanpa jeda (manhwa/webtoon).
  webtoon('Webtoon (vertikal)'),

  /// Per halaman, geser ke kiri untuk lanjut (komik barat/manhua).
  pagedLtr('Per halaman (kiri → kanan)'),

  /// Per halaman, geser ke kanan untuk lanjut (manga Jepang).
  pagedRtl('Per halaman (kanan → kiri)');

  const ReaderMode(this.label);

  final String label;

  bool get isPaged => this != webtoon;

  static ReaderMode? byName(String? name) => values.where((m) => m.name == name).firstOrNull;
}

final readerModeProvider = NotifierProvider<ReaderModeNotifier, ReaderMode>(ReaderModeNotifier.new);

class ReaderModeNotifier extends Notifier<ReaderMode> {
  static const _key = 'reader.mode.v1';

  @override
  ReaderMode build() {
    final name = ref.watch(sharedPreferencesProvider).getString(_key);
    return ReaderMode.byName(name) ?? ReaderMode.webtoon;
  }

  Future<void> set(ReaderMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(_key, mode.name);
  }
}

/// Bentuk zona ketuk untuk pindah halaman (mode per halaman).
enum TapZoneLayout {
  /// Sepertiga kiri dan kanan; tengah tidak berbuat apa-apa.
  thirds('Sepertiga (kiri / kanan)', 1 / 3),

  /// Setengah layar kiri dan kanan.
  halves('Setengah layar', 1 / 2),

  /// Pinggir sempit: seperempat kiri dan kanan.
  edges('Pinggir sempit', 1 / 4),

  /// Ketuk tidak memindah halaman (hanya geser).
  off('Mati (hanya geser)', 0);

  const TapZoneLayout(this.label, this.zone);

  final String label;

  /// Lebar tiap zona sebagai pecahan lebar layar.
  final double zone;

  static TapZoneLayout? byName(String? name) => values.where((m) => m.name == name).firstOrNull;
}

/// Pengaturan zona ketuk: bentuk dan arah (tukar kiri/kanan).
class TapZones {
  const TapZones({this.layout = TapZoneLayout.thirds, this.swap = false});

  final TapZoneLayout layout;

  /// Tukar fungsi kiri dan kanan.
  final bool swap;

  TapZones copyWith({TapZoneLayout? layout, bool? swap}) =>
      TapZones(layout: layout ?? this.layout, swap: swap ?? this.swap);

  /// Hasil ketukan di posisi [x] pada layar selebar [width]: true = halaman
  /// berikutnya, false = sebelumnya, null = tidak ada aksi. [rtl] = mode
  /// kanan → kiri (ketuk kiri maju).
  bool? resolve(double x, double width, {required bool rtl}) {
    if (layout == TapZoneLayout.off || width <= 0) return null;
    final edge = width * layout.zone;
    final bool? right = x >= width - edge ? true : (x <= edge ? false : null);
    if (right == null) return null;
    return (right != rtl) != swap;
  }

  Map<String, Object> toJson() => {'layout': layout.name, 'swap': swap};

  factory TapZones.fromJson(Map<String, Object?> json) => TapZones(
        layout: TapZoneLayout.byName(json['layout'] as String?) ?? TapZoneLayout.thirds,
        swap: json['swap'] == true,
      );
}

final tapZonesProvider = NotifierProvider<TapZonesNotifier, TapZones>(TapZonesNotifier.new);

class TapZonesNotifier extends Notifier<TapZones> {
  static const _key = 'reader.tapzones.v1';

  @override
  TapZones build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const TapZones();
    try {
      return TapZones.fromJson(Map<String, Object?>.from(jsonDecode(raw) as Map));
    } on Object {
      return const TapZones();
    }
  }

  Future<void> set(TapZones value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setString(_key, jsonEncode(value.toJson()));
  }
}

/// Tampilan halaman komik: potong tepi kosong dan filter warna.
class ReaderDisplay {
  const ReaderDisplay({
    this.cropBorders = false,
    this.grayscale = false,
    this.invert = false,
    this.dim = 0,
    this.spread = true,
  });

  /// Dua halaman berdampingan (mode per halaman, tablet landscape).
  final bool spread;

  /// Buang tepi polos (putih/hitam) di sekeliling gambar. Di mode webtoon
  /// hanya kiri-kanan, supaya potongan strip tetap menyambung.
  final bool cropBorders;
  final bool grayscale;
  final bool invert;

  /// 0 (normal) … 0.8 (sangat redup): lapisan hitam di atas halaman.
  final double dim;

  bool get hasColorFilter => grayscale || invert || dim > 0;

  ReaderDisplay copyWith({bool? cropBorders, bool? grayscale, bool? invert, double? dim, bool? spread}) =>
      ReaderDisplay(
        cropBorders: cropBorders ?? this.cropBorders,
        grayscale: grayscale ?? this.grayscale,
        invert: invert ?? this.invert,
        dim: dim ?? this.dim,
        spread: spread ?? this.spread,
      );

  Map<String, Object> toJson() =>
      {'crop': cropBorders, 'gray': grayscale, 'invert': invert, 'dim': dim, 'spread': spread};

  factory ReaderDisplay.fromJson(Map<String, Object?> json) => ReaderDisplay(
        cropBorders: json['crop'] == true,
        grayscale: json['gray'] == true,
        invert: json['invert'] == true,
        dim: ((json['dim'] as num?)?.toDouble() ?? 0).clamp(0, 0.8),
        spread: json['spread'] != false,
      );

  @override
  bool operator ==(Object other) =>
      other is ReaderDisplay &&
      other.cropBorders == cropBorders &&
      other.grayscale == grayscale &&
      other.invert == invert &&
      other.dim == dim &&
      other.spread == spread;

  @override
  int get hashCode => Object.hash(cropBorders, grayscale, invert, dim, spread);
}

/// Lebar minimum (dp) layar landscape agar dua halaman ditampilkan.
const spreadMinWidth = 700.0;

/// Pemetaan halaman ↔ spread. Halaman 0 (sampul) berdiri sendiri, sisanya
/// berpasangan: (1,2), (3,4), …
int spreadOfPage(int page) => page <= 0 ? 0 : (page + 1) ~/ 2;

/// Halaman-halaman dalam [spread] dari [total] halaman.
List<int> pagesOfSpread(int spread, int total) {
  if (spread == 0) return total > 0 ? [0] : const [];
  final first = 2 * spread - 1;
  return [for (var p = first; p <= first + 1 && p < total; p++) p];
}

/// Jumlah spread untuk [total] halaman.
int spreadCount(int total) => total <= 0 ? 0 : 1 + (total / 2).floor();

final readerDisplayProvider = NotifierProvider<ReaderDisplayNotifier, ReaderDisplay>(ReaderDisplayNotifier.new);

class ReaderDisplayNotifier extends Notifier<ReaderDisplay> {
  static const _key = 'reader.display.v1';

  @override
  ReaderDisplay build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const ReaderDisplay();
    try {
      return ReaderDisplay.fromJson(Map<String, Object?>.from(jsonDecode(raw) as Map));
    } on Object {
      return const ReaderDisplay();
    }
  }

  Future<void> set(ReaderDisplay value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setString(_key, jsonEncode(value.toJson()));
  }
}

/// Pengaturan khusus satu seri; null = ikut pengaturan umum.
class SeriesReaderOverride {
  const SeriesReaderOverride({this.mode, this.cropBorders});

  final ReaderMode? mode;
  final bool? cropBorders;

  Map<String, Object> toJson() => {
        if (mode != null) 'mode': mode!.name,
        if (cropBorders != null) 'crop': cropBorders!,
      };

  factory SeriesReaderOverride.fromJson(Map<String, Object?> json) => SeriesReaderOverride(
        mode: ReaderMode.byName(json['mode'] as String?),
        cropBorders: json['crop'] as bool?,
      );
}

/// Kunci seri: `<sourceId>|<url seri>` (sama dengan kunci pustaka sumber).
String seriesReaderKey(String sourceId, String url) => '$sourceId|$url';

final seriesReaderOverridesProvider =
    NotifierProvider<SeriesReaderOverridesNotifier, Map<String, SeriesReaderOverride>>(
  SeriesReaderOverridesNotifier.new,
);

class SeriesReaderOverridesNotifier extends Notifier<Map<String, SeriesReaderOverride>> {
  static const _key = 'reader.series.v1';

  @override
  Map<String, SeriesReaderOverride> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const {};
    try {
      final map = jsonDecode(raw) as Map;
      return {
        for (final e in map.entries)
          '${e.key}': SeriesReaderOverride.fromJson(Map<String, Object?>.from(e.value as Map)),
      };
    } on Object {
      return const {};
    }
  }

  /// Simpan override seri; null menghapusnya (kembali ke pengaturan umum).
  Future<void> set(String seriesKey, SeriesReaderOverride? value) async {
    final next = {...state};
    if (value == null) {
      next.remove(seriesKey);
    } else {
      next[seriesKey] = value;
    }
    state = next;
    await ref.read(sharedPreferencesProvider).setString(
          _key,
          jsonEncode({for (final e in next.entries) e.key: e.value.toJson()}),
        );
  }
}

/// Pengaturan yang berlaku untuk satu seri: override seri bila ada.
typedef EffectiveReader = ({ReaderMode mode, ReaderDisplay display, bool perSeries});

final effectiveReaderProvider = Provider.family<EffectiveReader, String>((ref, seriesKey) {
  final override = ref.watch(seriesReaderOverridesProvider)[seriesKey];
  final ReaderMode mode = override?.mode ?? ref.watch(readerModeProvider);
  final display = ref.watch(readerDisplayProvider);
  return (
    mode: mode,
    display: override?.cropBorders == null ? display : display.copyWith(cropBorders: override!.cropBorders),
    perSeries: override != null,
  );
});
