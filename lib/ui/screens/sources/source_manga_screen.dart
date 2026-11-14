import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/download.dart';
import '../../../data/models/source_library.dart';
import '../../../sources/local/local_source.dart';
import '../../../sources/models.dart';
import '../../../state/bookmarks_provider.dart';
import '../../../state/download_providers.dart';
import '../../../state/source_library_providers.dart';
import '../../../state/source_providers.dart';
import '../../deep_links.dart';
import '../../router.dart';
import '../../widgets/category_sheet.dart';
import '../../widgets/layout.dart';
import '../../widgets/series_notes.dart';
import '../../widgets/source_widgets.dart';
import '../../widgets/state_views.dart';
import '../tracker_screens.dart';

/// Detail seri dari sumber on-device + daftar bab.
class SourceMangaScreen extends ConsumerStatefulWidget {
  const SourceMangaScreen({super.key, required this.sourceId, required this.url});

  final String sourceId;
  final String url;

  @override
  ConsumerState<SourceMangaScreen> createState() => _SourceMangaScreenState();
}

class _SourceMangaScreenState extends ConsumerState<SourceMangaScreen> {
  bool _descExpanded = false;

  /// Situs mengurutkan terbaru dulu; pengguna bisa membalik.
  bool _oldestFirst = false;

  /// Tampilkan hanya bab ber-bookmark.
  bool _onlyBookmarked = false;

