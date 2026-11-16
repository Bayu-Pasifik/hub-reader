import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../state/browse_layout_provider.dart';
import '../../state/source_library_providers.dart' show LibraryDisplay, LibraryLayout;
import 'layout.dart';
import 'source_widgets.dart';

/// Satu judul di halaman jelajah, lepas dari jenisnya (komik atau novel).
class BrowseItem {
  const BrowseItem({required this.title, required this.cover, required this.onTap, this.heroTag});

  final String title;
  final String? cover;
  final VoidCallback onTap;
  final String? heroTag;
}

/// Daftar judul jelajah sebagai sliver: grid, grid ringkas, sampul saja, atau daftar.
class BrowseSliver extends StatelessWidget {
  const BrowseSliver({
    super.key,
    required this.layout,
    required this.itemCount,
    required this.itemAt,
    required this.headers,
  });

  final LibraryLayout layout;
  final int itemCount;
  final BrowseItem Function(int index) itemAt;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    if (layout.display == LibraryDisplay.list) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        sliver: SliverList.builder(
          itemCount: itemCount,
          itemBuilder: (context, i) {
            final item = itemAt(i);
            return ListTile(
              onTap: item.onTap,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: SourceCover(url: item.cover, headers: headers, width: 56, heroTag: item.heroTag),
              title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            );
          },
        ),
      );
    }

    final scale = MediaQuery.textScalerOf(context).scale(1);
    final isGrid = layout.display == LibraryDisplay.grid;
    return SliverPadding(
      padding: const EdgeInsets.all(12),
      sliver: SliverGrid.builder(
        gridDelegate: isGrid
            ? TextScaledGridDelegate(textScale: scale, columns: layout.columns)
            // Tanpa blok teks di bawah sampul: judul (bila ada) menumpuk di atas sampul 3:4.
            : TextScaledGridDelegate(
                maxCrossAxisExtent: 120,
                aspectRatio: 3 / 4,
                textBlockHeight: 0,
                columns: layout.columns,
              ),
        itemCount: itemCount,
        itemBuilder: (context, i) => _BrowseTile(item: itemAt(i), headers: headers, display: layout.display),
      ),
    );
  }
}

class _BrowseTile extends StatelessWidget {
  const _BrowseTile({required this.item, required this.headers, required this.display});

  final BrowseItem item;
  final Map<String, String> headers;
  final LibraryDisplay display;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover = SourceCover(url: item.cover, headers: headers, heroTag: item.heroTag);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: item.onTap,
      child: switch (display) {
        LibraryDisplay.grid => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              cover,
              const SizedBox(height: 6),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        LibraryDisplay.compact => Stack(
            children: [
              cover,
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 18, 6, 6),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                    ),
                  ),
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        _ => cover,
      },
    );
  }
}

/// Lembar pilihan tampilan jelajah: mode + jumlah kolom.
Future<void> showBrowseLayoutSheet(
  BuildContext context, {
  required NotifierProvider<BrowseLayoutNotifier, LibraryLayout> provider,
  required String title,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (_) => _BrowseLayoutSheet(provider: provider, title: title),
  );
}

class _BrowseLayoutSheet extends ConsumerWidget {
  const _BrowseLayoutSheet({required this.provider, required this.title});

  final NotifierProvider<BrowseLayoutNotifier, LibraryLayout> provider;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final layout = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in LibraryDisplay.values)
                  ChoiceChip(
                    label: Text(d.label),
                    selected: layout.display == d,
                    onSelected: (_) => notifier.set(display: d),
                  ),
              ],
            ),
            if (layout.display != LibraryDisplay.list) ...[
              Text(
                layout.columns == 0 ? tr('Kolom: otomatis') : '${tr('Kolom')}: ${layout.columns}',
                style: theme.textTheme.bodyMedium,
              ),
              Slider(
                value: layout.columns.toDouble(),
                min: 0,
                max: BrowseLayoutNotifier.maxColumns.toDouble(),
                divisions: BrowseLayoutNotifier.maxColumns,
                label: layout.columns == 0 ? tr('Otomatis') : '${layout.columns}',
                onChanged: (v) => notifier.set(columns: v.round()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
