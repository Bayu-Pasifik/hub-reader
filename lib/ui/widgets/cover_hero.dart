import 'package:flutter/material.dart';

import 'source_widgets.dart';

/// Tag Hero sampul sebuah seri: sama di daftar (jelajah, pencarian) dan di header
/// layar detail, sehingga sampul "terbang" dari kartu ke header saat dibuka.
String coverHeroTag(String sourceId, String url) => 'cover|$sourceId|$url';

/// Tag untuk item ke-[index] di [items], atau null bila item yang sama sudah
/// muncul lebih awal di daftar. Dua Hero dengan tag sama di satu layar
/// menggagalkan transisi, dan sebagian situs mengirim item ganda antar halaman.
String? coverHeroTagAt<T>(List<T> items, int index, String sourceId, String Function(T item) urlOf) {
  final url = urlOf(items[index]);
  return items.indexWhere((e) => urlOf(e) == url) == index ? coverHeroTag(sourceId, url) : null;
}

/// Data yang sudah diketahui dari daftar, dikirim ke layar detail lewat `extra`
/// GoRouter supaya header (sampul + judul) langsung tampil sebelum detail termuat.
/// Null bila detail dibuka dari tautan, favorit, atau riwayat.
class SeriesPreview {
  const SeriesPreview({required this.title, this.coverUrl});

  final String title;
  final String? coverUrl;
}

/// Header sementara di layar detail selama detail dimuat: sampul (tujuan Hero) dan judul.
class SeriesPreviewHeader extends StatelessWidget {
  const SeriesPreviewHeader({super.key, required this.preview, required this.heroTag, required this.headers});

  final SeriesPreview preview;
  final String heroTag;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SourceCover(url: preview.coverUrl, headers: headers, width: 110, heroTag: heroTag),
          const SizedBox(width: 16),
          Expanded(child: Text(preview.title, style: Theme.of(context).textTheme.titleLarge)),
        ],
      ),
    );
  }
}
