import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/chapter.dart';
import '../../data/models/library_item.dart';
import '../../data/models/series.dart';
import '../../state/catalog_providers.dart';
import '../../state/library_providers.dart';
import '../router.dart';
import '../widgets/cover_image.dart';
import '../widgets/state_views.dart';

/// Detail seri (GET /{type}/{id}) + daftar bab (GET /{type}/{id}/chapters).
class SeriesDetailScreen extends ConsumerStatefulWidget {
  const SeriesDetailScreen({super.key, required this.type, required this.id});

  final SeriesType type;
  final int id;

  @override
  ConsumerState<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends ConsumerState<SeriesDetailScreen> {
  /// Default: bab terbaru di atas, seperti Aniyomi.
  bool _newestFirst = true;

  SeriesRef get _ref => (type: widget.type, id: widget.id);

  Future<void> _refresh() async {
    ref.invalidate(chaptersProvider(_ref));
    try {
      ref.invalidate(seriesDetailProvider(_ref));
      await ref.read(seriesDetailProvider(_ref).future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(seriesDetailProvider(_ref));
    final isFavorite = ref.watch(isFavoriteProvider(_ref));
    final series = detail.valueOrNull?.data;

    // Sinkronkan judul/sampul favorit dengan data terbaru server.
    ref.listen(seriesDetailProvider(_ref), (_, next) {
      final data = next.valueOrNull;
      if (data != null && !data.isFromCache) {
        ref.read(favoritesProvider.notifier).refreshItem(LibraryItem.fromSeries(data.data));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(series?.title ?? widget.type.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: isFavorite ? 'Hapus dari favorit' : 'Tambah ke favorit',
            onPressed: series == null
                ? null
                : () {
                    ref.read(favoritesProvider.notifier).toggle(LibraryItem.fromSeries(series));
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                        content: Text(isFavorite ? 'Dihapus dari favorit' : 'Ditambahkan ke favorit'),
                        duration: const Duration(seconds: 2),
                      ));
                  },
            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(seriesDetailProvider(_ref)),
        ),
        data: (fetched) => RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              if (fetched.cachedAt != null)
                SliverToBoxAdapter(child: OfflineBanner(cachedAt: fetched.cachedAt!)),
              SliverToBoxAdapter(child: _Header(series: fetched.data)),
              SliverToBoxAdapter(child: _ReadButton(series: fetched.data)),
              SliverToBoxAdapter(child: _Info(series: fetched.data)),
              ..._chapterSlivers(fetched.data),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _chapterSlivers(Series series) {
    final chapters = ref.watch(chaptersProvider(_ref));
    final lastRead = ref.watch(lastReadProvider(_ref));

    final header = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${chapters.valueOrNull?.data.length ?? series.chapterCount} bab',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _newestFirst = !_newestFirst),
              icon: Icon(_newestFirst ? Icons.arrow_downward : Icons.arrow_upward, size: 18),
              label: Text(_newestFirst ? 'Terbaru' : 'Terlama'),
            ),
          ],
        ),
      ),
    );

    final body = chapters.when<Widget>(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => SliverToBoxAdapter(
        child: ErrorView(
          error: error,
          compact: true,
          onRetry: () => ref.invalidate(chaptersProvider(_ref)),
        ),
      ),
      data: (fetched) {
        final list = _newestFirst ? fetched.data.reversed.toList() : fetched.data;
        if (list.isEmpty) {
          return const SliverToBoxAdapter(
            child: EmptyView(
              compact: true,
              icon: Icons.menu_book_outlined,
              title: 'Belum ada bab',
              message: 'Scraper belum menemukan bab untuk seri ini.',
            ),
          );
        }
        return SliverList.builder(
          itemCount: list.length,
          itemBuilder: (context, i) => _ChapterTile(
            chapter: list[i],
            isLastRead: lastRead != null && list[i].isNumber(lastRead.chapterNumber),
            onTap: () => context.push(readerLocation(series.type, series.id, list[i].number)),
          ),
        );
      },
    );

    return [header, body];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.series});

  final Series series;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoverImage(url: series.coverUrl, width: 120),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(series.title, style: textTheme.titleLarge),
                const SizedBox(height: 6),
                if (series.author != null)
                  Text(series.author!, style: textTheme.bodyMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Pill(icon: Icons.schedule, text: statusLabel(series.status)),
                    _Pill(icon: Icons.menu_book_outlined, text: series.type.label),
                    if (series.source != null) _Pill(icon: Icons.public, text: series.source!),
                  ],
                ),
                if (series.scrapedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Diperbarui ${relativeTime(series.scrapedAt!)}',
                    style: textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: scheme.onSecondaryContainer)),
        ],
      ),
    );
  }
}

/// "Lanjutkan Bab X" bila ada riwayat, atau "Mulai membaca" dari bab pertama.
class _ReadButton extends ConsumerWidget {
  const _ReadButton({required this.series});

  final Series series;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = (type: series.type, id: series.id);
    final lastRead = ref.watch(lastReadProvider(r));
    final chapters = ref.watch(chaptersProvider(r)).valueOrNull?.data;

    final double? target = lastRead?.chapterNumber ??
        (chapters != null && chapters.isNotEmpty ? chapters.first.number : null);
    final label = lastRead != null
        ? 'Lanjutkan Bab ${formatChapterNumber(lastRead.chapterNumber)}'
        : 'Mulai membaca';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: target == null
              ? null
              : () => context.push(readerLocation(series.type, series.id, target)),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(label),
        ),
      ),
    );
  }
}

class _Info extends StatefulWidget {
  const _Info({required this.series});

  final Series series;

  @override
  State<_Info> createState() => _InfoState();
}

class _InfoState extends State<_Info> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final series = widget.series;
    final description = series.description == null ? null : stripHtml(series.description!);
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description != null && description.isNotEmpty) ...[
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    maxLines: _expanded ? null : 4,
                    overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: textTheme.bodyMedium,
                  ),
                  Text(
                    _expanded ? 'Sembunyikan' : 'Selengkapnya',
                    style: textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Text('Tidak ada deskripsi.', style: textTheme.bodyMedium),
          if (series.genres.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final genre in series.genres)
                  Chip(label: Text(genre), visualDensity: VisualDensity.compact),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({required this.chapter, required this.isLastRead, required this.onTap});

  final Chapter chapter;
  final bool isLastRead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitleParts = [
      if (chapter.title != null && chapter.title != chapter.label) chapter.title!,
      if (chapter.publishedAt != null) relativeTime(chapter.publishedAt!),
    ];
    return ListTile(
      onTap: onTap,
      leading: isLastRead ? Icon(Icons.bookmark, color: scheme.primary) : null,
      title: Text(
        chapter.label,
        style: TextStyle(
          fontWeight: isLastRead ? FontWeight.bold : FontWeight.normal,
          color: isLastRead ? scheme.primary : null,
        ),
      ),
      subtitle: subtitleParts.isEmpty
          ? null
          : Text(subtitleParts.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: chapter.isLocked
          ? Tooltip(
              message: 'Bab terkunci di situs sumber',
              child: Icon(Icons.lock_outline, color: scheme.outline),
            )
          : null,
    );
  }
}
