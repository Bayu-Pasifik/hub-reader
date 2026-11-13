import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../data/models/download.dart';
import '../../../data/models/source_library.dart';
import '../../../novels/local_epub.dart';
import '../../../novels/novel_models.dart';
import '../../../novels/novel_source.dart';
import '../../../sources/html_utils.dart';
import '../../../sources/models.dart';
import '../../../state/core_providers.dart';
import '../../../state/download_providers.dart';
import '../../../state/novel_providers.dart';
import '../../../state/source_library_providers.dart';
import '../tracker_screens.dart';
import 'novel_export.dart';
import '../../deep_links.dart';
import '../../router.dart';
import '../../widgets/source_widgets.dart';
import '../../widgets/state_views.dart';

/// Halaman daftar bab terakhir yang dibuka per novel (plugin berhalaman).
int novelLastPage(WidgetRef ref, String pluginId, String path) =>
    ref.read(sharedPreferencesProvider).getInt('novels.page.$pluginId|$path') ?? 1;

Future<void> saveNovelLastPage(WidgetRef ref, String pluginId, String path, int page) =>
    ref.read(sharedPreferencesProvider).setInt('novels.page.$pluginId|$path', page);

/// Detail novel + daftar bab.
class NovelDetailScreen extends ConsumerStatefulWidget {
  const NovelDetailScreen({super.key, required this.pluginId, required this.path});

  final String pluginId;
  final String path;

  @override
  ConsumerState<NovelDetailScreen> createState() => _NovelDetailScreenState();
}

class _NovelDetailScreenState extends ConsumerState<NovelDetailScreen> {
  bool _descExpanded = false;
  bool _newestFirst = false;
  late int _page = novelLastPage(ref, widget.pluginId, widget.path);

  NovelKey get _key => (pluginId: widget.pluginId, path: widget.path);
  SourceItemKey get _libKey => (sourceId: novelLibraryId(widget.pluginId), url: widget.path);

  SourceLibraryItem _item(NovelDetails n) => SourceLibraryItem(
        sourceId: novelLibraryId(widget.pluginId),
        url: widget.path,
        title: n.name,
        thumbnailUrl: n.cover,
      );

  String? _syncedFor;

  /// Bab yang sedang tampil (halaman daftar aktif), urutan plugin lama → baru.
  List<NovelChapter> _visible = const [];

  /// Bab terpilih (mode pilih, dari tekan lama).
  final Set<String> _selected = {};
  bool get _selecting => _selected.isNotEmpty;

  void _toggleSelect(String path) =>
      setState(() => _selected.contains(path) ? _selected.remove(path) : _selected.add(path));

  void _markSelected({required bool done}) {
    final paths = {..._selected};
    ref.read(sourceProgressProvider.notifier).setDoneMany(_libKey, paths, done: done);
    setState(_selected.clear);
    _snack(done ? '${paths.length} bab ditandai sudah dibaca' : '${paths.length} bab ditandai belum dibaca');
  }

