import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../novels/novel_models.dart';
import '../../../novels/novel_source.dart';
import '../../../state/novel_providers.dart';
import '../../router.dart';
import '../../widgets/source_widgets.dart';
import '../../widgets/state_views.dart';
import 'novel_settings_sheet.dart';

/// Jelajah satu plugin novel: Populer (dengan filter) / Terbaru + pencarian.
class NovelBrowseScreen extends ConsumerStatefulWidget {
  const NovelBrowseScreen({super.key, required this.pluginId});

  final String pluginId;

  @override
  ConsumerState<NovelBrowseScreen> createState() => _NovelBrowseScreenState();
}

class _NovelBrowseScreenState extends ConsumerState<NovelBrowseScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;
  String _submitted = '';
  NovelFilterValues _filters = const {};

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

  Future<void> _openFilters(NovelSource source) async {
    final result = await showModalBottomSheet<NovelFilterValues>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => NovelFilterSheet(defs: source.filters, initial: _filters),
    );
    if (result != null && mounted) setState(() => _filters = result);
  }

  Future<void> _openSettings(NovelSource source) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => NovelSettingsSheet(source: source),
    );
    // Muat ulang plugin agar nilai baru dipakai sejak awal (mis. login sekali jalan).
    if (saved == true && mounted) ref.invalidate(novelSourceProvider(source.id));
  }

  @override
  Widget build(BuildContext context) {
    final sourceAsync = ref.watch(novelSourceProvider(widget.pluginId));
    final info = ref.watch(novelManifestProvider).valueOrNull?.byId(widget.pluginId);
    final title = sourceAsync.valueOrNull?.name ?? info?.name ?? widget.pluginId;

    return sourceAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Memuat plugin…')],
          ),
        ),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SourceErrorView(
          error: novelError(e, site: info?.site),
          onRetry: () => ref.invalidate(novelSourceProvider(widget.pluginId)),
          verifyUrl: info?.site,
        ),
      ),
      data: (source) => _buildBrowser(context, source),
    );
  }

  Widget _buildBrowser(BuildContext context, NovelSource source) {
    final showSearch = _submitted.isNotEmpty;
    final activeFilters = _filters.length;
    final filtersJson = _filters.isEmpty ? '' : jsonEncode(_filters);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: _searching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(hintText: 'Cari di ${source.name}…', border: InputBorder.none),
                  onSubmitted: (text) => setState(() => _submitted = text.trim()),
                )
              : Text(source.name),
          actions: [
            if (source.filters.isNotEmpty && !showSearch)
              IconButton(
                tooltip: 'Filter',
                icon: Badge(
                  isLabelVisible: activeFilters > 0,
                  label: Text('$activeFilters'),
                  child: const Icon(Icons.tune),
                ),
                onPressed: () => _openFilters(source),
              ),
            IconButton(
              tooltip: _searching ? 'Tutup pencarian' : 'Cari',
              icon: Icon(_searching ? Icons.close : Icons.search),
              onPressed: _searching ? _closeSearch : () => setState(() => _searching = true),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'settings') return _openSettings(source);
                if (v == 'web') {
                  final ok = await context.push<bool>(sourceWebViewLocation(source.site, storagePluginId: source.webStorageUtilized ? source.id : null));
                  if (ok == true) ref.invalidate(novelListProvider);
                }
              },
              itemBuilder: (_) => [
                if (source.settings.isNotEmpty)
                  const PopupMenuItem(value: 'settings', child: Text('Pengaturan plugin')),
                const PopupMenuItem(value: 'web', child: Text('Buka situs di WebView')),
              ],
            ),
          ],
          bottom: showSearch
              ? null
              : TabBar(tabs: [
                  Tab(text: activeFilters > 0 ? 'Populer · filter' : 'Populer'),
                  const Tab(text: 'Terbaru'),
                ]),
        ),
        body: showSearch
            ? NovelGrid(
                key: ValueKey('search:$_submitted'),
                source: source,
                listKey: (pluginId: source.id, listing: NovelListing.search, query: _submitted, filtersJson: ''),
              )
            : TabBarView(
                children: [
                  NovelGrid(
                    key: ValueKey('popular:$filtersJson'),
                    source: source,
                    listKey: (pluginId: source.id, listing: NovelListing.popular, query: '', filtersJson: filtersJson),
                  ),
                  NovelGrid(
                    source: source,
                    listKey: (pluginId: source.id, listing: NovelListing.latest, query: '', filtersJson: ''),
                  ),
                ],
              ),
      ),
    );
  }
}

class NovelGrid extends ConsumerWidget {
  const NovelGrid({super.key, required this.source, required this.listKey});

  final NovelSource source;
  final NovelListKey listKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(novelListProvider(listKey));
    final notifier = ref.read(novelListProvider(listKey).notifier);

