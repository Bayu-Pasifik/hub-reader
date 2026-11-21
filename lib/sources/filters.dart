/// Filter pencarian per sumber (padanan `FilterList` di Mihon, disederhanakan
/// menjadi dua jenis: pilih satu dan pilih banyak).
library;

class FilterOption {
  const FilterOption(this.label, this.value);

  final String label;

  /// Nilai yang dikirim ke situs. String kosong = "semua"/default.
  final String value;
}

sealed class FilterDef {
  const FilterDef(this.key, this.label, this.options);

  /// Kunci internal, juga dipakai sebagai nama parameter URL bila cocok.
  final String key;
  final String label;
  final List<FilterOption> options;
}

/// Pilih satu. Opsi pertama dianggap default.
class SelectFilterDef extends FilterDef {
  const SelectFilterDef(super.key, super.label, super.options);
}

/// Pilih banyak (mis. genre).
class MultiSelectFilterDef extends FilterDef {
  const MultiSelectFilterDef(super.key, super.label, super.options);
}

/// Nilai filter yang dipilih pengguna. Immutable dan punya equality
/// struktural, jadi aman dipakai sebagai kunci provider Riverpod.
class FilterValues {
  const FilterValues._(this._values);

  static const empty = FilterValues._({});

  final Map<String, List<String>> _values;

  bool get isEmpty => _values.isEmpty;

  /// Jumlah filter yang aktif (untuk badge).
  int get activeCount => _values.length;

  String? single(String key) => _values[key]?.firstOrNull;

  List<String> multi(String key) => _values[key] ?? const [];

  /// Set nilai pilih-satu. String kosong menghapus filter itu.
  FilterValues withSingle(String key, String value) => _copyWith(key, value.isEmpty ? const [] : [value]);

  /// Tambah/hapus satu nilai pilih-banyak.
  FilterValues toggleMulti(String key, String value) {
    final current = multi(key);
    return _copyWith(
      key,
      current.contains(value) ? current.where((v) => v != value).toList() : [...current, value],
    );
  }

  FilterValues _copyWith(String key, List<String> values) {
    final next = {..._values};
    if (values.isEmpty) {
      next.remove(key);
    } else {
      next[key] = List.unmodifiable(values);
    }
    return FilterValues._(Map.unmodifiable(next));
  }

  String get _canonical {
    final keys = _values.keys.toList()..sort();
    return keys.map((k) => '$k=${([..._values[k]!]..sort()).join(',')}').join('&');
  }

  @override
  bool operator ==(Object other) => other is FilterValues && other._canonical == _canonical;

  @override
  int get hashCode => _canonical.hashCode;

  @override
  String toString() => 'FilterValues($_canonical)';
}

/// Filter yang cocok dengan [genre] (nama genre pada detail seri), atau null
/// bila sumber tidak punya filter genre dengan label itu (pemanggil lalu
/// jatuh ke pencarian teks). Pencocokan tidak membedakan huruf besar/kecil.
FilterValues? filterForGenre(List<FilterDef> defs, String genre) {
  final wanted = genre.trim().toLowerCase();
  if (wanted.isEmpty) return null;
  for (final def in defs) {
    for (final option in def.options) {
      if (option.value.isEmpty || option.label.trim().toLowerCase() != wanted) continue;
      return switch (def) {
        MultiSelectFilterDef() => FilterValues.empty.toggleMulti(def.key, option.value),
        SelectFilterDef() => FilterValues.empty.withSingle(def.key, option.value),
      };
    }
  }
  return null;
}
