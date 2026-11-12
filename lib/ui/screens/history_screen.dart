import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../state/library_providers.dart';
import '../router.dart';
import '../widgets/cover_image.dart';
import '../widgets/state_views.dart';

/// Riwayat baca lokal: bab terakhir yang dibuka per seri.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

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
    if (confirmed == true) await ref.read(historyProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);

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
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CoverImage(url: item.coverUrl, width: 44, borderRadius: 4),
                  title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    'Bab ${formatChapterNumber(entry.chapterNumber)} · ${relativeTime(entry.readAt)}',
                  ),
                  onTap: () => context.push(readerLocation(item.type, item.id, entry.chapterNumber)),
                  onLongPress: () => context.push(seriesLocation(item.type, item.id)),
                  trailing: IconButton(
                    tooltip: 'Hapus dari riwayat',
                    icon: const Icon(Icons.close),
                    onPressed: () => ref.read(historyProvider.notifier).remove(item.key),
                  ),
                );
              },
            ),
    );
  }
}
