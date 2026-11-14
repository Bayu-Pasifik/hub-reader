import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/source_library.dart';
import '../sources/html_utils.dart';
import '../sources/models.dart';
import '../sources/source_exception.dart';
import 'novel_providers.dart';
import 'source_providers.dart';

/// Bab satu seri (komik atau novel) dalam bentuk seragam.
typedef LibraryChapter = ({String url, String name, double? number});

/// `ref.read` dari Ref maupun WidgetRef.
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// Nomor bab: dari situs/plugin, atau ditebak dari judul bab.
double? libraryChapterNumber(String name, double? fromSource) =>
    (fromSource != null && fromSource >= 0) ? fromSource : parseChapterNumber(name);

/// Ambil daftar bab terbaru seri [item] dari situsnya.
///
/// Novel berhalaman: hanya halaman terakhir (bab terbaru) bila [allPages]
/// false; semua halaman bila true (untuk pindah sumber).
Future<List<LibraryChapter>> fetchLibraryChapters(
  ProviderReader read,
  SourceLibraryItem item, {
  bool allPages = false,
}) async =>
    (await fetchLibrarySeries(read, item, allPages: allPages)).chapters;

/// Status "tamat" dari teks bebas situs novel.
bool isCompletedStatusText(String? text) {
  final t = text?.toLowerCase().trim();
  if (t == null || t.isEmpty) return false;
  if (RegExp(r'\b(not|un|in|belum)\s*-?\s*(completed?|finished|tamat|selesai)').hasMatch(t)) return false;
  return RegExp(r'\b(completed?|complete|finished|ended|tamat|selesai)\b').hasMatch(t);
}

/// Bab terbaru + apakah seri sudah tamat (dari satu kali ambil detail).
Future<({List<LibraryChapter> chapters, bool completed})> fetchLibrarySeries(
  ProviderReader read,
  SourceLibraryItem item, {
  bool allPages = false,
}) async {
  if (isNovelSourceId(item.sourceId)) {
    final source = await read(novelSourceProvider(pluginIdOf(item.sourceId)).future);
    final details = await source.details(item.url);
    var chapters = details.chapters;
    if (details.totalPages > 1) {
      // Bab terbaru ada di halaman terakhir.
      final pages = allPages ? [for (var p = 1; p <= details.totalPages; p++) p] : [details.totalPages];
      chapters = [for (final p in pages) ...await source.chapterPage(item.url, p)];
    } else if (chapters.isEmpty && source.hasParsePage) {
      chapters = await source.chapterPage(item.url, 1);
    }
    return (
      chapters: [for (final c in chapters) (url: c.path, name: c.name, number: libraryChapterNumber(c.name, c.number))],
      completed: isCompletedStatusText(details.status),
    );
  }
  final source = read(sourceProvider(item.sourceId));
  if (source == null) throw SourceException(SourceErrorKind.unknown, detail: 'Sumber ${item.sourceId} tidak ada.');
  final details = await source.details(item.url);
  return (
    chapters: [
      for (final c in details.chapters) (url: c.url, name: c.name, number: libraryChapterNumber(c.name, c.number)),
    ],
    completed: details.status == SourceMangaStatus.completed,
  );
}
