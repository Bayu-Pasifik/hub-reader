import '../../haptics.dart';
import 'dart:math' show Random, max;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/source_library.dart';
import '../../../trackers/tracker.dart' show TrackStatus;
import '../../../state/download_providers.dart' show downloadIndexProvider;
import '../../../state/library_updates_provider.dart';
import '../../../state/novel_providers.dart';
import '../../../state/source_library_providers.dart';
import '../../../state/tracker_providers.dart' show trackLinksProvider;
import '../../router.dart';
import '../../widgets/category_sheet.dart' show askCategoryName;
import '../../widgets/continue_reading.dart';
import '../../widgets/library_routing.dart';
import '../../widgets/source_widgets.dart';
import '../../widgets/state_views.dart';
import '../../../core/i18n/strings.dart';

typedef LibraryExtras = ({
  Set<String> tracked,
  Map<String, Set<String>> trackStatuses,
  Map<String, DateTime> updatedAt,
  Map<String, String> sourceNames,
});

/// Favorit komik & novel, per kategori (tab), dengan filter dan urutan.
class SourceFavoritesScreen extends ConsumerStatefulWidget {
  const SourceFavoritesScreen({super.key});

  @override
  ConsumerState<SourceFavoritesScreen> createState() => _SourceFavoritesScreenState();
}

class _SourceFavoritesScreenState extends ConsumerState<SourceFavoritesScreen> {
  final _search = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Bab baru (dari Pembaruan) yang belum dibaca, per seri.
  Map<String, int> _unreadCounts() {
    final progress = ref.watch(sourceProgressProvider);
    final counts = <String, int>{};
    for (final u in ref.watch(libraryUpdatesProvider.select((s) => s.updates))) {
      if (progress[u.item.key]?[u.chapterUrl]?.done ?? false) continue;
      counts[u.item.key] = (counts[u.item.key] ?? 0) + 1;
    }
    return counts;
  }

  /// Data tambahan untuk filter "dilacak" dan urutan "pembaruan"/"sumber".
  LibraryExtras _extras() {
    final updatedAt = <String, DateTime>{};
    for (final u in ref.watch(libraryUpdatesProvider.select((s) => s.updates))) {
      final cur = updatedAt[u.item.key];
      if (cur == null || u.foundAt.isAfter(cur)) updatedAt[u.item.key] = u.foundAt;
    }
    final links = ref.watch(trackLinksProvider);
    final tracked = {
      for (final e in links.entries)
        if (e.value.isNotEmpty) e.key,
    };
    final trackStatuses = {
      for (final e in links.entries)
        if (e.value.isNotEmpty) e.key: {for (final l in e.value) l.status.name},
    };
    final names = <String, String>{};
    for (final f in ref.watch(sourceFavoritesProvider)) {
      names.putIfAbsent(f.item.sourceId, () => librarySourceInfo(ref, f.item.sourceId).name);
    }
    return (tracked: tracked, trackStatuses: trackStatuses, updatedAt: updatedAt, sourceNames: names);
  }

