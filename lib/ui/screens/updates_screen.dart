import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../state/library_updates_provider.dart';
import '../../state/source_library_providers.dart';
import '../widgets/library_routing.dart';
import '../widgets/source_widgets.dart';
import '../widgets/state_views.dart';

/// Bab baru dari favorit (komik & novel), dikelompokkan per hari.
class UpdatesScreen extends ConsumerStatefulWidget {
  const UpdatesScreen({super.key});

  @override
  ConsumerState<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends ConsumerState<UpdatesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(libraryUpdatesProvider.notifier).markSeen());
  }

  Future<void> _check() async {
    final notifier = ref.read(libraryUpdatesProvider.notifier);
    final found = await notifier.checkAll();
    if (!mounted) return;
    final failed = ref.read(libraryUpdatesProvider).failed;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text([
          found == 0 ? 'Tidak ada bab baru' : '$found bab baru',
          if (failed.isNotEmpty) '${failed.length} seri gagal dicek',
        ].join(' · ')),
      ));
    await notifier.markSeen();
  }

  static String _day(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';
    return '${day.day.toString().padLeft(2, '0')}-${day.month.toString().padLeft(2, '0')}-${day.year}';
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(libraryUpdatesProvider);
    final favorites = ref.watch(sourceFavoritesProvider);
    final auto = ref.watch(libraryAutoCheckProvider);
    final progress = ref.watch(sourceProgressProvider);

    final rows = <Object>[];
    String? lastDay;
    for (final u in s.updates) {
      final day = _day(u.foundAt);
      if (day != lastDay) {
        rows.add(day);
        lastDay = day;
      }
      rows.add(u);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembaruan'),
        actions: [
          IconButton(
            tooltip: s.checking ? 'Hentikan' : 'Cek sekarang',
            icon: Icon(s.checking ? Icons.stop : Icons.refresh),
            onPressed: s.checking ? ref.read(libraryUpdatesProvider.notifier).stop : _check,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'auto') ref.read(libraryAutoCheckProvider.notifier).set(!auto);
              if (v == 'clear') ref.read(libraryUpdatesProvider.notifier).clear();
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: 'auto',
                checked: auto,
                child: const Text('Cek otomatis saat aplikasi dibuka'),
              ),
              const PopupMenuItem(value: 'clear', child: Text('Hapus daftar pembaruan')),
            ],
          ),
        ],
        bottom: s.checking
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(value: s.total == 0 ? null : s.done / s.total),
              )
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: _check,
        child: rows.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyView(
                    icon: Icons.new_releases_outlined,
                    title: s.checking ? 'Mengecek ${s.done}/${s.total} favorit…' : 'Belum ada bab baru',
                    message: favorites.isEmpty
                        ? 'Tambahkan komik atau novel ke favorit; bab barunya akan muncul di sini.'
                        : 'Tarik ke bawah untuk mengecek ${favorites.length} favorit. '
                            'Pengecekan pertama hanya mencatat bab yang sudah ada.'
                            '${s.lastCheck != null ? '\nTerakhir dicek ${relativeTime(s.lastCheck!)}.' : ''}',
                  ),
                ],
              )
            : ListView.builder(
                itemCount: rows.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        [
                          if (s.lastCheck != null) 'Terakhir dicek ${relativeTime(s.lastCheck!)}',
                          if (s.failed.isNotEmpty) '${s.failed.length} gagal: ${s.failed.take(3).join(', ')}',
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  }
                  final row = rows[i - 1];
                  if (row is String) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(row, style: Theme.of(context).textTheme.titleSmall),
                    );
                  }
                  final u = row as LibraryUpdate;
                  final info = librarySourceInfo(ref, u.item.sourceId);
                  final read = progress[u.item.key]?[u.chapterUrl]?.done ?? false;
                  final color = read ? Theme.of(context).disabledColor : null;
                  return ListTile(
                    leading: SizedBox(
                      width: 40,
                      child: SourceCover(url: u.item.thumbnailUrl, headers: info.imageHeaders, width: 40),
                    ),
                    title: Text(u.item.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color)),
                    subtitle: Text(
                      '${u.chapterName} · ${info.isNovel ? 'Novel · ' : ''}${info.name}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: color),
                    ),
                    trailing: read ? const Icon(Icons.done_all, size: 18) : null,
                    onTap: () => context.push(info.readerLocation(u.item.url, u.chapterUrl)),
                    onLongPress: () => context.push(info.detailLocation(u.item.url)),
                  );
                },
              ),
      ),
    );
  }
}
