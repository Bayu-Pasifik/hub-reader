import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
        appBar: AppBar(title: const Text('Unduhan')),
        body: const EmptyView(
          icon: Icons.download_outlined,
          title: 'Belum ada unduhan',
          message: 'Ketuk ikon unduh di daftar bab untuk menyimpan bab agar bisa dibaca offline.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Unduhan')),
      body: ListView(
        children: [
          if (queue.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Antrean (${queue.length})', style: theme.textTheme.titleSmall),
            ),
            for (final task in queue)
              ListTile(
                title: Text(task.mangaTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(switch (task.status) {
                      DownloadStatus.queued => '${task.chapter.name} · menunggu',
                      DownloadStatus.downloading => '${task.chapter.name} · ${task.done}/${task.total}',
                      DownloadStatus.failed => '${task.chapter.name} · gagal: ${task.error ?? ''}',
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
                        tooltip: 'Coba lagi',
                        icon: const Icon(Icons.refresh),
                        onPressed: () => ref.read(downloadQueueProvider.notifier).retry(task.key),
                      ),
                    IconButton(
                      tooltip: 'Batalkan',
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
        title: Text('Hapus ${chapters.length} bab "${first.mangaTitle}"?'),
        content: const Text('File unduhan akan dihapus dari perangkat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    for (final c in chapters) {
      await ref.read(downloadIndexProvider.notifier).remove(c.key);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = chapters.first;
    final info = librarySourceInfo(ref, first.sourceId);
    final sorted = [...chapters]..sort((a, b) => a.chapterName.compareTo(b.chapterName));

    return ExpansionTile(
      title: Text(first.mangaTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${chapters.length} bab · ${info.name}${info.isNovel ? ' · novel' : ''}'),
      trailing: IconButton(
        tooltip: 'Hapus semua bab seri ini',
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _confirmDeleteAll(context, ref),
      ),
      children: [
        for (final c in sorted)
          ListTile(
            dense: true,
            leading: const Icon(Icons.offline_pin, size: 20),
            title: Text(c.chapterName),
            subtitle: info.isNovel ? null : Text('${c.files.length} halaman'),
            onTap: () => context.push(info.readerLocation(c.mangaUrl, c.chapterUrl)),
            trailing: IconButton(
              tooltip: 'Hapus',
              icon: const Icon(Icons.close),
              onPressed: () => ref.read(downloadIndexProvider.notifier).remove(c.key),
            ),
          ),
      ],
    );
  }
}
