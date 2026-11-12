import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../sources/models.dart';
import '../../../state/source_providers.dart';
import '../../router.dart';
import '../../widgets/source_widgets.dart';
import '../../widgets/state_views.dart';

/// Detail seri dari sumber on-device + daftar bab.
class SourceMangaScreen extends ConsumerStatefulWidget {
  const SourceMangaScreen({super.key, required this.sourceId, required this.url});

  final String sourceId;
  final String url;

  @override
  ConsumerState<SourceMangaScreen> createState() => _SourceMangaScreenState();
}

class _SourceMangaScreenState extends ConsumerState<SourceMangaScreen> {
  bool _descExpanded = false;

  /// Situs mengurutkan terbaru dulu; pengguna bisa membalik.
  bool _oldestFirst = false;

  SourceMangaKey get _key => (sourceId: widget.sourceId, url: widget.url);

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(sourceProvider(widget.sourceId));
    final details = ref.watch(sourceDetailsProvider(_key));
    final headers = source?.imageHeaders() ?? const <String, String>{};

    return Scaffold(
      appBar: AppBar(
        title: Text(details.valueOrNull?.title ?? source?.name ?? ''),
        actions: [
          IconButton(
            tooltip: _oldestFirst ? 'Urutkan terbaru dulu' : 'Urutkan terlama dulu',
            icon: Icon(_oldestFirst ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () => setState(() => _oldestFirst = !_oldestFirst),
          ),
        ],
      ),
      body: details.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => SourceErrorView(
          error: error,
          onRetry: () => ref.invalidate(sourceDetailsProvider(_key)),
        ),
        data: (manga) {
          final chapters = _oldestFirst ? manga.chapters.reversed.toList() : manga.chapters;
          return RefreshIndicator(
            onRefresh: () => ref.refresh(sourceDetailsProvider(_key).future),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _header(context, manga, headers)),
                if (chapters.isEmpty)
                  const SliverToBoxAdapter(
                    child: EmptyView(compact: true, title: 'Belum ada bab'),
                  )
                else
                  SliverList.separated(
                    itemCount: chapters.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final chapter = chapters[i];
                      return ListTile(
                        title: Text(chapter.name),
                        subtitle: chapter.uploadedAt == null
                            ? null
                            : Text(relativeTime(chapter.uploadedAt!)),
                        onTap: () => context.push(
                          sourceReaderLocation(widget.sourceId, manga.url, chapter.url),
                        ),
                      );
                    },
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: switch (details.valueOrNull) {
        final SourceMangaDetails manga when manga.chapters.isNotEmpty => FloatingActionButton.extended(
            onPressed: () => context.push(
              // Bab terakhir di list situs = bab pertama.
              sourceReaderLocation(widget.sourceId, manga.url, manga.chapters.last.url),
            ),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Mulai baca'),
          ),
        _ => null,
      },
    );
  }

  Widget _header(BuildContext context, SourceMangaDetails manga, Map<String, String> headers) {
    final theme = Theme.of(context);
    final meta = [
      if (manga.author != null) manga.author!,
      if (manga.artist != null && manga.artist != manga.author) manga.artist!,
      manga.status.label,
      '${manga.chapters.length} bab',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SourceCover(url: manga.thumbnailUrl, headers: headers, width: 110),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(manga.title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(meta, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          if (manga.genres.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final g in manga.genres)
                  Chip(label: Text(g), visualDensity: VisualDensity.compact),
              ],
            ),
          ],
          if (manga.description != null) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => setState(() => _descExpanded = !_descExpanded),
              child: Text(
                manga.description!,
                maxLines: _descExpanded ? null : 4,
                overflow: _descExpanded ? null : TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