  List<SourceFavorite> _apply(
    List<SourceFavorite> list,
    String? category,
    LibraryView view,
    Map<String, int> unread,
    Map<String, DateTime> lastRead,
    Set<String> downloaded,
    LibraryExtras extras,
  ) {
    final q = _search.text.trim().toLowerCase();
    final out = list.where((f) {
      if (category != null && !f.categories.contains(category)) return false;
      final novel = isNovelSourceId(f.item.sourceId);
      if (view.kind == LibraryKind.comic && novel) return false;
      if (view.kind == LibraryKind.novel && !novel) return false;
      if (view.unreadOnly && (unread[f.item.key] ?? 0) == 0) return false;
      if (view.downloadedOnly && !downloaded.contains(f.item.key)) return false;
      if (view.startedOnly && !lastRead.containsKey(f.item.key)) return false;
      if (view.unstartedOnly && lastRead.containsKey(f.item.key)) return false;
      if (view.trackedOnly && !extras.tracked.contains(f.item.key)) return false;
      if (view.trackStatus.isNotEmpty && !(extras.trackStatuses[f.item.key]?.contains(view.trackStatus) ?? false)) {
        return false;
      }
      if (view.tag.isNotEmpty && !f.tags.any((t) => t.toLowerCase() == view.tag.toLowerCase())) return false;
      if (q.isNotEmpty && !f.item.title.toLowerCase().contains(q) && !f.tags.any((t) => t.toLowerCase().contains(q))) {
        return false;
      }
      return true;
    }).toList();
    final epoch = DateTime(0);
    switch (view.sort) {
      case LibrarySort.added:
        out.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      case LibrarySort.title:
        out.sort((a, b) => a.item.title.toLowerCase().compareTo(b.item.title.toLowerCase()));
      case LibrarySort.lastRead:
        out.sort((a, b) => (lastRead[b.item.key] ?? epoch).compareTo(lastRead[a.item.key] ?? epoch));
      case LibrarySort.unread:
        out.sort((a, b) => (unread[b.item.key] ?? 0).compareTo(unread[a.item.key] ?? 0));
      case LibrarySort.updated:
        out.sort((a, b) => (extras.updatedAt[b.item.key] ?? epoch).compareTo(extras.updatedAt[a.item.key] ?? epoch));
      case LibrarySort.source:
        out.sort((a, b) {
          final byName = (extras.sourceNames[a.item.sourceId] ?? a.item.sourceId)
              .toLowerCase()
              .compareTo((extras.sourceNames[b.item.sourceId] ?? b.item.sourceId).toLowerCase());
          return byName != 0 ? byName : a.item.title.toLowerCase().compareTo(b.item.title.toLowerCase());
        });
    }
    return view.reversed ? out.reversed.toList() : out;
  }

