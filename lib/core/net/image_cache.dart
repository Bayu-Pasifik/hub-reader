import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Satu entri cache gambar: kunci (URL), ukuran byte, dan waktu terakhir dipakai.
typedef ImageCacheEntry = ({String key, int length, DateTime touched});

/// Kunci entri yang harus dibuang supaya total ≤ [maxBytes]: yang paling lama
/// tidak dipakai lebih dulu. [maxBytes] ≤ 0 berarti tanpa batas (tidak ada yang dibuang).
List<String> keysToEvict(Iterable<ImageCacheEntry> entries, int maxBytes) {
  if (maxBytes <= 0) return const [];
  final sorted = entries.toList()..sort((a, b) => a.touched.compareTo(b.touched));
  var total = sorted.fold<int>(0, (sum, e) => sum + e.length);
  final out = <String>[];
  for (final e in sorted) {
    if (total <= maxBytes) break;
    out.add(e.key);
    total -= e.length;
  }
  return out;
}

/// Cache gambar aplikasi (sampul dan halaman komik). Memakai folder dan database
/// yang sama dengan DefaultCacheManager sebelumnya, jadi cache lama tetap terpakai.
/// Batas jumlah file dinaikkan tinggi; ukuran dibatasi lewat [trimTo] (byte).
class AppImageCache extends CacheManager with ImageCacheManager {
  static const key = 'libCachedImageData';

  static final AppImageCache instance = AppImageCache._();

  AppImageCache._() : super(Config(key, maxNrOfCacheObjects: 100000, stalePeriod: const Duration(days: 30)));

  /// Buang entri terlama sampai ukuran total ≤ [maxBytes]. Mengembalikan jumlah
  /// entri yang dibuang. [maxBytes] ≤ 0 = tanpa batas.
  Future<int> trimTo(int maxBytes) async {
    if (maxBytes <= 0) return 0;
    // Membaca daftar entri dari database yang sama dengan manager ini.
    final repo = CacheObjectProvider(databaseName: key);
    // Jangan di-close: sqflite membagi satu koneksi per berkas database, jadi menutupnya
    // juga mematikan koneksi milik manager ini (removeFile lalu gagal diam-diam).
    await repo.open();
    final all = await repo.getAllObjects();
    final evict = keysToEvict([
      for (final o in all)
        if (o.length != null) (key: o.key, length: o.length!, touched: o.touched ?? DateTime.fromMillisecondsSinceEpoch(0)),
    ], maxBytes);
    for (final k in evict) {
      await removeFile(k);
    }
    return evict.length;
  }
}