  /// Tekan lama bab: tandai dibaca / bookmark.
  Future<void> _chapterActions(SourceChapter chapter, {required bool done, required bool bookmarked}) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(chapter.name, style: Theme.of(context).textTheme.titleMedium),
            ),
            ListTile(
              leading: Icon(done ? Icons.remove_done : Icons.done_all),
              title: Text(done ? 'Tandai belum dibaca' : 'Tandai sudah dibaca'),
              onTap: () => Navigator.pop(context, 'read'),
            ),
            ListTile(
              leading: Icon(bookmarked ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined),
              title: Text(bookmarked ? 'Hapus bookmark' : 'Bookmark bab ini'),
              onTap: () => Navigator.pop(context, 'bookmark'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    final String message;
    if (action == 'read') {
      await ref.read(sourceProgressProvider.notifier).setDone(_key, chapter.url, done: !done);
      message = done ? '${chapter.name} ditandai belum dibaca' : '${chapter.name} ditandai sudah dibaca';
    } else {
      final now = await ref.read(chapterBookmarksProvider.notifier).toggle(_key, chapter.url);
      message = now ? '${chapter.name} di-bookmark' : 'Bookmark ${chapter.name} dihapus';
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  SourceMangaKey get _key => (sourceId: widget.sourceId, url: widget.url);

  String? _syncedFor;

  /// Selaraskan judul/sampul favorit dengan data terbaru (sekali per muat).
  void _syncFavorite(SourceMangaDetails manga) {
    final stamp = '${manga.title}|${manga.thumbnailUrl}';
    if (_syncedFor == stamp) return;
    _syncedFor = stamp;
    final item = SourceLibraryItem.fromDetails(widget.sourceId, widget.url, manga);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(sourceFavoritesProvider.notifier).refreshItem(item);
    });
  }

  Future<void> _deleteLocal(LocalSource source, SourceMangaDetails manga) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus "${manga.title}"?'),
        content: const Text('File komik di perangkat ikut dihapus dan tidak bisa dikembalikan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await source.deleteSeries(widget.url);
    if (ref.read(isSourceFavoriteProvider(_key))) {
      ref.read(sourceFavoritesProvider.notifier).toggle(SourceLibraryItem.fromDetails(widget.sourceId, widget.url, manga));
    }
    ref.invalidate(sourceListProvider);
    if (mounted) context.pop();
  }

  void _toggleFavorite(SourceMangaDetails manga) {
    final item = SourceLibraryItem.fromDetails(widget.sourceId, widget.url, manga);
    final wasFavorite = ref.read(isSourceFavoriteProvider(_key));
    ref.read(sourceFavoritesProvider.notifier).toggle(item);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(wasFavorite ? 'Dihapus dari favorit' : 'Ditambahkan ke favorit'),
        duration: const Duration(seconds: 4),
        action: wasFavorite ? null : SnackBarAction(label: 'Kategori', onPressed: () => showCategorySheet(context, item.key)),
      ));
  }

  /// Unduh massal. [unreadOnly]: lewati bab yang sudah selesai dibaca.
  /// [limit]: hanya N bab berikutnya setelah bab terakhir dibaca.
  void _downloadMany(SourceMangaDetails manga, {int? limit}) {
    final progress = ref.read(sourceSeriesProgressProvider(_key));
    final lastRead = ref.read(sourceLastReadProvider(_key));
    // Urut lama → baru supaya antrean mengikuti urutan baca.
    var chapters = manga.chapters.reversed.toList();
    if (limit != null && lastRead != null) {
      final from = chapters.indexWhere((c) => c.url == lastRead.chapterUrl);
      if (from >= 0) chapters = chapters.sublist(from + 1);
    }
    chapters = chapters.where((c) => !(progress[c.url]?.done ?? false)).toList();
    if (limit != null) chapters = chapters.take(limit).toList();
    ref.read(downloadQueueProvider.notifier).enqueue(
          sourceId: widget.sourceId,
          mangaUrl: widget.url,
          manga: manga,
          chapters: chapters,
        );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${chapters.length} bab masuk antrean unduhan')));
  }

  void _openChapter(String chapterUrl) => context.push(sourceReaderLocation(widget.sourceId, widget.url, chapterUrl));

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(sourceProvider(widget.sourceId));
    final details = ref.watch(sourceDetailsProvider(_key));
    final headers = source?.imageHeaders() ?? const <String, String>{};
    final isFavorite = ref.watch(isSourceFavoriteProvider(_key));
    final lastRead = ref.watch(sourceLastReadProvider(_key));
    final progress = ref.watch(sourceSeriesProgressProvider(_key));
    final bookmarks = ref.watch(seriesBookmarksProvider(_key));
    final loaded = details.valueOrNull;
    if (loaded != null) _syncFavorite(loaded);

    return Scaffold(
      appBar: AppBar(
        title: Text(details.valueOrNull?.title ?? source?.name ?? ''),
        actions: [
          if (loaded != null)
            IconButton(
              tooltip: isFavorite ? 'Hapus dari favorit' : 'Tambah ke favorit',
              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
              color: isFavorite ? Theme.of(context).colorScheme.primary : null,
              onPressed: () => _toggleFavorite(loaded),
            ),
          if (loaded != null && source is! LocalSource)
            PopupMenuButton<int?>(
              tooltip: 'Unduh',
              icon: const Icon(Icons.download_outlined),
              onSelected: (limit) => _downloadMany(loaded, limit: limit == 0 ? null : limit),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 5, child: Text('Unduh 5 bab berikutnya')),
                PopupMenuItem(value: 0, child: Text('Unduh semua yang belum dibaca')),
              ],
            ),
          IconButton(
            tooltip: _oldestFirst ? 'Urutkan terbaru dulu' : 'Urutkan terlama dulu',
            icon: Icon(_oldestFirst ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () => setState(() => _oldestFirst = !_oldestFirst),
          ),
          if (loaded != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'note') editSeriesNote(context, ref, _key);
                if (v == 'bookmarked') setState(() => _onlyBookmarked = !_onlyBookmarked);
                if (v == 'migrate') context.push(migrateLocation(widget.sourceId, widget.url, loaded.title));
                if (v == 'delete' && source is LocalSource) _deleteLocal(source, loaded);
                if (v == 'share') {
                  DeepLinks.share(
                    title: loaded.title,
                    webUrl: loaded.url,
                    location: sourceMangaLocation(widget.sourceId, widget.url),
                  );
                }
                if (v == 'track') {
                  final progress = ref.read(sourceSeriesProgressProvider(_key));
                  int? local;
                  for (final c in loaded.chapters) {
                    final n = c.number;
                    if (n != null && (progress[c.url]?.done ?? false) && (local == null || n > local)) {
                      local = n.floor();
                    }
                  }
                  showModalBottomSheet<void>(
                    context: context,
                    useRootNavigator: true,
                    showDragHandle: true,
                    isScrollControlled: true,
                    builder: (_) => TrackingSheet(
                      seriesKey: '${widget.sourceId}|${widget.url}',
                      title: loaded.title,
                      novel: false,
                      localProgress: local,
                    ),
                  );
                }
              },
              itemBuilder: (_) => [
                if (source is! LocalSource) const PopupMenuItem(value: 'share', child: Text('Bagikan')),
                const PopupMenuItem(value: 'track', child: Text('Tracking')),
                const PopupMenuItem(value: 'note', child: Text('Catatan')),
                CheckedPopupMenuItem(
                  value: 'bookmarked',
                  checked: _onlyBookmarked,
                  child: const Text('Hanya bab ber-bookmark'),
                ),
                const PopupMenuItem(value: 'migrate', child: Text('Pindah sumber')),
                if (source is LocalSource) const PopupMenuItem(value: 'delete', child: Text('Hapus dari perangkat')),
              ],
            ),
        ],
      ),
      body: details.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => SourceErrorView(
          error: error,
          onRetry: () => ref.invalidate(sourceDetailsProvider(_key)),
          verifyUrl: widget.url,
        ),
        data: (manga) {
          final ordered = _oldestFirst ? manga.chapters.reversed.toList() : manga.chapters;
          final chapters = _onlyBookmarked ? ordered.where((c) => bookmarks.contains(c.url)).toList() : ordered;
          // Tablet / landscape lebar: info seri di kiri, daftar bab di kanan.
          final wide = MediaQuery.sizeOf(context).width >= twoPaneBreakpoint;
          final list = RefreshIndicator(
            onRefresh: () => ref.refresh(sourceDetailsProvider(_key).future),
            child: CustomScrollView(
              slivers: [
                if (!wide) SliverToBoxAdapter(child: _header(context, manga, headers)),
                if (chapters.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyView(
                      compact: true,
                      title: _onlyBookmarked && ordered.isNotEmpty ? 'Belum ada bab ber-bookmark' : 'Belum ada bab',
                    ),
                  )
                else
                  SliverList.separated(
                    itemCount: chapters.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final chapter = chapters[i];
                      final isLastRead = chapter.url == lastRead?.chapterUrl;
                      final p = progress[chapter.url];
                      final done = p?.done ?? false;
                      final inProgress = p != null && !done && p.total > 0;
                      final subtitle = [
                        if (chapter.uploadedAt != null) relativeTime(chapter.uploadedAt!),
                        if (inProgress) 'Hal. ${p.page + 1}/${p.total}',
                      ].join(' · ');
                      // Bab selesai diredupkan, seperti Mihon.
                      final fade = done && !isLastRead;
                      final bookmarked = bookmarks.contains(chapter.url);
                      return ListTile(
                        leading: isLastRead ? const Icon(Icons.play_circle_outline, size: 20) : null,
                        title: Text(
                          chapter.name,
                          style: TextStyle(
                            fontWeight: isLastRead ? FontWeight.w700 : null,
                            color: fade ? Theme.of(context).disabledColor : null,
                          ),
                        ),
                        subtitle: subtitle.isEmpty
                            ? null
                            : Text(
                                subtitle,
                                style: fade ? TextStyle(color: Theme.of(context).disabledColor) : null,
                              ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (bookmarked) const ChapterBookmarkIcon(),
                            if (done) const Icon(Icons.done_all, size: 18),
                            if (source is! LocalSource)
                            _ChapterDownloadButton(
                              sourceId: widget.sourceId,
                              mangaUrl: widget.url,
                              manga: manga,
                              chapter: chapter,
                            ),
                          ],
                        ),
                        onTap: () => _openChapter(chapter.url),
                        onLongPress: () => _chapterActions(chapter, done: done, bookmarked: bookmarked),
                      );
                    },
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 88)),
              ],
            ),
          );
          if (!wide) return list;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 380,
                child: SingleChildScrollView(child: _header(context, manga, headers)),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: list),
            ],
          );
        },
      ),
      floatingActionButton: switch (loaded) {
        final SourceMangaDetails manga when manga.chapters.isNotEmpty => lastRead != null
            ? FloatingActionButton.extended(
                onPressed: () => _openChapter(lastRead.chapterUrl),
                icon: const Icon(Icons.play_arrow),
                label: Text('Lanjutkan · ${lastRead.chapterName}'),
              )
            : FloatingActionButton.extended(
                // Bab terakhir di list situs = bab pertama.
                onPressed: () => _openChapter(manga.chapters.last.url),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Mulai baca'),
              ),
        _ => null,
      },
    );
  }

  Widget _header(BuildContext context, SourceMangaDetails manga, Map<String, String> headers) {
    final theme = Theme.of(context);
    final meta = [
      if (manga.author != null) manga.author!,
      if (manga.artist != null && manga.artist != manga.author) manga.artist!,
      manga.status.label,
      '${manga.chapters.length} bab',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SourceCover(url: manga.thumbnailUrl, headers: headers, width: 110),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(manga.title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(meta, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          if (manga.genres.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final g in manga.genres) Chip(label: Text(g), visualDensity: VisualDensity.compact),
              ],
            ),
          ],
          if (manga.description != null) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => setState(() => _descExpanded = !_descExpanded),
              child: Text(
                manga.description!,
                maxLines: _descExpanded ? null : 4,
                overflow: _descExpanded ? null : TextOverflow.ellipsis,
              ),
            ),
          ],
          SeriesNoteCard(series: _key),
        ],
      ),
    );
  }
}