  /// Buka seri acak dari tab yang sedang tampil (sesuai filter & pencarian).
  void _openRandom(
    List<SourceFavorite> favorites,
    List<String?> tabs,
    int tabIndex,
    LibraryView view,
    Map<String, int> unread,
    Map<String, DateTime> lastRead,
    Set<String> downloaded,
    LibraryExtras extras,
  ) {
    final category = tabs[tabIndex.clamp(0, tabs.length - 1)];
    final pool = _apply(
        favorites, category, effectiveLibraryView(view, ref.read(libraryCategoryViewsProvider), category), unread, lastRead, downloaded, extras);
    if (pool.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(tr('Tidak ada favorit yang cocok'))));
      return;
    }
    final pick = pool[Random().nextInt(pool.length)];
    context.push(librarySourceInfo(ref, pick.item.sourceId).detailLocation(pick.item.url));
  }

  Future<void> _openFilter(String? category) => showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _ViewSheet(category: category),
      );

  Future<void> _openActions(SourceFavorite entry) => showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _FavoriteActionsSheet(entry: entry),
      );

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(sourceFavoritesProvider);
    final categories = ref.watch(libraryCategoriesProvider);
    final view = ref.watch(libraryViewProvider);
    final unread = _unreadCounts();
    final lastRead = {for (final h in ref.watch(sourceHistoryProvider)) h.item.key: h.readAt};
    final unseen = ref.watch(libraryUpdatesProvider.select((s) => s.unseen));
    final checking = ref.watch(libraryUpdatesProvider.select((s) => s.checking));
    final downloaded = {for (final c in ref.watch(downloadIndexProvider).values) c.mangaKey};
    final extras = _extras();
    final categoryViews = ref.watch(libraryCategoryViewsProvider);
    final filtered = isLibraryViewFiltered(view) || categoryViews.values.any(isLibraryViewFiltered);
    final tabs = <String?>[null, ...categories];

    return DefaultTabController(
      key: ValueKey(categories.join('\u0000')),
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: _searching
              ? TextField(
                  controller: _search,
                  autofocus: true,
                  decoration: InputDecoration(hintText: tr('Cari di favorit…'), border: InputBorder.none),
                  onChanged: (_) => setState(() {}),
                )
              : Text(tr('Favorit')),
          actions: [
            IconButton(
              tooltip: _searching ? tr('Tutup pencarian') : tr('Cari'),
              icon: Icon(_searching ? Icons.close : Icons.search),
              onPressed: () => setState(() {
                _searching = !_searching;
                if (!_searching) _search.clear();
              }),
            ),
            Builder(
              builder: (context) => IconButton(
                tooltip: tr('Baca acak'),
                icon: const Icon(Icons.casino_outlined),
                onPressed: () => _openRandom(
                  favorites,
                  tabs,
                  DefaultTabController.of(context).index,
                  view,
                  unread,
                  lastRead,
                  downloaded,
                  extras,
                ),
              ),
            ),
            Builder(
              builder: (context) => IconButton(
                tooltip: tr('Tampilan, filter & urutan'),
                icon: Badge(isLabelVisible: filtered, smallSize: 8, child: const Icon(Icons.filter_list)),
                onPressed: () => _openFilter(tabs[DefaultTabController.of(context).index.clamp(0, tabs.length - 1)]),
              ),
            ),
            IconButton(
              tooltip: tr('Riwayat'),
              icon: const Icon(Icons.history),
              onPressed: () => context.push('/history'),
            ),
            IconButton(
              tooltip: tr('Pembaruan'),
              icon: Badge(
                isLabelVisible: unseen > 0,
                label: Text('$unseen'),
                child: checking
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.new_releases_outlined),
              ),
              onPressed: () => context.push('/updates'),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'backup') context.push('/backup');
                if (v == 'categories') {
                  showDialog<void>(context: context, useRootNavigator: true, builder: (_) => const _CategoriesDialog());
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'categories', child: Text(tr('Kelola kategori'))),
                PopupMenuItem(value: 'backup', child: Text(tr('Cadangkan & pulihkan'))),
              ],
            ),
          ],
          bottom: categories.isEmpty
              ? null
              : TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    for (final c in tabs)
                      Tab(
                        text: '${c ?? 'Semua'} '
                            '(${c == null ? favorites.length : favorites.where((f) => f.categories.contains(c)).length})',
                      ),
                  ],
                ),
        ),
        body: Column(
          children: [
            // Tersembunyi saat mencari supaya hasil pencarian tidak terdorong.
            if (!_searching) const ContinueReadingStrip(),
            Expanded(
              child: favorites.isEmpty
                  ? EmptyView(
                      icon: Icons.favorite_outline,
                      title: tr('Belum ada favorit'),
                      message: tr('Ketuk ikon hati di halaman detail seri untuk menyimpannya ke sini.'),
                      action: FilledButton.icon(
                        onPressed: () => context.go('/sources'),
                        icon: const Icon(Icons.explore_outlined),
                        label: Text(tr('Jelajahi komik')),
                      ),
                    )
                  : TabBarView(
                      children: [
                        for (final c in tabs)
                          _FavoritesGrid(
                            entries: _apply(
                                favorites, c, effectiveLibraryView(view, categoryViews, c), unread, lastRead, downloaded, extras),
                            unread: unread,
                            onLongPress: _openActions,
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

/// Tinggi kira-kira blok teks di bawah sampul grid (2 baris judul + 1 baris
/// sumber) pada skala font 1x; dipakai untuk menambah tinggi sel di font besar.
const favoriteTextBlockHeight = 62.0;

class _FavoritesGrid extends ConsumerWidget {
  const _FavoritesGrid({required this.entries, required this.unread, required this.onLongPress});

  final List<SourceFavorite> entries;
  final Map<String, int> unread;
  final void Function(SourceFavorite) onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entries.isEmpty) {
      return EmptyView(animation: AppAnimation.searchFile, title: tr('Tidak ada favorit yang cocok'));
    }
    final layout = ref.watch(libraryLayoutProvider);

    Widget tile(SourceFavorite entry) {
      final item = entry.item;
      final source = librarySourceInfo(ref, item.sourceId);
      return _FavoriteTile(
        entry: entry,
        source: source,
        count: unread[item.key] ?? 0,
        display: layout.display,
        onTap: () => context.push(source.detailLocation(item.url)),
        onLongPress: () => onLongPress(entry),
      );
    }

    if (layout.display == LibraryDisplay.list) {
      return ListView.builder(
        key: const PageStorageKey('library-list'),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: entries.length,
        itemBuilder: (context, i) => tile(entries[i]),
      );
    }

    // Tinggi sel: sampul 3:4 + (mode grid) dua baris judul dan satu baris sumber.
    // Tinggi bagian teks ikut skala font sistem; tanpa itu judul meluap di font besar.
    final isGrid = layout.display == LibraryDisplay.grid;
    return LayoutBuilder(builder: (context, constraints) {
      const pad = 12.0, gap = 12.0;
      final maxExtent = isGrid ? 160.0 : 120.0;
      final usable = constraints.maxWidth - pad * 2;
      final columns = layout.columns == 0 ? max(1, (usable / (maxExtent + gap)).ceil()) : layout.columns;
      final cellWidth = (usable - gap * (columns - 1)) / columns;
      final ratio = !isGrid ? 3 / 4 : (layout.columns >= 4 ? 0.45 : 0.5);
      final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 3.0);
      final extra = isGrid ? favoriteTextBlockHeight * (textScale - 1) : 0.0;
      return GridView.builder(
        key: const PageStorageKey('library-grid'),
        padding: const EdgeInsets.all(pad),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
          mainAxisExtent: cellWidth / ratio + extra,
        ),
        itemCount: entries.length,
        itemBuilder: (context, i) => tile(entries[i]),
      );
    });
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({
    required this.entry,
    required this.source,
    required this.count,
    required this.display,
    required this.onTap,
    required this.onLongPress,
  });

  final SourceFavorite entry;
  final LibrarySourceInfo source;
  final int count;
  final LibraryDisplay display;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  Widget _badge(ThemeData theme) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(6)),
        child: Text('$count', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimary)),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = entry.item;
    final subtitle = source.isNovel ? '${tr('Novel')} · ${source.name}' : source.name;

    if (display == LibraryDisplay.list) {
      return ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        leading: SourceCover(url: item.thumbnailUrl, headers: source.imageHeaders, width: 48),
        title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: count > 0 ? _badge(theme) : null,
      );
    }

    final cover = Stack(
      children: [
        SourceCover(url: item.thumbnailUrl, headers: source.imageHeaders),
        if (count > 0) Positioned(top: 4, left: 4, child: _badge(theme)),
        if (display == LibraryDisplay.compact)
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
    );

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      onLongPress: onLongPress,
      child: display == LibraryDisplay.grid
          ? Column(
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
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
              ],
            )
          : cover,
    );
  }
}

