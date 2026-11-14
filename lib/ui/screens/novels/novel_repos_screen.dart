import 'package:flutter/material.dart';
import '../../../core/i18n/strings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../novels/plugin_repository.dart';
import '../../../state/novel_providers.dart';

/// Atur repo plugin novel: tambah mirror/fork, urutkan prioritas, hapus.
class NovelReposScreen extends ConsumerWidget {
  const NovelReposScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (clip != null && NovelReposNotifier.normalize(clip) != null && clip.endsWith('.json')) {
      controller.text = clip;
    }
    if (!context.mounted) return;
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Tambah repo')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: 'https://…/plugins.min.json',
            helperText: tr('URL manifest bergaya lnreader-plugins'),
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Batal'))),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(tr('Tambah'))),
        ],
      ),
    );
    controller.dispose();
    if (url == null || !context.mounted) return;
    final error = await ref.read(novelReposProvider.notifier).add(url);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await ref.read(novelManifestProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repos = ref.watch(novelReposProvider);
    final manifest = ref.watch(novelManifestProvider).valueOrNull;
    final theme = Theme.of(context);
    final counts = <String, int>{};
    for (final p in manifest?.plugins ?? const []) {
      if (!p.orphaned && p.repo != null) counts[p.repo!] = (counts[p.repo!] ?? 0) + 1;
    }
    final orphans = manifest?.orphans.length ?? 0;
    final isDefault = repos.length == 1 && repos.first == NovelPluginRepository.defaultManifestUrl;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Repo plugin')),
        actions: [
          if (!isDefault)
            TextButton(
              onPressed: () async {
                await ref.read(novelReposProvider.notifier).resetDefault();
                await ref.read(novelManifestProvider.notifier).refresh();
              },
              child: Text(tr('Default')),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: Text(tr('Tambah')),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(novelManifestProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'Repo di atas diutamakan bila ada plugin dengan id sama. Bila repo utama dihapus, '
                'tambahkan mirror/fork-nya di sini. Plugin yang sudah pernah dibuka tetap tersimpan '
                'di HP walau repo-nya hilang.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (repos.isEmpty)
              ListTile(
                leading: Icon(Icons.info_outline),
                title: Text(tr('Belum ada repo')),
                subtitle: Text(tr('Hanya plugin yang tersimpan di HP yang tersedia.')),
              ),
            for (final (i, url) in repos.indexed)
              ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(
                  url == NovelPluginRepository.defaultManifestUrl ? 'LNReader (resmi)' : Uri.parse(url).host,
                ),
                subtitle: Text(
                  '${counts[url] == null ? 'belum dimuat' : '${counts[url]} plugin'} · $url',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (i > 0)
                      IconButton(
                        tooltip: tr('Naikkan prioritas'),
                        icon: const Icon(Icons.arrow_upward),
                        onPressed: () async {
                          await ref.read(novelReposProvider.notifier).moveUp(url);
                          await ref.read(novelManifestProvider.notifier).refresh();
                        },
                      ),
                    IconButton(
                      tooltip: tr('Hapus'),
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await ref.read(novelReposProvider.notifier).remove(url);
                        await ref.read(novelManifestProvider.notifier).refresh();
                      },
                    ),
                  ],
                ),
                onLongPress: () {
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('URL disalin'))));
                },
              ),
            if (orphans > 0)
              ListTile(
                leading: Icon(Icons.inventory_2_outlined, color: Colors.orange.shade700),
                title: Text('$orphans plugin tersimpan tanpa repo'),
                subtitle: Text(tr('Sudah hilang dari repo, tapi kodenya masih di HP dan tetap bisa dipakai.')),
              ),
          ],
        ),
      ),
    );
  }
}
