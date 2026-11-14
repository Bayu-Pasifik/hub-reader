import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sources/local/local_source.dart';
import '../sources/models.dart';
import 'source_providers.dart';

/// Kata pencarian untuk mencari seri sejenis dari [manga]: karya penulis yang
/// sama dulu, lalu kata awal judul (sekuel/spin-off biasanya sejudul).
List<String> similarQueries(SourceMangaDetails manga) {
  final queries = <String>[];
  void add(String? q) {
    final v = q?.trim() ?? '';
    if (v.length >= 3 && v != '-' && !queries.any((e) => e.toLowerCase() == v.toLowerCase())) queries.add(v);
  }

  add(manga.author);
  if (manga.artist != manga.author) add(manga.artist);
  final words = manga.title
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.length >= 2) add(words.take(2).join(' '));
  if (words.length >= 3) add(words.take(3).join(' '));
  // Kata judul terpanjang (paling khas) satu per satu: situs mencari lewat judul.
  final keywords = words.where((w) => w.length >= 4).toList()..sort((a, b) => b.length.compareTo(a.length));
  for (final w in keywords.take(3)) {
    add(w);
  }
  return queries;
}

/// Seri sejenis dari sumber yang sama; judul/URL seri ini disaring.
final similarSeriesProvider = FutureProvider.autoDispose.family<List<SourceManga>, SourceMangaKey>((ref, key) async {
  final source = ref.watch(sourceProvider(key.sourceId));
  if (source == null || source is LocalSource) return const [];
  final manga = await ref.watch(sourceDetailsProvider(key).future);
  final seen = <String>{key.url, manga.title.toLowerCase()};
  final result = <SourceManga>[];
  for (final q in similarQueries(manga)) {
    try {
      final page = await source.search(1, q);
      for (final item in page.items) {
        if (seen.add(item.url) && seen.add(item.title.toLowerCase())) result.add(item);
      }
    } on Object {
      // satu kueri gagal tidak membatalkan yang lain
    }
    if (result.length >= 12) break;
  }
  return result.take(12).toList();
});
