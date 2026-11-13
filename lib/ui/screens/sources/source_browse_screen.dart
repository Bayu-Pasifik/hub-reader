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

  /// Query yang sudah dikirim (Enter). Kosong + tanpa filter = tampilkan tab.
  String _submitted = '';
  FilterValues _filters = FilterValues.empty;

  Future<void> _openFilters(MangaSource source) async {
    final result = await showModalBottomSheet<FilterValues>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(sourceId: source.id, initial: _filters),
    );
    if (result != null && mounted) setState(() => _filters = result);
  }

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
    final showResults = _submitted.isNotEmpty || !_filters.isEmpty;

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
              tooltip: 'Filter',
              icon: Badge(
                isLabelVisible: !_filters.isEmpty,
                label: Text('${_filters.activeCount}'),
                child: const Icon(Icons.tune),
              ),
              onPressed: () => _openFilters(source),
            ),
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
                key: ValueKey('search:$_submitted:$_filters'),
                source: source,
                listKey: (
                  sourceId: source.id,
                  listing: SourceListing.search,
                  query: _submitted,
                  filters: _filters,
                ),
              )
            : TabBarView(
                children: [
                  for (final t in tabs)
                    _MangaGrid(
                      source: source,
                      listKey: (
                        sourceId: source.id,
                        listing: t.listing,
                        query: '',
                        filters: FilterValues.empty,
                      ),
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
      return SourceErrorView(
        error: state.error!,
        onRetry: notifier.refresh,
        verifyUrl: source.baseUrl,
      );
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
                          verifyUrl: source.baseUrl,
                        )
                      : LoadMoreFooter(onShown: notifier.loadMore),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lembar filter: chip pilih-satu & pilih-banyak dari definisi sumber.
class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.sourceId, required this.initial});

  final String sourceId;
  final FilterValues initial;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late FilterValues _values = widget.initial;

  @override
  Widget build(BuildContext context) {
    final defs = ref.watch(sourceFiltersProvider(widget.sourceId));
    final theme = Theme.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: defs.when(
          loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
          error: (error, _) => SourceErrorView(
            compact: true,
            error: error,
            onRetry: () => ref.invalidate(sourceFiltersProvider(widget.sourceId)),
          ),
          data: (list) => list.isEmpty
              ? const EmptyView(compact: true, title: 'Sumber ini tidak punya filter')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        children: [
                          for (final def in list) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 12, bottom: 6),
                              child: Text(def.label, style: theme.textTheme.titleSmall),
                            ),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final option in def.options)
                                  switch (def) {
                                    SelectFilterDef() => ChoiceChip(
                                        label: Text(option.label),
                                        selected: (_values.single(def.key) ?? '') == option.value,
                                        onSelected: (_) => setState(
                                          () => _values = _values.withSingle(def.key, option.value),
                                        ),
                                      ),
                                    MultiSelectFilterDef() => FilterChip(
                                        label: Text(option.label),
                                        selected: _values.multi(def.key).contains(option.value),
                                        onSelected: (_) => setState(
                                          () => _values = _values.toggleMulti(def.key, option.value),
                                        ),
                                      ),
                                  },
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _values = FilterValues.empty),
                            child: const Text('Reset'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, _values),
                            child: const Text('Terapkan'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
