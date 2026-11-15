import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/i18n/strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/local/cbz_export.dart';
import '../../../data/models/download.dart';
import '../../../state/download_providers.dart';
import '../../widgets/library_routing.dart';
import '../../widgets/state_views.dart';

/// Antrean unduhan + daftar bab yang tersimpan offline, dikelompokkan per seri.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(downloadQueueProvider);
    final index = ref.watch(downloadIndexProvider);
    final theme = Theme.of(context);

    // Kelompokkan bab terunduh per seri, seri terbaru diunduh di atas.
    final bySeries = <String, List<DownloadedChapter>>{};
    for (final c in index.values) {
      bySeries.putIfAbsent(c.mangaKey, () => []).add(c);
    }
    final series = bySeries.values.toList()
      ..sort((a, b) => _latest(b).compareTo(_latest(a)));

    if (queue.isEmpty && series.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('Unduhan'))),
        body: EmptyView(
          icon: Icons.download_outlined,
          title: tr('Belum ada unduhan'),
          message: tr('Ketuk ikon unduh di daftar bab untuk menyimpan bab agar bisa dibaca offline.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('Unduhan'))),
      body: ListView(
        children: [
          if (queue.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(trp('Antrean ({n})', {'n': queue.length}), style: theme.textTheme.titleSmall),
            ),
            for (final task in queue)
              ListTile(
                title: Text(task.mangaTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(switch (task.status) {
                      DownloadStatus.queued => '${task.chapter.name} · ${tr('menunggu')}',
                      DownloadStatus.downloading => '${task.chapter.name} · ${task.done}/${task.total}',
                      DownloadStatus.failed => '${task.chapter.name} · ${trp('gagal: {err}', {'err': task.error ?? ''})}',
                    }),
                    if (task.status == DownloadStatus.downloading) ...[
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: task.progress),
                    ],
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (task.status == DownloadStatus.failed)
                      IconButton(
                        tooltip: tr('Coba lagi'),
                        icon: const Icon(Icons.refresh),
                        onPressed: () => ref.read(downloadQueueProvider.notifier).retry(task.key),
                      ),
                    IconButton(
                      tooltip: tr('Batalkan'),
                      icon: const Icon(Icons.close),
                      onPressed: () => ref.read(downloadQueueProvider.notifier).cancel(task.key),
                    ),
                  ],
                ),
              ),
            const Divider(),
          ],
          for (final chapters in series) _SeriesDownloads(chapters: chapters),
        ],
      ),
    );
  }

  static DateTime _latest(List<DownloadedChapter> list) =>
      list.map((c) => c.downloadedAt).reduce((a, b) => a.isAfter(b) ? a : b);
}

class _SeriesDownloads extends ConsumerWidget {
  const _SeriesDownloads({required this.chapters});

  final List<DownloadedChapter> chapters;

  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
    final first = chapters.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(trp('Hapus {n} bab "{title}"?', {'n': chapters.length, 'title': first.mangaTitle})),
        content: Text(tr('File unduhan akan dihapus dari perangkat.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Batal'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Hapus'))),
        ],
      ),
    );
    if (ok != true) return;
    for (final c in chapters) {
      await ref.read(downloadIndexProvider.notifier).remove(c.key);
    }
  }

  void _snack(BuildContext context, String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _exportChapter(BuildContext context, WidgetRef ref, DownloadedChapter c) async {
    _snack(context, tr('Membuat CBZ…'));
    try {
      final bytes = await CbzExport.forChapter(ref.read(downloadStoreProvider), c);
      if (bytes == null) {
        if (context.mounted) _snack(context, tr('File unduhan tidak lengkap'));
        return;
      }
      final saved = await FilePicker.saveFile(
        fileName: CbzExport.fileName(c),
        bytes: bytes,
        mimeType: 'application/vnd.comicbook+zip',
        dialogTitle: tr('Simpan CBZ'),
      );
      if (context.mounted) _snack(context, saved == null ? tr('Dibatalkan') : '${tr('CBZ disimpan')}: ${CbzExport.fileName(c)}');
    } catch (e) {
      if (context.mounted) _snack(context, '${tr('Gagal membuat CBZ')}: $e');
    }
  }

  Future<void> _exportSeries(BuildContext context, WidgetRef ref, List<DownloadedChapter> list) async {
    final dir = await FilePicker.getDirectoryPath(dialogTitle: tr('Pilih folder untuk CBZ'));
    if (dir == null || !context.mounted) return;
    var ok = 0;
    var failed = 0;
    final store = ref.read(downloadStoreProvider);
    for (var i = 0; i < list.length; i++) {
      if (!context.mounted) return;
      _snack(context, '${tr('Membuat CBZ')} ${i + 1}/${list.length}…');
      try {
        final bytes = await CbzExport.forChapter(store, list[i]);
        if (bytes == null) {
          failed++;
          continue;
        }
        await File('$dir${Platform.pathSeparator}${CbzExport.fileName(list[i])}').writeAsBytes(bytes);
        ok++;
      } catch (_) {
        failed++;
      }
    }
    if (context.mounted) {
      _snack(context, '$ok CBZ ${tr('disimpan')}${failed == 0 ? '' : ', $failed ${tr('gagal')}'}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = chapters.first;
    final info = librarySourceInfo(ref, first.sourceId);
    final sorted = [...chapters]..sort((a, b) => a.chapterName.compareTo(b.chapterName));

    return ExpansionTile(
      title: Text(first.mangaTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${trp('{n} bab', {'n': chapters.length})} · ${info.name}${info.isNovel ? ' · novel' : ''}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!info.isNovel)
            IconButton(
              tooltip: tr('Ekspor semua bab ke CBZ'),
              icon: const Icon(Icons.archive_outlined),
              onPressed: () => _exportSeries(context, ref, sorted),
            ),
          IconButton(
            tooltip: tr('Hapus semua bab seri ini'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDeleteAll(context, ref),
          ),
          const Icon(Icons.expand_more),
        ],
      ),
      children: [
        for (final c in sorted)
          ListTile(
            dense: true,
            leading: const Icon(Icons.offline_pin, size: 20),
            title: Text(c.chapterName),
            subtitle: info.isNovel ? null : Text(trp('{n} halaman', {'n': c.files.length})),
            onTap: () => context.push(info.readerLocation(c.mangaUrl, c.chapterUrl)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!info.isNovel)
                  IconButton(
                    tooltip: tr('Ekspor ke CBZ'),
                    icon: const Icon(Icons.archive_outlined),
                    onPressed: () => _exportChapter(context, ref, c),
                  ),
                IconButton(
                  tooltip: tr('Hapus'),
                  icon: const Icon(Icons.close),
                  onPressed: () => ref.read(downloadIndexProvider.notifier).remove(c.key),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
