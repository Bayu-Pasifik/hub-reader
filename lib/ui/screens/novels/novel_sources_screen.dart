import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../novels/novel_models.dart';
import '../../../novels/plugin_repository.dart';
import '../../../state/novel_providers.dart';
import '../../router.dart';
import '../../widgets/source_widgets.dart';
import '../../widgets/state_views.dart';
import '../sources/sources_screen.dart' show languageName;

/// Urutan bahasa: Indonesia, English, lalu sisanya menurut jumlah plugin.
List<String> _orderedLanguages(Map<String, int> counts) => counts.keys.toList()
  ..sort((a, b) {
    int rank(String l) => switch (l) { 'id' => 0, 'en' => 1, _ => 2 };
    final r = rank(a).compareTo(rank(b));
    return r != 0 ? r : counts[b]!.compareTo(counts[a]!);
  });

/// Tab "Novel": plugin LNReader (lnreader-plugins) per bahasa.
class NovelSourcesScreen extends ConsumerStatefulWidget {
  const NovelSourcesScreen({super.key});

  @override
  ConsumerState<NovelSourcesScreen> createState() => _NovelSourcesScreenState();
}

class _NovelSourcesScreenState extends ConsumerState<NovelSourcesScreen> {
  final _search = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manifest = ref.watch(novelManifestProvider);
    final selectedLang = ref.watch(novelLanguageProvider);
    final installed = ref.watch(novelInstalledProvider).valueOrNull ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Cari sumber novel…', border: InputBorder.none),
                onChanged: (_) => setState(() {}),
              )
            : const Text('Novel'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Tutup pencarian' : 'Cari sumber',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _search.clear();
            }),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'refresh') ref.read(novelManifestProvider.notifier).refresh();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'refresh', child: Text('Perbarui daftar plugin')),
            ],
          ),
        ],
      ),
      body: manifest.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => SourceErrorView(
          error: e,
          onRetry: () => ref.read(novelManifestProvider.notifier).refresh(),
        ),
        data: (m) => _buildList(context, m, selectedLang, installed),
      ),
    );
  }

  Widget _buildList(BuildContext context, NovelManifest manifest, String? selectedLang, Set<String> installed) {
    final counts = <String, int>{};
    for (final p in manifest.plugins) {
      counts[p.lang] = (counts[p.lang] ?? 0) + 1;
    }
    final languages = _orderedLanguages(counts);
    final lang = languages.contains(selectedLang) ? selectedLang : null;
    final query = _search.text.trim().toLowerCase();
    final filtered = manifest.plugins.where((p) {
      if (lang != null && p.lang != lang) return false;
      if (query.isEmpty) return true;
      return p.name.toLowerCase().contains(query) || p.site.toLowerCase().contains(query);
    }).toList();

    final rows = <Object>[];
    final used = filtered.where((p) => installed.contains(NovelPluginRepository.safeId(p.id))).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (used.isNotEmpty && query.isEmpty) {
      rows.add((title: 'Pernah dibuka', count: used.length));
      rows.addAll(used);
    }
    for (final l in languages) {
      final group = filtered.where((p) => p.lang == l).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (group.isEmpty) continue;
      rows.add((title: languageName(l), count: group.length));
      rows.addAll(group);
    }

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text('Semua (${manifest.plugins.length})'),
                  selected: lang == null,
                  onSelected: (_) => ref.read(novelLanguageProvider.notifier).set(null),
                ),
              ),
              for (final l in languages)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('${l.toUpperCase()} (${counts[l]})'),
                    selected: lang == l,
                    onSelected: (_) => ref.read(novelLanguageProvider.notifier).set(l),
                  ),
                ),
            ],
          ),
        ),
        if (manifest.refreshError != null)
          MaterialBanner(
            content: const Text('Gagal memperbarui daftar plugin; memakai daftar tersimpan.'),
            actions: [
              TextButton(
                onPressed: () => ref.read(novelManifestProvider.notifier).refresh(),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        Expanded(
          child: rows.isEmpty
              ? const EmptyView(icon: Icons.search_off_rounded, title: 'Tidak ada sumber yang cocok')
              : RefreshIndicator(
                  onRefresh: () => ref.read(novelManifestProvider.notifier).refresh(),
                  child: ListView.builder(
                    itemCount: rows.length + 1,
                    itemBuilder: (context, i) {
                      if (i == rows.length) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          child: Text(
                            'Plugin dari github.com/lnreader/lnreader-plugins, dijalankan langsung di HP. '
                            'Kode plugin diunduh saat sumber pertama kali dibuka.',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      final row = rows[i];
                      if (row is ({String title, int count})) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Text(
                            '${row.title} · ${row.count}',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        );
                      }
                      final p = row as NovelPluginInfo;
                      return ListTile(
                        leading: _PluginIcon(url: p.iconUrl),
                        title: Text(p.name),
                        subtitle: Text('${p.host} · v${p.version}', maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Text(p.lang.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
                        onTap: () => context.push(novelBrowseLocation(p.id)),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _PluginIcon extends StatelessWidget {
  const _PluginIcon({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.menu_book_outlined, size: 20, color: scheme.onSurfaceVariant),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 40,
        height: 40,
        child: url == null
            ? fallback
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}
