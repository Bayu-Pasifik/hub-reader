import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/home_sections.dart';
import '../../state/catalog_providers.dart';
import '../../state/library_providers.dart';
import '../router.dart';
import '../widgets/series_card.dart';
import '../widgets/state_views.dart';

/// Beranda: section dari GET /home + "Lanjutkan membaca" dari riwayat lokal.
/// Riwayat lokal tetap tampil walau server mati.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final history = ref.watch(historyProvider);

    Future<void> refresh() async {
      try {
        ref.invalidate(homeProvider);
        await ref.read(homeProvider.future);
      } catch (_) {
        // Error sudah ditampilkan oleh home.when(error: ...).
      }
    }

    final continueReading = history.isEmpty
        ? null
        : _HorizontalSection(
            title: 'Lanjutkan membaca',
            itemCount: history.length > 10 ? 10 : history.length,
            itemBuilder: (context, i) {
              final entry = history[i];
              return SeriesCard(
                width: 110,
                title: entry.item.title,
                coverUrl: entry.item.coverUrl,
                subtitle: 'Bab ${formatChapterNumber(entry.chapterNumber)}',
                onTap: () => context.push(
                  readerLocation(entry.item.type, entry.item.id, entry.chapterNumber),
                ),
              );
            },
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hub Reader'),
        actions: [
          IconButton(
            tooltip: 'Cari',
            icon: const Icon(Icons.search),
            onPressed: () => context.go('/browse'),
          ),
          IconButton(
            tooltip: 'Pengaturan',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: home.when(
          skipLoadingOnRefresh: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (continueReading != null) continueReading,
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: ErrorView(error: error, onRetry: () => ref.invalidate(homeProvider)),
              ),
            ],
          ),
          data: (fetched) {
            final sections = fetched.data.sections;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (fetched.cachedAt != null) OfflineBanner(cachedAt: fetched.cachedAt!),
                if (continueReading != null) continueReading,
                if (fetched.data.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: EmptyView(
                      icon: Icons.auto_stories_outlined,
                      title: 'Belum ada konten',
                      message: 'Server belum memiliki data hasil scraping. '
                          'Jalankan "php artisan scrape:run" di scraper-hub lalu tarik untuk memuat ulang.',
                    ),
                  ),
                for (final section in sections) _SeriesSection(section: section),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SeriesSection extends StatelessWidget {
  const _SeriesSection({required this.section});

  final HomeSection section;

  @override
  Widget build(BuildContext context) => _HorizontalSection(
        title: section.title,
        itemCount: section.items.length,
        itemBuilder: (context, i) {
          final series = section.items[i];
          return SeriesCard(
            width: 110,
            title: series.title,
            coverUrl: series.coverUrl,
            subtitle: '${series.chapterCount} bab · ${statusLabel(series.status)}',
            onTap: () => context.push(seriesLocation(series.type, series.id)),
          );
        },
      );
}

class _HorizontalSection extends StatelessWidget {
  const _HorizontalSection({
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
  });

  final String title;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        SizedBox(
          // Sampul 110×146.7 + 2 baris judul + 1 baris subjudul.
          height: 226,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: itemCount,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: itemBuilder,
          ),
        ),
      ],
    );
  }
}
