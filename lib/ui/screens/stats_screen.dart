import 'package:flutter/material.dart';
import '../../core/i18n/strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/novel_providers.dart' show isNovelSourceId;
import '../../state/reading_stats_provider.dart';
import '../../state/source_library_providers.dart';

/// Statistik baca: lama membaca, bab selesai, rentetan hari, dan pustaka.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  static String duration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return m > 0 ? '$h j $m m' : '$h j';
    if (m > 0) return '$m m';
    return seconds > 0 ? '<1 m' : '0 m';
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Hapus statistik?')),
        content: Text(tr('Lama membaca dan hitungan bab per hari dihapus. Riwayat & tanda dibaca tidak berubah.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Batal'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Hapus'))),
        ],
      ),
    );
    if (ok == true) await ref.read(readingStatsProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(readingStatsProvider);
    final progress = ref.watch(sourceProgressProvider);
    final favorites = ref.watch(sourceFavoritesProvider);
    final history = ref.watch(sourceHistoryProvider);

    // Dari tanda dibaca (termasuk tandai manual), per seri.
    var comicDone = 0, novelDone = 0, seriesStarted = 0;
    final doneBySeries = <String, int>{};
    for (final series in progress.entries) {
      final done = series.value.values.where((p) => p.done).length;
      if (series.value.isNotEmpty) seriesStarted++;
      if (done == 0) continue;
      doneBySeries[series.key] = done;
      if (isNovelSourceId(series.key.split('|').first)) {
        novelDone += done;
      } else {
        comicDone += done;
      }
    }
    final titles = <String, String>{
      for (final h in history) h.item.key: h.item.title,
      for (final f in favorites) f.item.key: f.item.title,
    };
    final top = (doneBySeries.entries.where((e) => titles.containsKey(e.key)).toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .toList();
    final novelFavorites = favorites.where((f) => isNovelSourceId(f.item.sourceId)).length;

    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();

    Widget tile(String label, String value, {IconData? icon}) => Card.filled(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  if (icon != null) ...[Icon(icon, size: 16, color: scheme.onSurfaceVariant), const SizedBox(width: 6)],
                  Expanded(child: Text(label, style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant))),
                ]),
                const SizedBox(height: 6),
                Text(value, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );

    Widget grid(List<Widget> children) => LayoutBuilder(
          builder: (context, c) {
            const gap = 10.0;
            final w = (c.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [for (final child in children) SizedBox(width: w, child: child)],
            );
          },
        );

    Widget heading(String s) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
          child: Text(s, style: text.titleSmall?.copyWith(color: scheme.primary)),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Statistik')),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'reset') _confirmReset(context, ref);
            },
            itemBuilder: (_) => [PopupMenuItem(value: 'reset', child: Text(tr('Hapus statistik waktu baca')))],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          heading('Waktu baca'),
          grid([
            tile('Hari ini', duration(stats.secondsOn(now)), icon: Icons.today),
            tile('7 hari terakhir', duration(stats.secondsLast(7, now: now)), icon: Icons.date_range),
            tile('Total', duration(stats.totalSeconds), icon: Icons.timer_outlined),
            tile('Rentetan', '${stats.streak(now: now)} hari', icon: Icons.local_fire_department_outlined),
          ]),
          const SizedBox(height: 16),
          _DailyChart(stats: stats, now: now),
          heading('Bab'),
          grid([
            tile('Selesai dibaca', '${stats.totalComicChapters + stats.totalNovelChapters}',
                icon: Icons.check_circle_outline),
            tile('Ditandai dibaca', '${comicDone + novelDone}', icon: Icons.done_all),
            tile('Komik', '$comicDone', icon: Icons.photo_library_outlined),
            tile('Novel', '$novelDone', icon: Icons.menu_book_outlined),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              tr('"Selesai dibaca" dihitung sejak statistik ada; "ditandai" termasuk tanda manual di daftar bab.'),
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          heading('Pustaka'),
          grid([
            tile('Favorit komik', '${favorites.length - novelFavorites}', icon: Icons.favorite_border),
            tile('Favorit novel', '$novelFavorites', icon: Icons.favorite_border),
            tile('Seri dibuka', '$seriesStarted', icon: Icons.auto_stories_outlined),
            tile('Hari membaca', '${stats.activeDays}', icon: Icons.event_available_outlined),
          ]),
          if (top.isNotEmpty) ...[
            heading('Paling banyak dibaca'),
            Card.outlined(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, e) in top.indexed)
                    ListTile(
                      dense: true,
                      leading: CircleAvatar(radius: 14, child: Text('${i + 1}')),
                      title: Text(titles[e.key]!, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(isNovelSourceId(e.key.split('|').first) ? 'Novel' : 'Komik'),
                      trailing: Text('${e.value} bab', style: text.labelLarge),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Batang menit membaca per hari, 14 hari terakhir.
class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.stats, required this.now});

  final ReadingStats stats;
  final DateTime now;

  static const _days = 14;
  static const _weekdays = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final today = DateTime(now.year, now.month, now.day);
    final days = [for (var i = _days - 1; i >= 0; i--) today.subtract(Duration(days: i))];
    final values = [for (final d in days) stats.secondsOn(d)];
    final max = values.fold(0, (a, b) => a > b ? a : b);

    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('14 hari terakhir'), style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
            if (max > 0)
              Text('Terbanyak ${StatsScreen.duration(max)}', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            SizedBox(
              height: 110,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (i, d) in days.indexed)
                    Expanded(
                      child: Tooltip(
                        message: '${d.day}/${d.month}: ${StatsScreen.duration(values[i])}',
                        child: Semantics(
                          label: '${d.day}/${d.month}, ${StatsScreen.duration(values[i])}',
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                height: max == 0 ? 2 : 2 + 86 * values[i] / max,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  color: values[i] == 0
                                      ? scheme.surfaceContainerHighest
                                      : d == today
                                          ? scheme.primary
                                          : scheme.primary.withValues(alpha: 0.55),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _weekdays[d.weekday - 1],
                                style: text.labelSmall?.copyWith(
                                  color: d == today ? scheme.primary : scheme.onSurfaceVariant,
                                  fontWeight: d == today ? FontWeight.w700 : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
