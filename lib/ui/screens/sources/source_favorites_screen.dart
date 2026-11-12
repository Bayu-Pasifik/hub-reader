import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../state/source_library_providers.dart';
import '../../widgets/library_routing.dart';
import '../../widgets/source_widgets.dart';
import '../../widgets/state_views.dart';

/// Favorit seri dari sumber on-device. Disimpan lokal, selalu tersedia.
class SourceFavoritesScreen extends ConsumerWidget {
  const SourceFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(sourceFavoritesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Favorit')),
      body: favorites.isEmpty
          ? const EmptyView(
              icon: Icons.favorite_outline,
              title: 'Belum ada favorit',
              message: 'Ketuk ikon hati di halaman detail seri untuk menyimpannya ke sini.',
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.5,
              ),
              itemCount: favorites.length,
              itemBuilder: (context, i) {
                final entry = favorites[i];
                final item = entry.item;
                final source = librarySourceInfo(ref, item.sourceId);
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => context.push(source.detailLocation(item.url)),
                  onLongPress: () {
                    ref.read(sourceFavoritesProvider.notifier).remove(item.key);
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                        content: Text('"${item.title}" dihapus dari favorit'),
                        action: SnackBarAction(
                          label: 'Urungkan',
                          onPressed: () => ref.read(sourceFavoritesProvider.notifier).restore(entry),
                        ),
                      ));
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SourceCover(
                        url: item.thumbnailUrl,
                        headers: source.imageHeaders,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        source.isNovel ? 'Novel · ${source.name}' : source.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
