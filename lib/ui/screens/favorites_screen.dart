import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../state/library_providers.dart';
import '../router.dart';
import '../widgets/series_card.dart';
import '../widgets/state_views.dart';

/// Favorit lokal. Tidak memanggil API, jadi selalu tersedia walau offline.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Favorit')),
      body: favorites.isEmpty
          ? const EmptyView(
              icon: Icons.favorite_outline,
              title: 'Belum ada favorit',
              message: 'Ketuk ikon hati di halaman detail untuk menyimpan seri ke sini.',
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 140,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.52,
              ),
              itemCount: favorites.length,
              itemBuilder: (context, i) {
                final entry = favorites[i];
                final item = entry.item;
                return SeriesCard(
                  title: item.title,
                  coverUrl: item.coverUrl,
                  subtitle: '${item.type.label} · ${statusLabel(item.status)}',
                  onTap: () => context.push(seriesLocation(item.type, item.id)),
                  onLongPress: () {
                    ref.read(favoritesProvider.notifier).remove(item.key);
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                        content: Text('"${item.title}" dihapus dari favorit'),
                        action: SnackBarAction(
                          label: 'Urungkan',
                          onPressed: () => ref.read(favoritesProvider.notifier).restore(entry),
                        ),
                      ));
                  },
                );
              },
            ),
    );
  }
}
