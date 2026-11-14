import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../state/app_settings_provider.dart';
import '../../../state/source_library_providers.dart';
import '../../widgets/library_routing.dart';
import '../../widgets/source_widgets.dart';
import '../../widgets/state_views.dart';
import '../../../core/i18n/strings.dart';

/// Riwayat baca: bab terakhir yang dibuka per seri.
class SourceHistoryScreen extends ConsumerWidget {
  const SourceHistoryScreen({super.key});

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Hapus semua riwayat?')),
        content: Text(tr('Riwayat baca di perangkat ini akan dihapus permanen.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Batal'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Hapus'))),
        ],
      ),
    );
    if (confirmed == true) await ref.read(sourceHistoryProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(sourceHistoryProvider);
    final incognito = ref.watch(appSettingsProvider.select((s) => s.incognito));

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Riwayat')),
        actions: [
          IconButton(
            tooltip: tr('Statistik'),
            icon: const Icon(Icons.insights_outlined),
            onPressed: () => context.push('/stats'),
          ),
          IconButton(
            tooltip: incognito ? 'Matikan mode samaran' : 'Mode samaran',
            icon: Icon(incognito ? Icons.visibility_off : Icons.visibility_off_outlined),
            color: incognito ? Theme.of(context).colorScheme.primary : null,
            onPressed: () {
              ref.read(appSettingsProvider.notifier).update((s) => s.copyWith(incognito: !incognito));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text(incognito ? 'Mode samaran mati' : 'Mode samaran: riwayat & posisi baca tidak dicatat'),
                ));
            },
          ),
          if (history.isNotEmpty)
            IconButton(
              tooltip: tr('Hapus semua'),
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
                    tooltip: tr('Hapus dari riwayat'),
                    icon: const Icon(Icons.close),
                    onPressed: () => ref.read(sourceHistoryProvider.notifier).remove(item.key),
                  ),
                );
              },
            ),
    );
  }
}
