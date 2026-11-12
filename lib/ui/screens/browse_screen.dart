import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/series.dart';
import '../../data/models/series_query.dart';
import '../../state/browse_provider.dart';
import '../../state/catalog_providers.dart';
import '../router.dart';
import '../widgets/series_card.dart';
import '../widgets/state_views.dart';

/// Jelajah & pencarian: GET /{novels|comics}?search=&genre=&status=&sort=&page=
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  SeriesType _type = SeriesType.novel;
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  BrowseNotifier get _notifier => ref.read(browseProviderFor(_type).notifier);

  void _onSearchChanged(String text) {
    setState(() {}); // perbarui tombol hapus (×) di kolom pencarian
    _debounce?.cancel();
    // Debounce agar tidak memicu request di setiap ketikan (ada rate limit).
    _debounce = Timer(const Duration(milliseconds: 450), () {
      final query = ref.read(browseProviderFor(_type)).query;
      if (query.search.trim() == text.trim()) return;
      _notifier.applyQuery(query.copyWith(search: text));
    });
  }

  void _switchType(SeriesType type) {
    _debounce?.cancel();
    setState(() => _type = type);
    // Tiap jenis punya query sendiri; sinkronkan isi kolom pencarian.
    _searchController.text = ref.read(browseProviderFor(type)).query.search;
  }

  Future<void> _openFilters() async {
    final current = ref.read(browseProviderFor(_type)).query;
    final result = await showModalBottomSheet<SeriesQuery>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(type: _type, initial: current),
    );
    if (result != null) {
      await _notifier.applyQuery(result.copyWith(search: _searchController.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(browseProviderFor(_type));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jelajah'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  maxLength: 100,
                  decoration: InputDecoration(
                    hintText: 'Cari judul atau penulis…',
                    prefixIcon: const Icon(Icons.search),
                    counterText: '',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<SeriesType>(
                        segments: [
                          for (final t in SeriesType.values)
                            ButtonSegment(value: t, label: Text(t.label)),
                        ],
                        selected: {_type},
                        onSelectionChanged: (s) => _switchType(s.first),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Filter & urutan',
                      onPressed: _openFilters,
                      icon: Badge(
                        isLabelVisible: state.query.hasFilters,
                        smallSize: 8,
                        child: const Icon(Icons.tune),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _notifier.refresh(),
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(BrowseState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return ScrollableFill(
        child: ErrorView(error: state.error!, onRetry: () => _notifier.refresh()),
      );
    }
    if (state.isEmpty) {
      final search = state.query.search.trim();
      return ScrollableFill(
        child: EmptyView(
          icon: Icons.search_off_rounded,
          title: search.isEmpty ? 'Belum ada ${_type.label.toLowerCase()}' : 'Tidak ada hasil',
          message: search.isEmpty
              ? 'Coba ubah filter, atau tunggu scraper mengisi data.'
              : 'Tidak ditemukan ${_type.label.toLowerCase()} untuk "$search".',
          action: state.query.hasFilters
              ? TextButton(
                  onPressed: () =>
                      _notifier.applyQuery(SeriesQuery(search: state.query.search)),
                  child: const Text('Hapus filter'),
                )
              : null,
        ),
      );
    }

    final showFooter = state.hasMore || state.loadMoreError != null;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (state.cachedAt != null)
          SliverToBoxAdapter(child: OfflineBanner(cachedAt: state.cachedAt!)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '${state.total} ${_type.label.toLowerCase()} · ${state.query.sort.label}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 140,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.52,
            ),
            itemCount: state.items.length,
            itemBuilder: (context, i) {
              final series = state.items[i];
              // Muat halaman berikutnya saat mendekati akhir grid.
              if (i >= state.items.length - 6) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _notifier.loadMore());
              }
              return SeriesCard(
                title: series.title,
                coverUrl: series.coverUrl,
                subtitle: '${series.chapterCount} bab · ${statusLabel(series.status)}',
                onTap: () => context.push(seriesLocation(series.type, series.id)),
              );
            },
          ),
        ),
        if (showFooter)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: state.loadMoreError != null
                  ? ErrorView(
                      error: state.loadMoreError!,
                      compact: true,
                      onRetry: () => _notifier.loadMore(retry: true),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

/// Bottom sheet filter genre/status/urutan. Opsi diambil dari GET /genres;
/// bila gagal (offline), filter genre/status disembunyikan, urutan tetap ada.
class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.type, required this.initial});

  final SeriesType type;
  final SeriesQuery initial;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late String? _genre = widget.initial.genre;
  late String? _status = widget.initial.status;
  late SeriesSort _sort = widget.initial.sort;

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(filterOptionsProvider);
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Urutkan', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final sort in SeriesSort.values)
                    ChoiceChip(
                      label: Text(sort.label),
                      selected: _sort == sort,
                      onSelected: (_) => setState(() => _sort = sort),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              options.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => ErrorView(
                  error: error,
                  compact: true,
                  onRetry: () => ref.invalidate(filterOptionsProvider),
                ),
                data: (fetched) {
                  final filters = fetched.data.forType(widget.type);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (filters.statuses.isNotEmpty) ...[
                        Text('Status', style: textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Semua'),
                              selected: _status == null,
                              onSelected: (_) => setState(() => _status = null),
                            ),
                            for (final status in filters.statuses)
                              ChoiceChip(
                                label: Text(statusLabel(status)),
                                selected: _status == status,
                                onSelected: (_) => setState(() => _status = status),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (filters.genres.isNotEmpty) ...[
                        Text('Genre', style: textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            ChoiceChip(
                              label: const Text('Semua'),
                              selected: _genre == null,
                              onSelected: (_) => setState(() => _genre = null),
                            ),
                            for (final genre in filters.genres)
                              ChoiceChip(
                                label: Text(genre),
                                selected: _genre == genre,
                                onSelected: (_) => setState(() => _genre = genre),
                              ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      _genre = null;
                      _status = null;
                      _sort = SeriesSort.latest;
                    }),
                    child: const Text('Reset'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      widget.initial.copyWith(
                        genre: () => _genre,
                        status: () => _status,
                        sort: _sort,
                      ),
                    ),
                    child: const Text('Terapkan'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
