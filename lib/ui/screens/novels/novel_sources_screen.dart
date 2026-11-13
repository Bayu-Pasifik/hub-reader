import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../novels/local_epub.dart';
import '../../../novels/novel_models.dart';
import '../../../novels/plugin_repository.dart';
import '../../../state/download_providers.dart';
import '../../../state/novel_health_provider.dart';
import '../../../state/novel_providers.dart';
import '../../../state/source_health_provider.dart';
import '../../router.dart';
import '../../widgets/local_import.dart';
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
          IconButton(
            tooltip: 'Cari novel di semua sumber',
            icon: const Icon(Icons.travel_explore),
            onPressed: () => context.push(novelGlobalSearchLocation()),
          ),
          IconButton(
            tooltip: 'Unduhan',
            icon: Badge(
              isLabelVisible: ref.watch(downloadQueueProvider).isNotEmpty,
              label: Text('${ref.watch(downloadQueueProvider).length}'),
              child: const Icon(Icons.download_outlined),
            ),
            onPressed: () => context.push('/downloads'),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              final health = ref.read(novelHealthProvider.notifier);
              switch (v) {
                case 'refresh':
                  ref.read(novelManifestProvider.notifier).refresh();
                case 'check':
                  final m = manifest.valueOrNull;
                  if (m == null) return;
                  final lang = selectedLang;
                  health.checkAll([
                    for (final p in m.plugins)
                      if (lang == null || p.lang == lang) p
                  ]);
                case 'stop':
                  health.stop();
                case 'hide':
                  ref.read(novelHideBrokenProvider.notifier).set(!ref.read(novelHideBrokenProvider));
                case 'repos':
                  context.push('/novel-repos');
                case 'settings':
                  context.push('/app-settings');
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'refresh', child: Text('Perbarui daftar plugin')),
              const PopupMenuItem(value: 'repos', child: Text('Repo plugin')),
              if (ref.read(novelHealthRunProvider).running)
                const PopupMenuItem(value: 'stop', child: Text('Hentikan pengecekan'))
              else
                PopupMenuItem(
                  value: 'check',
                  child: Text(selectedLang == null ? 'Cek semua plugin' : 'Cek plugin ${languageName(selectedLang)}'),
                ),
              CheckedPopupMenuItem(
                value: 'hide',
                checked: ref.read(novelHideBrokenProvider),
                child: const Text('Sembunyikan yang rusak'),
              ),
              const PopupMenuItem(value: 'settings', child: Text('Pengaturan')),
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

    final health = ref.watch(novelHealthProvider);
    final hideBroken = ref.watch(novelHideBrokenProvider);
    final run = ref.watch(novelHealthRunProvider);
    final hiddenCount = hideBroken ? filtered.where((p) => !novelUsable(health[p.id])).length : 0;
    if (hideBroken) filtered.removeWhere((p) => !novelUsable(health[p.id]));
    final rows = <Object>[];
    if (query.isEmpty && lang == null) rows.add(LocalNovelSource.pluginInfo);
    final used = filtered.where((p) => p.orphaned || installed.contains(NovelPluginRepository.safeId(p.id))).toList()
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
        if (run.running)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(child: LinearProgressIndicator(value: run.total == 0 ? null : run.done / run.total)),
                const SizedBox(width: 12),
                Text('Cek ${run.done}/${run.total}', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        if (hiddenCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              '$hiddenCount plugin rusak/mati disembunyikan',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (manifest.refreshError != null)
          MaterialBanner(
            content: const Text('Sebagian/semua repo plugin gagal dihubungi; memakai daftar tersimpan.'),
            actions: [
              TextButton(
                onPressed: () => context.push('/novel-repos'),
                child: const Text('Repo'),
              ),
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
                            'Plugin dari ${ref.watch(novelReposProvider).length} repo (atur di menu › Repo plugin), '
                            'dijalankan langsung di HP. Kode plugin diunduh saat sumber pertama kali dibuka '
                            'dan tetap bisa dipakai walau repo hilang.',
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
                      if (p.id == LocalNovelSource.pluginId) {
                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.folder_outlined)),
                          title: Text(p.name),
                          subtitle: const Text('File EPUB di perangkat'),
                          trailing: IconButton(
                            tooltip: 'Impor EPUB',
                            icon: const Icon(Icons.upload_file_outlined),
                            onPressed: () => importLocalFiles(context, epubOnly: true),
                          ),
                          onTap: () => context.push(novelBrowseLocation(p.id)),
                        );
                      }
                      return _PluginTile(plugin: p, health: health[p.id]);
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _PluginTile extends ConsumerWidget {
  const _PluginTile({required this.plugin, required this.health});

  final NovelPluginInfo plugin;
  final SourceHealth? health;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = plugin;
    final scheme = Theme.of(context).colorScheme;
    final status = health?.status;
    final (Color? color, IconData? icon) = switch (status) {
      HealthStatus.ok => (Colors.green.shade600, Icons.check_circle),
      HealthStatus.cloudflare => (Colors.orange.shade700, Icons.shield),
      HealthStatus.broken => (Colors.amber.shade800, Icons.warning_rounded),
      HealthStatus.dead => (scheme.error, Icons.cancel),
      null => (null, null),
    };
    final detail = health?.detail;
    final info = [
      if (p.orphaned) 'Hilang dari repo, tersimpan di HP',
      if (status != null) status.label + (status != HealthStatus.ok && detail != null ? ' ($detail)' : ''),
      if (p.host.isNotEmpty) p.host,
      'v${p.version}',
    ].join(' · ');
    final subtitleColor = color ?? (p.orphaned ? Colors.orange.shade700 : null);
    final tile = ListTile(
      leading: Badge(
        isLabelVisible: icon != null,
        backgroundColor: Colors.transparent,
        offset: const Offset(4, 26),
        label: icon == null ? null : Icon(icon, size: 16, color: color),
        child: _PluginIcon(url: p.iconUrl),
      ),
      title: Text(p.name),
      subtitle: Text(info, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: subtitleColor)),
      trailing: Text(p.lang.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
      onTap: () => context.push(novelBrowseLocation(p.id)),
      // Tekan lama = cek ulang plugin ini saja.
      onLongPress: () async {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(SnackBar(content: Text('Mengecek ${p.name}…'), duration: const Duration(seconds: 1)));
        final h = await ref.read(novelHealthProvider.notifier).check(p);
        final d = h.detail;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('${p.name}: ${h.status.label}${d != null ? ' ($d)' : ''}')));
      },
    );
    return status == HealthStatus.dead || status == HealthStatus.broken ? Opacity(opacity: 0.6, child: tile) : tile;
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
