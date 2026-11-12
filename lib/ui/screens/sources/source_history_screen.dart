import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../state/source_library_providers.dart';
import '../../widgets/library_routing.dart';
import '../../widgets/source_widgets.dart';
import '../../widgets/state_views.dart';

/// Riwayat baca: bab terakhir yang dibuka per seri.
class SourceHistoryScreen extends ConsumerWidget {
  const SourceHistoryScreen({super.key});

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus semua riwayat?'),
        content: const Text('Riwayat baca di perangkat ini akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed == true) await ref.read(sourceHistoryProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(sourceHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat'),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              tooltip: 'Hapus semua',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmClear(context, ref),
            ),
        ],
      ),
      body: history.isEmpty
          ? const EmptyView(
              icon: Icons.history,
              title: 'Belum ada riwayat',
              message: 'Bab yang kamu buka akan muncul di sini.',
            )
          : ListView.separated(
              itemCount: history.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final entry = history[i];
                final item = entry.item;
                final source = librarySourceInfo(ref, item.sourceId);
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: SourceCover(
                    url: item.thumbnailUrl,
                    headers: source.imageHeaders,
                    width: 44,
                  ),
                  title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${entry.chapterName} · ${source.isNovel ? 'Novel · ' : ''}${source.name} · ${relativeTime(entry.readAt)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Ketuk = lanjut baca; tekan lama = buka detail seri.
                  onTap: () => context.push(source.readerLocation(item.url, entry.chapterUrl)),
                  onLongPress: () => context.push(source.detailLocation(item.url)),
                  trailing: IconButton(
                    tooltip: 'Hapus dari riwayat',
                    icon: const Icon(Icons.close),
                    onPressed: () => ref.read(sourceHistoryProvider.notifier).remove(item.key),
                  ),
                );
              },
            ),
    );
  }
}
