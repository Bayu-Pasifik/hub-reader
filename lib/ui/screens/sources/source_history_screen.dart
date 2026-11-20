import '../../haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../state/app_settings_provider.dart';
import '../../../data/models/source_library.dart';
import '../../../state/source_library_providers.dart';
import '../../widgets/library_routing.dart';
import '../../widgets/source_widgets.dart';
import '../../widgets/state_views.dart';
import '../../../core/i18n/strings.dart';

/// Riwayat baca: bab terakhir yang dibuka per seri.
class SourceHistoryScreen extends ConsumerWidget {
  const SourceHistoryScreen({super.key});

  /// Hapus lalu tawarkan "Urungkan" (tanpa dialog konfirmasi).
  void _removeWithUndo(BuildContext context, WidgetRef ref, List<SourceHistoryEntry> removed, String message,
      Future<void> Function() action) {
    final notifier = ref.read(sourceHistoryProvider.notifier);
    Haptics.thud();
    action();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        persist: false,
        action: SnackBarAction(
          label: tr('Urungkan'),
          onPressed: () {
            Haptics.tap();
            notifier.restore(removed);
          },
        ),
      ));
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
            tooltip: incognito ? tr('Matikan mode samaran') : tr('Mode samaran'),
            icon: Icon(incognito ? Icons.visibility_off : Icons.visibility_off_outlined),
            color: incognito ? Theme.of(context).colorScheme.primary : null,
            onPressed: () {
              ref.read(appSettingsProvider.notifier).update((s) => s.copyWith(incognito: !incognito));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text(incognito ? tr('Mode samaran mati') : tr('Mode samaran: riwayat & posisi baca tidak dicatat')),
                ));
            },
          ),
          if (history.isNotEmpty)
            IconButton(
              tooltip: tr('Hapus semua'),
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _removeWithUndo(
                context,
                ref,
                history,
                tr('Riwayat dihapus'),
                ref.read(sourceHistoryProvider.notifier).clear,
              ),
            ),
        ],
      ),
      body: history.isEmpty
          ? EmptyView(
              animation: AppAnimation.noHistory,
              icon: Icons.history,
              title: tr('Belum ada riwayat'),
              message: tr('Bab yang kamu buka akan muncul di sini.'),
            )
          : ListView.separated(
              itemCount: history.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final entry = history[i];
                final item = entry.item;
                final source = librarySourceInfo(ref, item.sourceId);
                return Dismissible(
                  key: ValueKey(item.key),
                  background: ColoredBox(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Icon(Icons.delete_outline)),
                    ),
                  ),
                  secondaryBackground: ColoredBox(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: const Align(
                      alignment: Alignment.centerRight,
                      child: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Icon(Icons.delete_outline)),
                    ),
                  ),
                  onDismissed: (_) => _removeWithUndo(
                    context,
                    ref,
                    [entry],
                    trp('"{title}" dihapus dari riwayat', {'title': item.title}),
                    () => ref.read(sourceHistoryProvider.notifier).remove(item.key),
                  ),
                  child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: SourceCover(
                    url: item.thumbnailUrl,
                    headers: source.imageHeaders,
                    width: 44,
                  ),
                  title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${entry.chapterName} · ${source.isNovel ? '${tr('Novel')} · ' : ''}${source.name} · ${relativeTime(entry.readAt)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Ketuk = lanjut baca; tekan lama = buka detail seri.
                  onTap: () => context.push(source.readerLocation(item.url, entry.chapterUrl)),
                  onLongPress: () => context.push(source.detailLocation(item.url)),
                  trailing: IconButton(
                    tooltip: tr('Hapus dari riwayat'),
                    icon: const Icon(Icons.close),
                    onPressed: () => _removeWithUndo(
                      context,
                      ref,
                      [entry],
                      trp('"{title}" dihapus dari riwayat', {'title': item.title}),
                      () => ref.read(sourceHistoryProvider.notifier).remove(item.key),
                    ),
                  ),
                  ),
                );
              },
            ),
    );
  }
}