  /// Semua bab sebelum bab terpilih paling akhir (urutan plugin) jadi sudah dibaca.
  void _markPreviousRead() {
    final last = _visible.lastIndexWhere((c) => _selected.contains(c.path));
    if (last < 0) return;
    final paths = [for (final c in _visible.take(last + 1)) c.path];
    ref.read(sourceProgressProvider.notifier).setDoneMany(_libKey, paths, done: true);
    setState(_selected.clear);
    _snack('${paths.length} bab ditandai sudah dibaca');
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));

  PreferredSizeWidget _selectionBar(NovelDetails? novel) => AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(_selected.clear)),
        title: Text('${_selected.length} dipilih'),
        actions: [
          IconButton(
            tooltip: 'Pilih semua',
            icon: const Icon(Icons.select_all),
            onPressed: () => setState(() => _selected.addAll(_visible.map((c) => c.path))),
          ),
          IconButton(
            tooltip: 'Tandai sudah dibaca',
            icon: const Icon(Icons.done_all),
            onPressed: () => _markSelected(done: true),
          ),
          IconButton(
            tooltip: 'Tandai belum dibaca',
            icon: const Icon(Icons.remove_done),
            onPressed: () => _markSelected(done: false),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'previous') _markPreviousRead();
              if (v == 'download' && novel != null) {
                final chosen = _visible.where((c) => _selected.contains(c.path)).toList();
                _enqueue(novel, chosen);
                setState(_selected.clear);
                _snack('${chosen.length} bab masuk antrean unduhan');
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'previous', child: Text('Tandai sampai sini sudah dibaca')),
              if (novel != null) const PopupMenuItem(value: 'download', child: Text('Unduh yang dipilih')),
            ],
          ),
        ],
      );

  void _syncFavorite(NovelDetails n) {
    final stamp = '${n.name}|${n.cover}';
    if (_syncedFor == stamp) return;
    _syncedFor = stamp;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(sourceFavoritesProvider.notifier).refreshItem(_item(n));
    });
  }

  void _toggleFavorite(NovelDetails n) {
    final was = ref.read(isSourceFavoriteProvider(_libKey));
    ref.read(sourceFavoritesProvider.notifier).toggle(_item(n));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(was ? 'Dihapus dari favorit' : 'Ditambahkan ke favorit'),
        duration: const Duration(seconds: 2),
      ));
  }

  void _open(NovelChapter chapter, {int? page}) {
    final p = page ?? _page;
    saveNovelLastPage(ref, widget.pluginId, widget.path, p);
    context.push(novelReaderLocation(widget.pluginId, widget.path, chapter.path, page: p));
  }

  /// Unduh massal dari daftar bab yang sedang tampil. [limit]: N bab setelah
  /// bab terakhir dibaca; null = semua yang belum dibaca.
  void _downloadMany(NovelDetails novel, {int? limit}) {
    final progress = ref.read(sourceSeriesProgressProvider(_libKey));
    final lastRead = ref.read(sourceLastReadProvider(_libKey));
    var chapters = _visible;
    if (limit != null && lastRead != null) {
      final from = chapters.indexWhere((c) => c.path == lastRead.chapterUrl);
      if (from >= 0) chapters = chapters.sublist(from + 1);
    }
    chapters = chapters.where((c) => !(progress[c.path]?.done ?? false)).toList();
    if (limit != null) chapters = chapters.take(limit).toList();
    _enqueue(novel, chapters);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${chapters.length} bab masuk antrean unduhan')));
  }

  void _enqueue(NovelDetails novel, Iterable<NovelChapter> chapters) {
    ref.read(downloadQueueProvider.notifier).enqueue(
      sourceId: novelLibraryId(widget.pluginId),
      mangaUrl: widget.path,
      manga: SourceMangaDetails(url: widget.path, title: novel.name, thumbnailUrl: novel.cover),
      chapters: [for (final c in chapters) SourceChapter(url: c.path, name: c.name)],
    );
  }

  void _openTracking(NovelDetails novel) {
    final progress = ref.read(sourceSeriesProgressProvider(_libKey));
    int? local;
    for (final c in _visible) {
      if (!(progress[c.path]?.done ?? false)) continue;
      final n = c.number ?? parseChapterNumber(c.name);
      if (n != null && (local == null || n > local)) local = n.floor();
    }
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => TrackingSheet(
        seriesKey: '${novelLibraryId(widget.pluginId)}|${widget.path}',
        title: novel.name,
        novel: true,
        localProgress: local,
      ),
    );
  }

  Future<void> _openWeb(NovelSource source) async {
    final url = await source.webUrl(widget.path, isNovel: true);
    if (!mounted) return;
    final ok = await context.push<bool>(sourceWebViewLocation(url, storagePluginId: source.webStorageUtilized ? source.id : null));
    if (ok == true) ref.invalidate(novelDetailsProvider(_key));
  }

  Future<void> _share(NovelSource source, NovelDetails novel) async {
    String? web;
    try {
      web = await source.webUrl(widget.path, isNovel: true);
    } catch (_) {
      web = null;
    }
    await DeepLinks.share(
      title: novel.name,
      webUrl: web,
      location: novelDetailLocation(widget.pluginId, widget.path),
    );
  }

  Future<void> _deleteLocal(NovelDetails novel) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus "${novel.name}"?'),
        content: const Text('File EPUB di perangkat ikut dihapus dan tidak bisa dikembalikan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await LocalNovelSource.delete(widget.path);
    if (ref.read(isSourceFavoriteProvider(_libKey))) _toggleFavorite(novel);
    ref.invalidate(novelListProvider);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(novelSourceProvider(widget.pluginId)).valueOrNull;
    final details = ref.watch(novelDetailsProvider(_key));
    final isFavorite = ref.watch(isSourceFavoriteProvider(_libKey));
    final lastRead = ref.watch(sourceLastReadProvider(_libKey));
    final loaded = details.valueOrNull;
    if (loaded != null) _syncFavorite(loaded);

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: Scaffold(
        appBar: _selecting
            ? _selectionBar(loaded)
            : AppBar(
                title: Text(loaded?.name ?? source?.name ?? ''),
                actions: [
                  if (loaded != null)
                    IconButton(
                      tooltip: isFavorite ? 'Hapus dari favorit' : 'Tambah ke favorit',
                      icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                      color: isFavorite ? Theme.of(context).colorScheme.primary : null,
                      onPressed: () => _toggleFavorite(loaded),
                    ),
                  if (loaded != null && source is! LocalNovelSource)
                    PopupMenuButton<int>(
                      tooltip: 'Unduh',
                      icon: const Icon(Icons.download_outlined),
                      onSelected: (limit) => _downloadMany(loaded, limit: limit == 0 ? null : limit),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 5, child: Text('Unduh 5 bab berikutnya')),
                        const PopupMenuItem(value: 10, child: Text('Unduh 10 bab berikutnya')),
                        PopupMenuItem(
                          value: 0,
                          child: Text(loaded.totalPages > 1
                              ? 'Unduh yang belum dibaca (halaman ini)'
                              : 'Unduh semua yang belum dibaca'),
                        ),
                      ],
                    ),
                  IconButton(
                    tooltip: _newestFirst ? 'Urutkan bab pertama dulu' : 'Urutkan bab terbaru dulu',
                    icon: Icon(_newestFirst ? Icons.arrow_upward : Icons.arrow_downward),
                    onPressed: () => setState(() => _newestFirst = !_newestFirst),
                  ),
                  if (source != null)
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'web') _openWeb(source);
                        if (v == 'delete' && loaded != null) _deleteLocal(loaded);
                        if (v == 'share' && loaded != null) _share(source, loaded);
                        if (v == 'export' && loaded != null) {
                          exportNovelEpub(context, ref, pluginId: widget.pluginId, path: widget.path, details: loaded);
                        }
                        if (v == 'track' && loaded != null) _openTracking(loaded);
                        if (v == 'migrate' && loaded != null) {
                          context.push(migrateLocation(novelLibraryId(widget.pluginId), widget.path, loaded.name));
                        }
                      },
                      itemBuilder: (_) => [
                        if (source is! LocalNovelSource) const PopupMenuItem(value: 'share', child: Text('Bagikan')),
                        if (source is! LocalNovelSource) const PopupMenuItem(value: 'web', child: Text('Buka di WebView')),
                        const PopupMenuItem(value: 'track', child: Text('Tracking')),
                        const PopupMenuItem(value: 'migrate', child: Text('Pindah sumber')),
                        if (source is! LocalNovelSource)
                          const PopupMenuItem(value: 'export', child: Text('Ekspor ke EPUB')),
                        if (source is LocalNovelSource)
                          const PopupMenuItem(value: 'delete', child: Text('Hapus dari perangkat')),
                      ],
                    ),
                ],
              ),
        body: details.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => SourceErrorView(
            error: novelError(error, site: source?.site),
            onRetry: () => ref.invalidate(novelDetailsProvider(_key)),
            verifyUrl: source?.site,
          ),
          data: (novel) => RefreshIndicator(
            onRefresh: () => ref.refresh(novelDetailsProvider(_key).future),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _header(context, novel, source)),
                if (novel.totalPages > 1) SliverToBoxAdapter(child: _pagePicker(novel.totalPages)),
                _chapterList(novel, lastRead?.chapterUrl),
                const SliverToBoxAdapter(child: SizedBox(height: 88)),
              ],
            ),
          ),
        ),
        floatingActionButton: _selecting ? null : _fab(loaded, lastRead),
      ),
    );
  }

  Widget? _fab(NovelDetails? novel, SourceHistoryEntry? lastRead) {
    if (novel == null) return null;
    if (lastRead != null) {
      return FloatingActionButton.extended(
        onPressed: () => _open(
          NovelChapter(path: lastRead.chapterUrl, name: lastRead.chapterName),
          page: novelLastPage(ref, widget.pluginId, widget.path),
        ),
        icon: const Icon(Icons.play_arrow),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text('Lanjutkan · ${lastRead.chapterName}', overflow: TextOverflow.ellipsis),
        ),
      );
    }
    if (novel.chapters.isEmpty) return null;
    return FloatingActionButton.extended(
      onPressed: () {
        // Mulai dari bab pertama yang belum ditandai dibaca.
        final progress = ref.read(sourceSeriesProgressProvider(_libKey));
        final next = novel.chapters.firstWhere(
          (c) => !(progress[c.path]?.done ?? false),
          orElse: () => novel.chapters.first,
        );
        _open(next, page: 1);
      },
      icon: const Icon(Icons.play_arrow),
      label: const Text('Mulai baca'),
    );
  }

  Widget _pagePicker(int total) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(
          children: [
            IconButton(
              onPressed: _page > 1 ? () => setState(() => _page--) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: DropdownButton<int>(
                isExpanded: true,
                value: _page.clamp(1, total),
                items: [
                  for (var p = 1; p <= total; p++)
                    DropdownMenuItem(value: p, child: Text('Halaman bab $p dari $total')),
                ],
                onChanged: (p) => setState(() => _page = p ?? 1),
              ),
            ),
            IconButton(
              onPressed: _page < total ? () => setState(() => _page++) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      );

  Widget _chapterList(NovelDetails novel, String? lastReadPath) {
    final page = novel.totalPages > 1 ? _page.clamp(1, novel.totalPages) : 1;
    final paged = ref.read(loadedNovelSourceProvider(widget.pluginId))?.hasParsePage ?? false;
    final chaptersAsync = novel.totalPages > 1 || (novel.chapters.isEmpty && paged)
        ? ref.watch(novelChapterPageProvider((pluginId: widget.pluginId, path: widget.path, page: page)))
        : AsyncData(novel.chapters);
    final progress = ref.watch(sourceSeriesProgressProvider(_libKey));

    return chaptersAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: SourceErrorView(
          compact: true,
          error: novelError(e),
          onRetry: () =>
              ref.invalidate(novelChapterPageProvider((pluginId: widget.pluginId, path: widget.path, page: page))),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const SliverToBoxAdapter(child: EmptyView(compact: true, title: 'Belum ada bab'));
        }
        _visible = list;
        final chapters = _newestFirst ? list.reversed.toList() : list;
        return SliverList.separated(
          itemCount: chapters.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final c = chapters[i];
            final isLast = c.path == lastReadPath;
            final p = progress[c.path];
            final done = p?.done ?? false;
            final fade = done && !isLast;
            final subtitle = [
              if (c.releaseTime != null) _shortDate(c.releaseTime!),
              if (p != null && !done && p.page > 0) '${p.page}% dibaca',
            ].join(' · ');
            final selected = _selected.contains(c.path);
            return ListTile(
              selected: selected,
              selectedTileColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              leading: _selecting
                  ? Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked, size: 22)
                  : isLast
                      ? const Icon(Icons.bookmark, size: 20)
                      : null,
              title: Text(
                c.name,
                style: TextStyle(
                  fontWeight: isLast ? FontWeight.w700 : null,
                  color: fade ? Theme.of(context).disabledColor : null,
                ),
              ),
              subtitle: subtitle.isEmpty ? null : Text(subtitle),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (done) const Icon(Icons.done_all, size: 18),
                  if (widget.pluginId != LocalNovelSource.pluginId)
                  _NovelChapterDownloadButton(
                    chapterKey: chapterKey(novelLibraryId(widget.pluginId), c.path),
                    onDownload: () => _enqueue(novel, [c]),
                  ),
                ],
              ),
              onTap: () => _selecting ? _toggleSelect(c.path) : _open(c, page: page),
              onLongPress: () => _toggleSelect(c.path),
            );
          },
        );
      },
    );
  }

  static String _shortDate(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }

  Widget _header(BuildContext context, NovelDetails novel, NovelSource? source) {
    final theme = Theme.of(context);
    final meta = [
      if (novel.author != null) novel.author!,
      if (novel.artist != null && novel.artist != novel.author) novel.artist!,
      if (novel.status != null) novel.status!,
      if (novel.rating != null) '★ ${novel.rating!.toStringAsFixed(1)}',
      if (novel.totalPages <= 1) '${novel.chapters.length} bab',
    ].join(' · ');
    final summary = novel.summary == null
        ? null
        : html_parser.parseFragment(novel.summary!).text?.trim().replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SourceCover(url: novel.cover, headers: source?.imageHeaders ?? const {}, width: 110),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(novel.name, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(meta, style: theme.textTheme.bodySmall),
                    if (source != null) ...[
                      const SizedBox(height: 4),
                      Text(source.name, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (novel.genres.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final g in novel.genres) Chip(label: Text(g), visualDensity: VisualDensity.compact)],
            ),
          ],
          if (summary != null && summary.isNotEmpty) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => setState(() => _descExpanded = !_descExpanded),
              child: Text(
                summary,
                maxLines: _descExpanded ? null : 5,
                overflow: _descExpanded ? null : TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Status unduhan satu bab novel: unduh / antre / terunduh (ketuk untuk hapus).
class _NovelChapterDownloadButton extends ConsumerWidget {
  const _NovelChapterDownloadButton({required this.chapterKey, required this.onDownload});

  final String chapterKey;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloaded = ref.watch(downloadIndexProvider.select((i) => i.containsKey(chapterKey)));
    final task = ref.watch(downloadTaskProvider(chapterKey));
    final queue = ref.read(downloadQueueProvider.notifier);
    if (downloaded) {
      return IconButton(
        tooltip: 'Hapus unduhan',
        icon: Icon(Icons.offline_pin, color: Theme.of(context).colorScheme.primary),
        onPressed: () => ref.read(downloadIndexProvider.notifier).remove(chapterKey),
      );
    }
    return switch (task?.status) {
      DownloadStatus.queued || DownloadStatus.downloading => IconButton(
          tooltip: 'Batalkan unduhan',
          onPressed: () => queue.cancel(chapterKey),
          icon: const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
        ),
      DownloadStatus.failed => IconButton(
          tooltip: 'Gagal: ${task!.error ?? ''}. Coba lagi',
          icon: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          onPressed: () => queue.retry(chapterKey),
        ),
      null => IconButton(
          tooltip: 'Unduh',
          icon: const Icon(Icons.download_for_offline_outlined),
          onPressed: onDownload,
        ),
    };
  }
}