    if (state.error != null) {
      return SourceErrorView(error: state.error!, onRetry: notifier.refresh, verifyUrl: source.site);
    }
    if (state.isLoading && state.items.isEmpty) {
      return const LoadingView();
    }
    if (state.isEmpty) {
      return EmptyView(
        icon: Icons.search_off_rounded,
        title: listKey.listing == NovelListing.search ? 'Tidak ada hasil untuk "${listKey.query}"' : 'Belum ada judul',
      );
    }
    final showFooter = state.hasNextPage || state.loadMoreError != null;

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
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
                  final novel = state.items[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => context.push(novelDetailLocation(source.id, novel.path)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SourceCover(url: novel.cover, headers: source.imageHeaders),
                        const SizedBox(height: 6),
                        Text(
                          novel.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
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
                          verifyUrl: source.site,
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

/// Lembar filter plugin LNReader: Picker, Checkbox, Switch, Text, XCheckbox.
/// Mengembalikan hanya nilai yang berbeda dari bawaan.
class NovelFilterSheet extends StatefulWidget {
  const NovelFilterSheet({super.key, required this.defs, required this.initial});

  final List<NovelFilterDef> defs;
  final NovelFilterValues initial;

  @override
  State<NovelFilterSheet> createState() => _NovelFilterSheetState();
}

class _NovelFilterSheetState extends State<NovelFilterSheet> {
  late final Map<String, Object?> _values = {
    for (final d in widget.defs) d.key: _copy(widget.initial.containsKey(d.key) ? widget.initial[d.key] : d.defaultValue),
  };
  final _text = <String, TextEditingController>{};

  static Object? _copy(Object? v) => v == null ? null : jsonDecode(jsonEncode(v));

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _list(Object? v) => v is List ? v.map((e) => '$e').toList() : <String>[];

  Map<String, List<String>> _xmap(Object? v) {
    final m = v is Map ? v : const {};
    return {'include': _list(m['include']), 'exclude': _list(m['exclude'])};
  }

  NovelFilterValues _changed() => {
        for (final d in widget.defs)
          if (jsonEncode(_values[d.key]) != jsonEncode(d.defaultValue)) d.key: _values[d.key],
      };

  Widget _section(NovelFilterDef def) {
    final theme = Theme.of(context);
    final header = Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(def.label, style: theme.textTheme.titleSmall),
    );
    switch (def.type) {
      case NovelFilterType.toggle:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(def.label),
          value: _values[def.key] == true,
          onChanged: (v) => setState(() => _values[def.key] = v),
        );
      case NovelFilterType.text:
        final c = _text.putIfAbsent(def.key, () => TextEditingController(text: '${_values[def.key] ?? ''}'));
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: TextField(
            controller: c,
            decoration: InputDecoration(labelText: def.label, border: const OutlineInputBorder(), isDense: true),
            onChanged: (v) => _values[def.key] = v,
          ),
        );
      case NovelFilterType.picker:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final o in def.options)
                ChoiceChip(
                  label: Text(o.label),
                  selected: '${_values[def.key] ?? ''}' == o.value,
                  onSelected: (_) => setState(() => _values[def.key] = o.value),
                ),
            ]),
          ],
        );
      case NovelFilterType.checkbox:
        final selected = _list(_values[def.key]);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final o in def.options)
                FilterChip(
                  label: Text(o.label),
                  selected: selected.contains(o.value),
                  onSelected: (on) => setState(() {
                    _values[def.key] = on ? [...selected, o.value] : selected.where((v) => v != o.value).toList();
                  }),
                ),
            ]),
          ],
        );
      case NovelFilterType.excludable:
        final x = _xmap(_values[def.key]);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            Text('Ketuk: sertakan → kecualikan → netral', style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final o in def.options)
                FilterChip(
                  label: Text(o.label),
                  avatar: x['include']!.contains(o.value)
                      ? const Icon(Icons.check, size: 16)
                      : x['exclude']!.contains(o.value)
                          ? const Icon(Icons.block, size: 16)
                          : null,
                  selected: x['include']!.contains(o.value) || x['exclude']!.contains(o.value),
                  selectedColor: x['exclude']!.contains(o.value) ? theme.colorScheme.errorContainer : null,
                  showCheckmark: false,
                  onSelected: (_) => setState(() {
                    final inc = x['include']!;
                    final exc = x['exclude']!;
                    if (inc.contains(o.value)) {
                      inc.remove(o.value);
                      exc.add(o.value);
                    } else if (exc.contains(o.value)) {
                      exc.remove(o.value);
                    } else {
                      inc.add(o.value);
                    }
                    _values[def.key] = {'include': inc, 'exclude': exc};
                  }),
                ),
            ]),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                children: [for (final d in widget.defs) _section(d)],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, const <String, Object?>{}),
                    child: const Text('Reset'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _changed()),
                    child: const Text('Terapkan'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
