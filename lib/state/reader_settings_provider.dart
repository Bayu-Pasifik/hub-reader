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

/// Tampilan halaman komik: potong tepi kosong dan filter warna.
class ReaderDisplay {
  const ReaderDisplay({this.cropBorders = false, this.grayscale = false, this.invert = false, this.dim = 0});

  /// Buang tepi polos (putih/hitam) di sekeliling gambar. Di mode webtoon
  /// hanya kiri-kanan, supaya potongan strip tetap menyambung.
  final bool cropBorders;
  final bool grayscale;
  final bool invert;

  /// 0 (normal) … 0.8 (sangat redup): lapisan hitam di atas halaman.
  final double dim;

  bool get hasColorFilter => grayscale || invert || dim > 0;

  ReaderDisplay copyWith({bool? cropBorders, bool? grayscale, bool? invert, double? dim}) => ReaderDisplay(
        cropBorders: cropBorders ?? this.cropBorders,
        grayscale: grayscale ?? this.grayscale,
        invert: invert ?? this.invert,
        dim: dim ?? this.dim,
      );

  Map<String, Object> toJson() => {'crop': cropBorders, 'gray': grayscale, 'invert': invert, 'dim': dim};

  factory ReaderDisplay.fromJson(Map<String, Object?> json) => ReaderDisplay(
        cropBorders: json['crop'] == true,
        grayscale: json['gray'] == true,
        invert: json['invert'] == true,
        dim: ((json['dim'] as num?)?.toDouble() ?? 0).clamp(0, 0.8),
      );

  @override
  bool operator ==(Object other) =>
      other is ReaderDisplay &&
      other.cropBorders == cropBorders &&
      other.grayscale == grayscale &&
      other.invert == invert &&
      other.dim == dim;

  @override
  int get hashCode => Object.hash(cropBorders, grayscale, invert, dim);
}

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
