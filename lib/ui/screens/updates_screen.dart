import 'package:flutter/material.dart';
import '../../core/i18n/strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../state/background_updates.dart';
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
          found == 0 ? tr('Tidak ada bab baru') : trp('{found} bab baru', {'found': found}),
          if (failed.isNotEmpty) trp('{length} seri gagal dicek', {'length': failed.length}),
        ].join(' · ')),
      ));
    await notifier.markSeen();
  }

  Future<void> _backgroundDialog() async {
    var config = ref.read(backgroundUpdatesProvider);
    final result = await showDialog<BackgroundUpdateConfig>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(tr('Cek di latar belakang')),
          contentPadding: const EdgeInsets.only(top: 12),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioGroup<int>(
                  groupValue: config.hours,
                  onChanged: (v) => setState(() => config = config.copyWith(hours: v)),
                  child: Column(
                    children: [
                      for (final h in BackgroundUpdateConfig.choices)
                        RadioListTile<int>(value: h, title: Text(BackgroundUpdateConfig.label(h))),
                    ],
                  ),
                ),
                const Divider(),
                CheckboxListTile(
                  value: config.wifiOnly,
                  onChanged: config.enabled ? (v) => setState(() => config = config.copyWith(wifiOnly: v)) : null,
                  title: Text(tr('Hanya lewat Wi-Fi')),
                  subtitle: Text(tr('Juga dilewati saat baterai lemah')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Batal'))),
            FilledButton(onPressed: () => Navigator.pop(context, config), child: Text(tr('Simpan'))),
          ],
        ),
      ),
    );
    if (result != null) await ref.read(backgroundUpdatesProvider.notifier).set(result);
  }

  Future<void> _rulesDialog() async {
    var rules = ref.read(libraryUpdateRulesProvider);
    final categories = ref.read(libraryCategoriesProvider);
    final result = await showDialog<LibraryUpdateRules>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(tr('Aturan pembaruan')),
          contentPadding: const EdgeInsets.only(top: 12),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  value: rules.skipCompleted,
                  onChanged: (v) => setState(() => rules = rules.copyWith(skipCompleted: v)),
                  title: Text(tr('Lewati seri yang sudah tamat')),
                ),
                SwitchListTile(
                  value: rules.skipUnstarted,
                  onChanged: (v) => setState(() => rules = rules.copyWith(skipUnstarted: v)),
                  title: Text(tr('Lewati seri yang belum dibaca')),
                ),
                SwitchListTile(
                  value: rules.skipUnread,
                  onChanged: (v) => setState(() => rules = rules.copyWith(skipUnread: v)),
                  title: Text(tr('Lewati seri yang masih punya bab baru belum dibaca')),
                ),
                if (categories.isNotEmpty) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(tr('Jangan cek kategori'), style: Theme.of(context).textTheme.titleSmall),
                    ),
                  ),
                  for (final c in categories)
                    CheckboxListTile(
                      value: rules.excludedCategories.contains(c),
                      onChanged: (v) => setState(() => rules = rules.copyWith(
                            excludedCategories: v == true
                                ? [...rules.excludedCategories, c]
                                : rules.excludedCategories.where((x) => x != c).toList(),
                          )),
                      title: Text(c),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Batal'))),
            FilledButton(onPressed: () => Navigator.pop(context, rules), child: Text(tr('Simpan'))),
          ],
        ),
      ),
    );
    if (result != null) await ref.read(libraryUpdateRulesProvider.notifier).set(result);
  }

  static String _day(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return tr('Hari ini');
    if (diff == 1) return tr('Kemarin');
    return '${day.day.toString().padLeft(2, '0')}-${day.month.toString().padLeft(2, '0')}-${day.year}';
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(libraryUpdatesProvider);
    final favorites = ref.watch(sourceFavoritesProvider);
    final auto = ref.watch(libraryAutoCheckProvider);
    final background = ref.watch(backgroundUpdatesProvider);
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
        title: Text(tr('Pembaruan')),
        actions: [
          IconButton(
            tooltip: s.checking ? tr('Hentikan') : tr('Cek sekarang'),
            icon: Icon(s.checking ? Icons.stop : Icons.refresh),
            onPressed: s.checking ? ref.read(libraryUpdatesProvider.notifier).stop : _check,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'auto') ref.read(libraryAutoCheckProvider.notifier).set(!auto);
              if (v == 'clear') ref.read(libraryUpdatesProvider.notifier).clear();
              if (v == 'background') _backgroundDialog();
              if (v == 'rules') _rulesDialog();
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: 'auto',
                checked: auto,
                child: Text(tr('Cek otomatis saat aplikasi dibuka')),
              ),
              PopupMenuItem(
                value: 'background',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr('Cek di latar belakang')),
                  subtitle: Text(BackgroundUpdateConfig.label(background.hours) +
                      (background.enabled && background.wifiOnly ? ' · Wi-Fi' : '')),
                ),
              ),
              PopupMenuItem(value: 'rules', child: Text(tr('Aturan pembaruan'))),
              PopupMenuItem(value: 'clear', child: Text(tr('Hapus daftar pembaruan'))),
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
                    animation: s.checking
                        ? AppAnimation.sync
                        : favorites.isEmpty
                            ? AppAnimation.empty
                            : AppAnimation.success,
                    title: s.checking ? trp('Mengecek {done}/{total} favorit…', {'done': s.done, 'total': s.total}) : tr('Belum ada bab baru'),
                    message: favorites.isEmpty
                        ? tr('Tambahkan komik atau novel ke favorit; bab barunya akan muncul di sini.')
                        : trp('Tarik ke bawah untuk mengecek {n} favorit. Pengecekan pertama hanya mencatat bab yang sudah ada.', {'n': favorites.length}) +
                            (s.lastCheck != null ? '\n' + trp('Terakhir dicek {lastCheck}.', {'lastCheck': relativeTime(s.lastCheck!)}) : ''),
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
                          if (s.lastCheck != null) trp('Terakhir dicek {lastCheck}', {'lastCheck': relativeTime(s.lastCheck!)}),
                          if (s.failed.isNotEmpty) trp('{n} gagal: {list}', {'n': s.failed.length, 'list': s.failed.take(3).join(', ')}),
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
                      '${u.chapterName} · ${info.isNovel ? '${tr('Novel')} · ' : ''}${info.name}',
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
