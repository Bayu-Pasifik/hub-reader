import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/repo_url.dart';
import '../../../sources/catalog_repository.dart';
import '../../../state/source_providers.dart';

/// Atur repo katalog sumber komik: tambah mirror/fork, urutkan prioritas,
/// hapus. Katalog bawaan aplikasi selalu ikut dipakai di bawah semua repo.
class SourceReposScreen extends ConsumerWidget {
  const SourceReposScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (clip != null && normalizeRepoUrl(clip) != null && clip.endsWith('.json')) controller.text = clip;
    if (!context.mounted) return;
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah repo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https://…/catalog.json',
            helperText: 'URL katalog sumber (format catalog.json hub_reader)',
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Tambah')),
        ],
      ),
    );
    controller.dispose();
    if (url == null || !context.mounted) return;
    final error = await ref.read(sourceCatalogReposProvider.notifier).add(url);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repos = ref.watch(sourceCatalogReposProvider);
    final state = ref.watch(sourceCatalogStateProvider);
    final theme = Theme.of(context);
    final counts = <String, int>{};
    var bundled = 0;
    for (final e in state.catalog.entries) {
      if (e.orphaned) continue;
      if (e.repo == null) {
        bundled++;
      } else {
        counts[e.repo!] = (counts[e.repo!] ?? 0) + 1;
      }
    }
    final orphans = state.catalog.orphans.length;
    final isDefault = repos.length == SourceCatalogReposNotifier.defaults.length &&
        repos.indexed.every((r) => SourceCatalogReposNotifier.defaults[r.$1] == r.$2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Repo sumber komik'),
        actions: [
          if (!isDefault)
            TextButton(
              onPressed: () => ref.read(sourceCatalogReposProvider.notifier).resetDefault(),
              child: const Text('Default'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(sourceCatalogStateProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            if (state.refreshing) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'Repo berisi daftar sumber (domain, template, opsi) dan bisa memperbarui domain sumber '
                'tanpa update aplikasi. Repo di atas diutamakan bila id sumber sama. Bila repo utama '
                'hilang, tambahkan mirror/fork-nya di sini. Sumber yang pernah didapat tetap tersimpan '
                'di HP walau repo-nya hilang.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (state.refreshError != null)
              ListTile(
                leading: Icon(Icons.cloud_off_outlined, color: theme.colorScheme.error),
                title: const Text('Gagal memperbarui sebagian repo'),
                subtitle: Text('Memakai salinan terakhir. ${state.refreshError}',
                    maxLines: 3, overflow: TextOverflow.ellipsis),
              ),
            for (final (i, url) in repos.indexed)
              ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(url == SourceCatalogRepository.defaultRepoUrl ? 'hub_reader (resmi)' : Uri.parse(url).host),
                subtitle: Text(
                  '${counts[url] == null ? 'belum dimuat' : '${counts[url]} sumber'} · $url',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (i > 0)
                      IconButton(
                        tooltip: 'Naikkan prioritas',
                        icon: const Icon(Icons.arrow_upward),
                        onPressed: () => ref.read(sourceCatalogReposProvider.notifier).moveUp(url),
                      ),
                    IconButton(
                      tooltip: 'Hapus',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ref.read(sourceCatalogReposProvider.notifier).remove(url),
                    ),
                  ],
                ),
                onLongPress: () {
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL disalin')));
                },
              ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.inventory_2_outlined, size: 20)),
              title: const Text('Katalog bawaan aplikasi'),
              subtitle: Text(
                bundled == 0
                    ? 'Semua sudah ada di repo · jadi cadangan bila repo hilang'
                    : '$bundled sumber tambahan · selalu dipakai, prioritas terendah',
              ),
            ),
            if (orphans > 0)
              ListTile(
                leading: Icon(Icons.history_toggle_off, color: Colors.orange.shade700),
                title: Text('$orphans sumber tersimpan tanpa repo'),
                subtitle: const Text('Sudah hilang dari repo, tapi datanya masih di HP dan tetap bisa dipakai.'),
                trailing: TextButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Lupakan sumber tanpa repo?'),
                        content: const Text(
                          'Sumber ini hilang dari daftar. Favorit dan riwayatnya tidak dihapus, '
                          'tapi tidak bisa dibuka sampai sumbernya muncul lagi di repo.',
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Lupakan')),
                        ],
                      ),
                    );
                    if (ok == true) await ref.read(sourceCatalogStateProvider.notifier).forgetOrphans();
                  },
                  child: const Text('Lupakan'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