/// Status unduhan satu bab: unduh / progres / terunduh (ketuk untuk hapus).
class _ChapterDownloadButton extends ConsumerWidget {
  const _ChapterDownloadButton({
    required this.sourceId,
    required this.mangaUrl,
    required this.manga,
    required this.chapter,
  });

  final String sourceId;
  final String mangaUrl;
  final SourceMangaDetails manga;
  final SourceChapter chapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = chapterKey(sourceId, chapter.url);
    final downloaded = ref.watch(downloadIndexProvider.select((i) => i.containsKey(key)));
    final task = ref.watch(downloadTaskProvider(key));
    final queue = ref.read(downloadQueueProvider.notifier);

    if (downloaded) {
      return IconButton(
        tooltip: 'Hapus unduhan',
        icon: Icon(Icons.offline_pin, color: Theme.of(context).colorScheme.primary),
        onPressed: () => ref.read(downloadIndexProvider.notifier).remove(key),
      );
    }
    return switch (task?.status) {
      DownloadStatus.queued || DownloadStatus.downloading => IconButton(
          tooltip: 'Batalkan unduhan',
          onPressed: () => queue.cancel(key),
          icon: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, value: task!.progress),
          ),
        ),
      DownloadStatus.failed => IconButton(
          tooltip: 'Gagal: ${task!.error ?? ''}. Coba lagi',
          icon: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          onPressed: () => queue.retry(key),
        ),
      null => IconButton(
          tooltip: 'Unduh',
          icon: const Icon(Icons.download_for_offline_outlined),
          onPressed: () => queue.enqueue(
            sourceId: sourceId,
            mangaUrl: mangaUrl,
            manga: manga,
            chapters: [chapter],
          ),
        ),
    };
  }
}
