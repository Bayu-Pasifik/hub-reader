import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/source_library.dart';
import '../../../state/library_updates_provider.dart';
import '../../../state/novel_providers.dart';
import '../../../state/source_library_providers.dart';
import '../../widgets/library_routing.dart';
import '../../widgets/source_widgets.dart';
import '../../widgets/state_views.dart';

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

  List<SourceFavorite> _apply(
    List<SourceFavorite> list,
    String? category,
    LibraryView view,
    Map<String, int> unread,
    Map<String, DateTime> lastRead,
  ) {
    final q = _search.text.trim().toLowerCase();
    final out = list.where((f) {
      if (category != null && !f.categories.contains(category)) return false;
      final novel = isNovelSourceId(f.item.sourceId);
      if (view.kind == LibraryKind.comic && novel) return false;
      if (view.kind == LibraryKind.novel && !novel) return false;
      if (view.unreadOnly && (unread[f.item.key] ?? 0) == 0) return false;
      if (q.isNotEmpty && !f.item.title.toLowerCase().contains(q)) return false;
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
    }
    return out;
  }

  Future<void> _openFilter() => showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        showDragHandle: true,
        builder: (_) => const _ViewSheet(),
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
    final filtered = view.kind != LibraryKind.all || view.unreadOnly || view.sort != LibrarySort.added;
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
                  decoration: const InputDecoration(hintText: 'Cari di favorit…', border: InputBorder.none),
                  onChanged: (_) => setState(() {}),
                )
              : const Text('Favorit'),
          actions: [
            IconButton(
              tooltip: _searching ? 'Tutup pencarian' : 'Cari',
              icon: Icon(_searching ? Icons.close : Icons.search),
              onPressed: () => setState(() {
                _searching = !_searching;
                if (!_searching) _search.clear();
              }),
            ),
            IconButton(
              tooltip: 'Filter & urutan',
              icon: Badge(isLabelVisible: filtered, smallSize: 8, child: const Icon(Icons.filter_list)),
              onPressed: _openFilter,
            ),
            IconButton(
              tooltip: 'Pembaruan',
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
                if (v == 'categories') {
                  showDialog<void>(context: context, useRootNavigator: true, builder: (_) => const _CategoriesDialog());
                }
              },
              itemBuilder: (_) => const [PopupMenuItem(value: 'categories', child: Text('Kelola kategori'))],
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
        body: favorites.isEmpty
            ? const EmptyView(
                icon: Icons.favorite_outline,
                title: 'Belum ada favorit',
                message: 'Ketuk ikon hati di halaman detail seri untuk menyimpannya ke sini.',
              )
            : TabBarView(
                children: [
                  for (final c in tabs)
                    _FavoritesGrid(
                      entries: _apply(favorites, c, view, unread, lastRead),
                      unread: unread,
                      onLongPress: _openActions,
                    ),
                ],
              ),
      ),
    );
  }
}

class _FavoritesGrid extends ConsumerWidget {
  const _FavoritesGrid({required this.entries, required this.unread, required this.onLongPress});

  final List<SourceFavorite> entries;
  final Map<String, int> unread;
  final void Function(SourceFavorite) onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entries.isEmpty) {
      return const EmptyView(icon: Icons.filter_list_off, title: 'Tidak ada favorit yang cocok');
    }
    final theme = Theme.of(context);
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.5,
      ),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final entry = entries[i];
        final item = entry.item;
        final source = librarySourceInfo(ref, item.sourceId);
        final count = unread[item.key] ?? 0;
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.push(source.detailLocation(item.url)),
          onLongPress: () => onLongPress(entry),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  SourceCover(url: item.thumbnailUrl, headers: source.imageHeaders),
                  if (count > 0)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$count',
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimary),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                source.isNovel ? 'Novel · ${source.name}' : source.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ViewSheet extends ConsumerWidget {
  const _ViewSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(libraryViewProvider);
    final n = ref.read(libraryViewProvider.notifier);
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Jenis', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(spacing: 6, children: [
              for (final k in LibraryKind.values)
                ChoiceChip(label: Text(k.label), selected: view.kind == k, onSelected: (_) => n.set(kind: k)),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hanya yang ada bab baru belum dibaca'),
              value: view.unreadOnly,
              onChanged: (v) => n.set(unreadOnly: v),
            ),
            Text('Urutkan', style: theme.textTheme.titleSmall),
            RadioGroup<LibrarySort>(
              groupValue: view.sort,
              onChanged: (v) => n.set(sort: v),
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
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Belum ada kategori'),
                subtitle: Text('Buat kategori di bawah untuk mengelompokkan favorit.'),
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
              title: const Text('Kategori baru'),
              onTap: () async {
                final name = await _askName(context, title: 'Kategori baru');
                if (name == null) return;
                if (await ref.read(libraryCategoriesProvider.notifier).add(name)) {
                  await favorites.setCategories(entry.item.key, [...current, name.trim()]);
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.heart_broken_outlined),
              title: const Text('Hapus dari favorit'),
              onTap: () {
                final messenger = ScaffoldMessenger.of(context);
                favorites.remove(entry.item.key);
                Navigator.pop(context);
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                    content: Text('"${entry.item.title}" dihapus dari favorit'),
                    action: SnackBarAction(label: 'Urungkan', onPressed: () => favorites.restore(entry)),
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
      title: const Text('Kategori'),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: categories.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Belum ada kategori. Kategori jadi tab di halaman Favorit.'),
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
                        children: [
                          IconButton(
                            tooltip: 'Naik',
                            icon: const Icon(Icons.arrow_upward, size: 20),
                            onPressed: i == 0 ? null : () => n.move(categories[i], -1),
                          ),
                          IconButton(
                            tooltip: 'Ganti nama',
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () async {
                              final name = await _askName(context, title: 'Ganti nama', initial: categories[i]);
                              if (name != null) await n.rename(categories[i], name);
                            },
                          ),
                          IconButton(
                            tooltip: 'Hapus',
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => n.remove(categories[i]),
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
            final name = await _askName(context, title: 'Kategori baru');
            if (name != null) await n.add(name);
          },
          child: const Text('Tambah'),
        ),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Selesai')),
      ],
    );
  }
}

Future<String?> _askName(BuildContext context, {required String title, String initial = ''}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Nama kategori'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Simpan')),
      ],
    ),
  );
}
