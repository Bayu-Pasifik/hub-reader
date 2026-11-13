import 'dart:async';

import '../data/models/source_library.dart';
import '../sources/models.dart';
import 'bookmarks_provider.dart';
import 'library_chapters.dart';
import 'source_library_providers.dart';

/// Hasil pindah sumber, untuk ditampilkan ke pengguna.
typedef MigrationResult = ({int markedRead, String? lastRead});

/// Nomor bab tertinggi yang sudah selesai dibaca di [chapters] menurut [progress].
double? highestReadNumber(List<LibraryChapter> chapters, Map<String, SourceChapterProgress> progress) {
  double? best;
  for (final c in chapters) {
    final n = c.number;
    if (n == null || !(progress[c.url]?.done ?? false)) continue;
    if (best == null || n > best) best = n;
  }
  return best;
}

/// Pindahkan seri dari [from] ke [to] (Mihon "Migrate"): favorit beserta
/// kategori & tanggal ditambahkan, tanda sudah dibaca (dicocokkan lewat nomor
/// bab), bookmark bab (juga lewat nomor bab), catatan seri, dan riwayat bab
/// terakhir. Bila [keepOld] false, favorit lama dihapus.
Future<MigrationResult> migrateSeries(
  ProviderReader read, {
  required SourceLibraryItem from,
  required SourceLibraryItem to,
  required bool keepOld,
}) async {
  final fromKey = (sourceId: from.sourceId, url: from.url);
  final toKey = (sourceId: to.sourceId, url: to.url);

  // Bab yang sudah dibaca di sumber lama → nomor bab tertinggi. Bila sumber
  // lama sudah mati, pakai nomor dari judul bab di riwayat.
  final oldProgress = read(sourceSeriesProgressProvider(fromKey));
  final lastRead = read(sourceLastReadProvider(fromKey));
  double? readUpTo;
  var oldChapters = const <LibraryChapter>[];
  try {
    oldChapters = await fetchLibraryChapters(read, from, allPages: true).timeout(const Duration(seconds: 40));
    readUpTo = highestReadNumber(oldChapters, oldProgress);
  } catch (_) {
    readUpTo = null;
  }
  final lastReadNumber = lastRead == null ? null : libraryChapterNumber(lastRead.chapterName, null);
  if (readUpTo == null && lastReadNumber != null) readUpTo = lastReadNumber - 1;

  final newChapters = await fetchLibraryChapters(read, to, allPages: true).timeout(const Duration(seconds: 60));
  final toMark = [
    for (final c in newChapters)
      if (readUpTo != null && c.number != null && c.number! <= readUpTo) c.url,
  ];
  if (toMark.isNotEmpty) {
    await read(sourceProgressProvider.notifier).setDoneMany(toKey, toMark, done: true);
  }

  // Bookmark: nomor bab yang ditandai di sumber lama.
  final oldBookmarks = read(seriesBookmarksProvider(fromKey));
  final bookmarkedNumbers = {
    for (final c in oldChapters)
      if (c.number != null && oldBookmarks.contains(c.url)) c.number!,
  };
  final toBookmark = [
    for (final c in newChapters)
      if (c.number != null && bookmarkedNumbers.contains(c.number)) c.url,
  ];
  if (toBookmark.isNotEmpty) {
    await read(chapterBookmarksProvider.notifier).setMany(toKey, toBookmark, bookmarked: true);
  }

  // Catatan: disalin bila seri tujuan belum punya.
  final note = read(seriesNoteProvider(fromKey));
  if (note != null && read(seriesNoteProvider(toKey)) == null) {
    await read(seriesNotesProvider.notifier).set(toKey, note);
  }

  // Riwayat: bab dengan nomor sama dengan bab terakhir dibaca.
  String? resumed;
  if (lastReadNumber != null) {
    final match = newChapters.where((c) => c.number == lastReadNumber).firstOrNull;
    if (match != null) {
      await read(sourceHistoryProvider.notifier).record(to, SourceChapter(url: match.url, name: match.name));
      resumed = match.name;
    }
  }

  // Favorit: salin kategori & tanggal, lalu (opsional) hapus yang lama.
  final favorites = read(sourceFavoritesProvider.notifier);
  final old = read(sourceFavoritesProvider).where((f) => f.item.key == from.key).firstOrNull;
  final existing = read(sourceFavoritesProvider).where((f) => f.item.key == to.key).firstOrNull;
  if (existing == null) {
    await favorites.restore(SourceFavorite(
      item: to,
      addedAt: old?.addedAt ?? DateTime.now(),
      categories: old?.categories ?? const [],
    ));
  } else if (old != null) {
    await favorites.setCategories(to.key, {...existing.categories, ...old.categories}.toList());
  }
  if (!keepOld && old != null) await favorites.remove(from.key);

  return (markedRead: toMark.length, lastRead: resumed);
}
