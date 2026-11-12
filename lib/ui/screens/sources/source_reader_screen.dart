import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../data/models/source_library.dart';
import '../../../sources/models.dart';
import '../../../sources/source.dart';
import '../../../state/source_library_providers.dart';
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
  String? _recordedFor;

  /// Catat ke riwayat sekali per bab, setelah detail seri tersedia.
  void _recordHistory(SourceMangaDetails manga, SourceChapter chapter) {
    if (_recordedFor == chapter.url) return;
    _recordedFor = chapter.url;
    final item = SourceLibraryItem.fromDetails(widget.sourceId, widget.mangaUrl, manga);
    // Ditunda ke setelah frame: provider tidak boleh diubah saat build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(sourceHistoryProvider.notifier).record(item, chapter);
    });
  }

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
    final manga = details.valueOrNull;
    if (manga != null && index >= 0) _recordHistory(manga, chapter);

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
          : _Pages(
              key: ValueKey(chapter.url),
              source: source,
              series: (sourceId: widget.sourceId, url: widget.mangaUrl),
              chapter: chapter,
            ),
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

class _Pages extends ConsumerStatefulWidget {
  const _Pages({super.key, required this.source, required this.series, required this.chapter});

  final MangaSource source;
  final SourceItemKey series;
  final SourceChapter chapter;

  @override
  ConsumerState<_Pages> createState() => _PagesState();
}

class _PagesState extends ConsumerState<_Pages> {
  final _positions = ItemPositionsListener.create();
  int _current = 0;
  int? _saved;
  int _total = 0;

  /// Halaman awal: lanjut dari posisi tersimpan, kecuali bab sudah selesai.
  late final int _initialPage = () {
    final saved = ref.read(sourceSeriesProgressProvider(widget.series))[widget.chapter.url];
    return saved == null || saved.done ? 0 : saved.page;
  }();

  @override
  void initState() {
    super.initState();
    _current = _initialPage;
    _positions.itemPositions.addListener(_onScroll);
  }

  @override
  void dispose() {
    _positions.itemPositions.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final visible = _positions.itemPositions.value
        .where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1);
    if (visible.isEmpty || _total == 0) return;
    // Halaman "sekarang" = halaman teratas yang terlihat; bila halaman
    // terakhir sudah tampil, anggap selesai.
    final top = visible.map((p) => p.index).reduce((a, b) => a < b ? a : b);
    final bottom = visible.map((p) => p.index).reduce((a, b) => a > b ? a : b);
    final page = bottom >= _total - 1 ? _total - 1 : top;
    if (page != _current) setState(() => _current = page);
    // Dibandingkan dengan yang terakhir disimpan (bukan _current), supaya
    // bab 1 halaman tetap tercatat selesai pada event pertama.
    if (page == _saved) return;
    _saved = page;
    ref
        .read(sourceProgressProvider.notifier)
        .update(widget.series, widget.chapter.url, page: page, total: _total);
  }

  @override
  Widget build(BuildContext context) {
    final key = (sourceId: widget.source.id, chapter: widget.chapter);
    final pages = ref.watch(sourcePagesProvider(key));
    // Banyak CDN menolak gambar tanpa Referer halaman bab.
    final headers = widget.source.imageHeaders(referer: widget.chapter.url);

    return pages.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => SourceErrorView(
        error: error,
        onRetry: () => ref.invalidate(sourcePagesProvider(key)),
        verifyUrl: widget.chapter.url,
      ),
      data: (urls) {
        _total = urls.length;
        final initial = _initialPage.clamp(0, urls.isEmpty ? 0 : urls.length - 1);
        return Stack(
          children: [
            InteractiveViewer(
              minScale: 1,
              maxScale: 3,
              child: ScrollablePositionedList.builder(
                itemCount: urls.length,
                initialScrollIndex: initial,
                itemPositionsListener: _positions,
                // Pra-muat beberapa layar ke bawah.
                minCacheExtent: 2500,
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
            Positioned(
              right: 12,
              bottom: 12,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Text(
                      '${_current + 1} / ${urls.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12.5),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
