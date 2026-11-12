import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sources/models.dart';
import '../../../sources/source.dart';
import '../../../state/source_providers.dart';
import '../../widgets/source_widgets.dart';
import '../../widgets/state_views.dart';

/// Pembaca komik vertikal (webtoon) untuk sumber on-device.
class SourceReaderScreen extends ConsumerStatefulWidget {
  const SourceReaderScreen({
    super.key,
    required this.sourceId,
    required this.mangaUrl,
    required this.chapterUrl,
  });

  final String sourceId;
  final String mangaUrl;
  final String chapterUrl;

  @override
  ConsumerState<SourceReaderScreen> createState() => _SourceReaderScreenState();
}

class _SourceReaderScreenState extends ConsumerState<SourceReaderScreen> {
  late String _chapterUrl = widget.chapterUrl;

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(sourceProvider(widget.sourceId));
    final details = ref.watch(sourceDetailsProvider((sourceId: widget.sourceId, url: widget.mangaUrl)));

    // Daftar situs: terbaru → terlama. "Berikutnya" = indeks lebih kecil.
    final chapters = details.valueOrNull?.chapters ?? const <SourceChapter>[];
    final index = chapters.indexWhere((c) => c.url == _chapterUrl);
    final chapter = index >= 0
        ? chapters[index]
        : SourceChapter(url: _chapterUrl, name: 'Bab');
    final next = index > 0 ? chapters[index - 1] : null;
    final prev = index >= 0 && index < chapters.length - 1 ? chapters[index + 1] : null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chapter.name, style: Theme.of(context).textTheme.titleMedium),
            if (details.valueOrNull != null)
              Text(
                details.valueOrNull!.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
      body: source == null
          ? const EmptyView(title: 'Sumber tidak ditemukan')
          : _Pages(key: ValueKey(chapter.url), source: source, chapter: chapter),
      bottomNavigationBar: index < 0
          ? null
          : BottomAppBar(
              height: 64,
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: prev == null ? null : () => setState(() => _chapterUrl = prev.url),
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Sebelumnya'),
                  ),
                  const Spacer(),
                  Text('${chapters.length - index}/${chapters.length}'),
                  const Spacer(),
                  TextButton(
                    onPressed: next == null ? null : () => setState(() => _chapterUrl = next.url),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [Text('Berikutnya'), Icon(Icons.chevron_right)],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Pages extends ConsumerWidget {
  const _Pages({super.key, required this.source, required this.chapter});

  final MangaSource source;
  final SourceChapter chapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (sourceId: source.id, chapter: chapter);
    final pages = ref.watch(sourcePagesProvider(key));
    // Banyak CDN menolak gambar tanpa Referer halaman bab.
    final headers = source.imageHeaders(referer: chapter.url);

    return pages.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => SourceErrorView(
        error: error,
        onRetry: () => ref.invalidate(sourcePagesProvider(key)),
      ),
      data: (urls) => InteractiveViewer(
        minScale: 1,
        maxScale: 3,
        child: ListView.builder(
          itemCount: urls.length,
          // Pra-muat beberapa layar ke bawah.
          scrollCacheExtent: const ScrollCacheExtent.pixels(2500),
          itemBuilder: (_, i) => CachedNetworkImage(
            imageUrl: urls[i],
            httpHeaders: headers,
            fit: BoxFit.fitWidth,
            placeholder: (_, __) => const SizedBox(
              height: 400,
              child: Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (_, __, ___) => SizedBox(
              height: 200,
              child: Center(child: Text('Halaman ${i + 1} gagal dimuat')),
            ),
          ),
        ),
      ),
    );
  }
}