class _ViewSheet extends ConsumerWidget {
  const _ViewSheet({this.category});

  /// Tab yang sedang dibuka; null = tab "Semua" (selalu memakai tampilan umum).
  final String? category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final global = ref.watch(libraryViewProvider);
    final globalN = ref.read(libraryViewProvider.notifier);
    final cat = category;
    final catViews = ref.watch(libraryCategoryViewsProvider);
    final catN = ref.read(libraryCategoryViewsProvider.notifier);
    final perCategory = cat != null && catViews.containsKey(cat);
    final view = perCategory ? catViews[cat]! : global;
    // Ubah tampilan kategori bila "Khusus kategori ini" aktif, kalau tidak yang umum.
    Future<void> setView({
      LibrarySort? sort,
      bool? reversed,
      LibraryKind? kind,
      bool? unreadOnly,
      bool? downloadedOnly,
      bool? startedOnly,
      bool? unstartedOnly,
      bool? trackedOnly,
      String? trackStatus,
      String? tag,
    }) {
      if (perCategory) {
        return catN.set(cat, (
          sort: sort ?? view.sort,
          reversed: reversed ?? view.reversed,
          kind: kind ?? view.kind,
          unreadOnly: unreadOnly ?? view.unreadOnly,
          downloadedOnly: downloadedOnly ?? view.downloadedOnly,
          startedOnly: startedOnly ?? view.startedOnly,
          unstartedOnly: unstartedOnly ?? view.unstartedOnly,
          trackedOnly: trackedOnly ?? view.trackedOnly,
          trackStatus: trackStatus ?? view.trackStatus,
          tag: tag ?? view.tag,
        ));
      }
      return globalN.set(
        sort: sort,
        reversed: reversed,
        kind: kind,
        unreadOnly: unreadOnly,
        downloadedOnly: downloadedOnly,
        startedOnly: startedOnly,
        unstartedOnly: unstartedOnly,
        trackedOnly: trackedOnly,
        trackStatus: trackStatus,
        tag: tag,
      );
    }
    final allTags = ref.watch(libraryTagsProvider);
    final layout = ref.watch(libraryLayoutProvider);
    final layoutNotifier = ref.read(libraryLayoutProvider.notifier);
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cat != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(trp('Khusus kategori "{c}"', {'c': cat})),
                subtitle: Text(perCategory ? tr('Urutan & filter disimpan untuk kategori ini') : tr('Mengikuti tampilan umum')),
                // Mulai dari tampilan yang sedang berlaku, supaya tidak berubah tiba-tiba.
                value: perCategory,
                onChanged: (on) => catN.set(cat, on ? global : null),
              ),
            Text(tr('Mode tampilan'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final d in LibraryDisplay.values)
                ChoiceChip(
                  label: Text(tr(d.label)),
                  selected: layout.display == d,
                  onSelected: (_) => layoutNotifier.set(display: d),
                ),
            ]),
            if (layout.display != LibraryDisplay.list) ...[
              const SizedBox(height: 8),
              Text(
                layout.columns == 0 ? tr('Kolom: otomatis') : '${tr('Kolom')}: ${layout.columns}',
                style: theme.textTheme.bodyMedium,
              ),
              Slider(
                value: layout.columns.toDouble(),
                min: 0,
                max: LibraryLayoutNotifier.maxColumns.toDouble(),
                divisions: LibraryLayoutNotifier.maxColumns,
                label: layout.columns == 0 ? tr('Otomatis') : '${layout.columns}',
                onChanged: (v) => layoutNotifier.set(columns: v.round()),
              ),
            ],
            const SizedBox(height: 8),
            Text(tr('Jenis'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final k in LibraryKind.values)
                ChoiceChip(label: Text(k.label), selected: view.kind == k, onSelected: (_) => setView(kind: k)),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('Hanya yang ada bab baru belum dibaca')),
              value: view.unreadOnly,
              onChanged: (v) => setView(unreadOnly: v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('Hanya yang sudah mulai dibaca')),
              value: view.startedOnly,
              // Saling meniadakan dengan "belum mulai dibaca".
              onChanged: (v) => setView(startedOnly: v, unstartedOnly: v ? false : null),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('Hanya yang belum mulai dibaca')),
              value: view.unstartedOnly,
              onChanged: (v) => setView(unstartedOnly: v, startedOnly: v ? false : null),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('Hanya yang terhubung tracker')),
              value: view.trackedOnly,
              // Memilih status otomatis menyiratkan "terhubung tracker".
              onChanged: (v) => setView(trackedOnly: v, trackStatus: v ? null : ''),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final s in TrackStatus.values)
                  FilterChip(
                    label: Text(s.label),
                    selected: view.trackStatus == s.name,
                    onSelected: (on) => setView(trackStatus: on ? s.name : ''),
                  ),
              ]),
            ),
            if (allTags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(tr('Tag'), style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final t in allTags)
                  FilterChip(
                    label: Text(t),
                    selected: view.tag.toLowerCase() == t.toLowerCase(),
                    onSelected: (on) => setView(tag: on ? t : ''),
                  ),
              ]),
              const SizedBox(height: 4),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('Hanya yang sudah diunduh')),
              value: view.downloadedOnly,
              onChanged: (v) => setView(downloadedOnly: v),
            ),
            Text(tr('Urutkan'), style: theme.textTheme.titleSmall),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('Balik urutan')),
              value: view.reversed,
              onChanged: (v) => setView(reversed: v),
            ),
            RadioGroup<LibrarySort>(
              groupValue: view.sort,
              onChanged: (v) => setView(sort: v),
              child: Column(
                children: [
                  for (final s in LibrarySort.values)
                    RadioListTile<LibrarySort>(contentPadding: EdgeInsets.zero, value: s, title: Text(s.label)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteActionsSheet extends ConsumerWidget {
  const _FavoriteActionsSheet({required this.entry});

  final SourceFavorite entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(libraryCategoriesProvider);
    final current = ref.watch(sourceFavoritesProvider.select(
      (list) => list.where((f) => f.item.key == entry.item.key).firstOrNull?.categories ?? const <String>[],
    ));
    final currentTags = ref.watch(sourceFavoritesProvider.select(
      (list) => list.where((f) => f.item.key == entry.item.key).firstOrNull?.tags ?? const <String>[],
    ));
    final allTags = ref.watch(libraryTagsProvider);
    final favorites = ref.read(sourceFavoritesProvider.notifier);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(entry.item.title, style: Theme.of(context).textTheme.titleMedium),
            ),
            if (categories.isEmpty)
              ListTile(
                leading: Icon(Icons.info_outline),
                title: Text(tr('Belum ada kategori')),
                subtitle: Text(tr('Buat kategori di bawah untuk mengelompokkan favorit.')),
              ),
            for (final c in categories)
              CheckboxListTile(
                title: Text(c),
                value: current.contains(c),
                onChanged: (v) => favorites.setCategories(
                  entry.item.key,
                  v == true ? [...current, c] : current.where((x) => x != c).toList(),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(tr('Kategori baru')),
              onTap: () async {
                final name = await askCategoryName(context, title: tr('Kategori baru'));
                if (name == null) return;
                if (await ref.read(libraryCategoriesProvider.notifier).add(name)) {
                  await favorites.setCategories(entry.item.key, [...current, name.trim()]);
                }
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(tr('Tag'), style: Theme.of(context).textTheme.titleSmall),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final t in {...allTags, ...currentTags})
                  FilterChip(
                    label: Text(t),
                    selected: currentTags.any((x) => x.toLowerCase() == t.toLowerCase()),
                    onSelected: (on) => favorites.setTags(
                      entry.item.key,
                      on ? [...currentTags, t] : currentTags.where((x) => x.toLowerCase() != t.toLowerCase()).toList(),
                    ),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(tr('Tag baru')),
                  onPressed: () async {
                    final name = await askCategoryName(context, title: tr('Tag baru'), hint: tr('Nama tag'));
                    if (name == null) return;
                    await favorites.setTags(entry.item.key, [...currentTags, name]);
                  },
                ),
              ]),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(tr('Pindah sumber')),
              onTap: () {
                Navigator.pop(context);
                context.push(migrateLocation(entry.item.sourceId, entry.item.url, entry.item.title));
              },
            ),
            ListTile(
              leading: const Icon(Icons.heart_broken_outlined),
              title: Text(tr('Hapus dari favorit')),
              onTap: () {
                final messenger = ScaffoldMessenger.of(context);
                Haptics.thud();
                favorites.remove(entry.item.key);
                Navigator.pop(context);
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                    content: Text(trp('"{title}" dihapus dari favorit', {'title': entry.item.title})),
                    persist: false,
                    action: SnackBarAction(label: tr('Urungkan'), onPressed: () {
                      Haptics.tap();
                      favorites.restore(entry);
                    }),
                  ));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoriesDialog extends ConsumerWidget {
  const _CategoriesDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(libraryCategoriesProvider);
    final n = ref.read(libraryCategoriesProvider.notifier);
    return AlertDialog(
      title: Text(tr('Kategori')),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: categories.isEmpty
            ? Padding(
                padding: EdgeInsets.all(16),
                child: Text(tr('Belum ada kategori. Kategori jadi tab di halaman Favorit.')),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (var i = 0; i < categories.length; i++)
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 8),
                      title: Text(categories[i]),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                spacing: 6,
                        children: [
                          IconButton(
                            tooltip: tr('Naik'),
                            icon: const Icon(Icons.arrow_upward, size: 20),
                            onPressed: i == 0 ? null : () => n.move(categories[i], -1),
                          ),
                          IconButton(
                            tooltip: tr('Ganti nama'),
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () async {
                              final name = await askCategoryName(context, title: tr('Ganti nama'), initial: categories[i]);
                              if (name != null) await n.rename(categories[i], name);
                            },
                          ),
                          IconButton(
                            tooltip: tr('Hapus'),
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(trp('Hapus kategori "{name}"?', {'name': categories[i]})),
                                  content: Text(tr('Seri di dalamnya tidak dihapus, hanya dilepas dari kategori ini.')),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Batal'))),
                                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Hapus'))),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                Haptics.thud();
                                await n.remove(categories[i]);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final name = await askCategoryName(context, title: tr('Kategori baru'));
            if (name != null) await n.add(name);
          },
          child: Text(tr('Tambah')),
        ),
        FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr('Selesai'))),
      ],
    );
  }
}

