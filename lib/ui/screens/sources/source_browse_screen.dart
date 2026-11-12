import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../sources/source.dart';
import '../../../state/source_providers.dart';
import '../../router.dart';
import '../../widgets/source_widgets.dart';
import '../../widgets/state_views.dart';

/// Jelajah satu sumber: tab Populer / Terbaru + pencarian.
class SourceBrowseScreen extends ConsumerStatefulWidget {
  const SourceBrowseScreen({super.key, required this.sourceId});

  final String sourceId;

  @override
  ConsumerState<SourceBrowseScreen> createState() => _SourceBrowseScreenState();
}

class _SourceBrowseScreenState extends ConsumerState<SourceBrowseScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;

  /// Query yang sudah dikirim (Enter). Kosong = tampilkan tab.
  String _submitted = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _closeSearch() => setState(() {
        _searching = false;
        _submitted = '';
        _searchController.clear();
      });

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(sourceProvider(widget.sourceId));
    if (source == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyView(title: 'Sumber tidak ditemukan'),
      );
    }

    final tabs = [
      (label: 'Populer', listing: SourceListing.popular),
      if (source.supportsLatest) (label: 'Terbaru', listing: SourceListing.latest),
    ];
    final showResults = _submitted.isNotEmpty;

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: _searching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Cari di ${source.name}…',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (text) => setState(() => _submitted = text.trim()),
                )
              : Text(source.name),
          actions: [
            IconButton(
              tooltip: _searching ? 'Tutup pencarian' : 'Cari',
              icon: Icon(_searching ? Icons.close : Icons.search),
              onPressed: _searching ? _closeSearch : () => setState(() => _searching = true),
            ),
          ],
          bottom: showResults
              ? null
              : TabBar(tabs: [for (final t in tabs) Tab(text: t.label)]),
        ),
        body: showResults
            ? _MangaGrid(
                key: ValueKey('search:$_submitted'),
                source: source,
                listKey: (sourceId: source.id, listing: SourceListing.search, query: _submitted),
              )
            : TabBarView(
                children: [
                  for (final t in tabs)
                    _MangaGrid(
                      source: source,
                      listKey: (sourceId: source.id, listing: t.listing, query: ''),
                    ),
                ],
              ),
      ),
    );
  }
}

class _MangaGrid extends ConsumerWidget {
  const _MangaGrid({super.key, required this.source, required this.listKey});

  final MangaSource source;
  final SourceListKey listKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sourceListProvider(listKey));
    final notifier = ref.read(sourceListProvider(listKey).notifier);
    final headers = source.imageHeaders();

    if (state.error != null) {
      return SourceErrorView(error: state.error!, onRetry: notifier.refresh);
    }
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.isEmpty) {
      return EmptyView(
        icon: Icons.search_off_rounded,
        title: listKey.listing == SourceListing.search
            ? 'Tidak ada hasil untuk "${listKey.query}"'
            : 'Belum ada judul',
      );
    }

    final showFooter = state.hasNextPage || state.loadMoreError != null;

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          // Ditunda: notifikasi scroll bisa terjadi saat layout.
          if (n.metrics.extentAfter < 600) Future.microtask(notifier.loadMore);
          return false;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 160,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.56,
                ),
                itemCount: state.items.length,
                itemBuilder: (context, i) {
                  final manga = state.items[i];
                  return SourceMangaCard(
                    manga: manga,
                    headers: headers,
                    onTap: () => context.push(sourceMangaLocation(source.id, manga.url)),
                  );
                },
              ),
            ),
            if (showFooter)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: state.loadMoreError != null
                      ? SourceErrorView(
                          compact: true,
                          error: state.loadMoreError!,
                          onRetry: () => notifier.loadMore(retry: true),
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
