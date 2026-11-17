import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../data/models/source_library.dart';
import '../../state/source_library_providers.dart';
import 'library_routing.dart';
import 'source_widgets.dart';

/// Baris "Lanjutkan membaca": bab terakhir dibuka dari komik dan novel,
/// satu ketukan untuk kembali ke bacaan.
class ContinueReadingStrip extends ConsumerWidget {
  const ContinueReadingStrip({super.key, this.limit = 8});

  final int limit;

  /// Entri yang ditampilkan: terbaru dulu, dibatasi [limit].
  static List<SourceHistoryEntry> pick(List<SourceHistoryEntry> history, {int limit = 8}) =>
      ([...history]..sort((a, b) => b.readAt.compareTo(a.readAt))).take(limit).toList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = pick(ref.watch(sourceHistoryProvider), limit: limit);
    if (entries.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Text(tr('Lanjutkan membaca'), style: theme.textTheme.titleSmall),
        ),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final entry = entries[i];
              final source = librarySourceInfo(ref, entry.item.sourceId);
              return SizedBox(
                width: 240,
                child: Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.push(source.readerLocation(entry.item.url, entry.chapterUrl)),
                    onLongPress: () => context.push(source.detailLocation(entry.item.url)),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          SourceCover(url: entry.item.thumbnailUrl, headers: source.imageHeaders, width: 44),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(entry.item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(
                                  entry.chapterName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}
