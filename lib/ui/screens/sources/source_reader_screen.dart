import 'dart:io';
import '../../../core/i18n/strings.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../core/platform/reader_bridge.dart';
import '../../../data/models/source_library.dart';
import '../../../sources/models.dart';
import '../../../sources/source.dart';
import '../../../state/bookmarks_provider.dart';
import '../../../state/download_providers.dart' show downloadIndexProvider;
import '../../../state/reader_settings_provider.dart';
import '../../../state/reading_stats_provider.dart';
import '../../../state/source_library_providers.dart';
import '../../../state/tracker_providers.dart';
import '../../../state/source_providers.dart';
import '../../widgets/cropped_page_image.dart';
import '../../widgets/reader_settings_sheet.dart';
import '../../widgets/source_widgets.dart';
import '../../widgets/state_views.dart';

/// Pembaca komik untuk sumber on-device: mode webtoon (vertikal) atau per
/// halaman (kiri→kanan / kanan→kiri), dengan halaman transisi ke bab berikutnya.
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

  void _goTo(SourceChapter chapter) => setState(() => _chapterUrl = chapter.url);

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(sourceProvider(widget.sourceId));
    final details = ref.watch(sourceDetailsProvider((sourceId: widget.sourceId, url: widget.mangaUrl)));
    final seriesKey = seriesReaderKey(widget.sourceId, widget.mangaUrl);
    final reader = ref.watch(effectiveReaderProvider(seriesKey));
    final mode = reader.mode;

    // Daftar situs: terbaru → terlama. "Berikutnya" = indeks lebih kecil.
    final chapters = details.valueOrNull?.chapters ?? const <SourceChapter>[];
    final index = chapters.indexWhere((c) => c.url == _chapterUrl);
    final chapter = index >= 0 ? chapters[index] : SourceChapter(url: _chapterUrl, name: 'Bab');
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
            if (manga != null)
              Text(
                manga.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          if (index >= 0)
            Builder(builder: (context) {
              final series = (sourceId: widget.sourceId, url: widget.mangaUrl);
              final marked = ref.watch(seriesBookmarksProvider(series)).contains(chapter.url);
              return IconButton(
                tooltip: marked ? 'Hapus bookmark' : 'Bookmark bab ini',
                icon: Icon(marked ? Icons.bookmark : Icons.bookmark_border),
                onPressed: () => ref.read(chapterBookmarksProvider.notifier).toggle(series, chapter.url),
              );
            }),
          IconButton(
            tooltip: tr('Pengaturan baca'),
            icon: const Icon(Icons.tune),
            onPressed: () => showReaderSettingsSheet(context, seriesKey),
          ),
        ],
      ),
      body: source == null
          ? EmptyView(title: tr('Sumber tidak ditemukan'))
          : _Pages(
              // Kunci menyertakan mode: ganti mode = posisi dibaca ulang dari progres.
              key: ValueKey('${chapter.url}|${mode.name}'),
              source: source,
              series: (sourceId: widget.sourceId, url: widget.mangaUrl),
              chapter: chapter,
              next: next,
              mode: mode,
              display: reader.display,
              onNext: next == null ? null : () => _goTo(next),
            ),
      bottomNavigationBar: index < 0
          ? null
          : BottomAppBar(
              height: 64,
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: prev == null ? null : () => _goTo(prev),
                    icon: const Icon(Icons.chevron_left),
                    label: Text(tr('Sebelumnya')),
                  ),
                  const Spacer(),
                  Text('${chapters.length - index}/${chapters.length}'),
                  const Spacer(),
                  TextButton(
                    onPressed: next == null ? null : () => _goTo(next),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [Text(tr('Berikutnya')), Icon(Icons.chevron_right)],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Pages extends ConsumerStatefulWidget {
  const _Pages({
    super.key,
    required this.source,
    required this.series,
    required this.chapter,
    required this.next,
    required this.mode,
    required this.display,
    required this.onNext,
  });

  final MangaSource source;
  final SourceItemKey series;
  final SourceChapter chapter;
  final SourceChapter? next;
  final ReaderMode mode;
  final ReaderDisplay display;
  final VoidCallback? onNext;

  @override
  ConsumerState<_Pages> createState() => _PagesState();
}

class _PagesState extends ConsumerState<_Pages> with SingleTickerProviderStateMixin {
  final _positions = ItemPositionsListener.create();
  final _offsetController = ScrollOffsetController();

  // ---- gulir otomatis (webtoon)
  late final Ticker _ticker = createTicker(_onTick);
  Duration _lastTick = Duration.zero;
  bool _autoScroll = false;
  bool _touching = false;

  /// Menjaga state PageView/list saat filter warna dinyalakan/dimatikan
  /// (pembungkus filter mengubah bentuk tree).
  final _bodyKey = GlobalKey();
  PageController? _pageController;
  int _current = 0;
  int? _saved;
  int _total = 0;
  bool _nextPrecached = false;

  /// Mulai pra-muat bab berikutnya saat tersisa sekian halaman.
  static const _preloadWithin = 3;

  /// Halaman awal: lanjut dari posisi tersimpan, kecuali bab sudah selesai.
  late final int _initialPage = () {
    final saved = ref.read(sourceSeriesProgressProvider(widget.series))[widget.chapter.url];
    return saved == null || saved.done ? 0 : saved.page;
  }();

  /// Lama membaca untuk statistik.
  late final ReadingSession _session = () {
    final stats = ref.read(readingStatsProvider.notifier);
    return ReadingSession(stats.addReadingTime);
  }();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _current = _initialPage;
    _positions.itemPositions.addListener(_onScroll);
    _session.activity();
    _lifecycle = AppLifecycleListener(onPause: _session.pause, onResume: _session.activity);
    ReaderBridge.setKeepScreenOn(widget.display.keepScreenOn);
  }

  @override
  void didUpdateWidget(covariant _Pages old) {
    super.didUpdateWidget(old);
    if (old.display.keepScreenOn != widget.display.keepScreenOn) {
      ReaderBridge.setKeepScreenOn(widget.display.keepScreenOn);
    }
  }

  void _toggleAutoScroll() {
    setState(() => _autoScroll = !_autoScroll);
    if (_autoScroll) {
      _lastTick = Duration.zero;
      _ticker.start();
    } else {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (_touching || dt <= 0 || dt > 0.5 || _total == 0) return;
    // Kartu transisi (indeks == _total) sudah terlihat penuh: berhenti.
    final atEnd = _positions.itemPositions.value.any((p) => p.index == _total && p.itemTrailingEdge <= 1.001);
    if (atEnd) {
      _toggleAutoScroll();
      return;
    }
    final speed = ref.read(webtoonAutoScrollSpeedProvider);
    try {
      _offsetController.animateScroll(offset: speed * dt, duration: const Duration(milliseconds: 16));
    } on Object {
      // list belum terpasang
    }
  }

  @override
  void dispose() {
    ReaderBridge.setKeepScreenOn(false);
    _ticker.dispose();
    _lifecycle.dispose();
    _session.pause();
    _positions.itemPositions.removeListener(_onScroll);
    _pageController?.dispose();
    // Hapus unduhan bab yang baru selesai dibaca (setelah reader tertutup
    // agar gambar yang sedang tampil tidak hilang).
    final index = ref.read(downloadIndexProvider.notifier);
    Future<void>.delayed(const Duration(seconds: 1), index.purgeRead);
    super.dispose();
  }

  /// Simpan posisi; dibandingkan dengan nilai tersimpan terakhir (bukan
  /// _current) supaya bab 1 halaman tetap tercatat selesai.
  void _setPage(int page) {
    _session.activity();
    if (page != _current) setState(() => _current = page);
    if (page == _saved || _total == 0) return;
    _saved = page;
    ref.read(sourceProgressProvider.notifier).update(widget.series, widget.chapter.url, page: page, total: _total);
    // Halaman terakhir: bab selesai, kirim progres ke tracker yang tertaut.
    if (page >= _total - 1) {
      ref.read(trackLinksProvider.notifier).chapterRead(
            '${widget.series.sourceId}|${widget.series.url}',
            widget.chapter.name,
            number: widget.chapter.number,
          );
    }
  }

  void _onScroll() {
    final visible = _positions.itemPositions.value
        // indeks == _total adalah kartu transisi, bukan halaman.
        .where((p) => p.index < _total && p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1);
    if (visible.isEmpty || _total == 0) return;
    final top = visible.map((p) => p.index).reduce((a, b) => a < b ? a : b);
    final bottom = visible.map((p) => p.index).reduce((a, b) => a > b ? a : b);
    _setPage(bottom >= _total - 1 ? _total - 1 : top);
  }

  void _onPageChanged(int index) {
    final spread = _spreadActive;
    // Indeks PageView: halaman biasa, atau spread (dua halaman) di tablet landscape.
    final count = spread ? spreadCount(_total) : _total;
    if (index >= count) {
      // Menggeser melewati halaman terakhir = niat lanjut; bab tetap
      // ditandai selesai lalu pindah ke bab berikutnya.
      _setPage(_total - 1);
      widget.onNext?.call();
      return;
    }
    // Spread dicatat sebagai halaman terakhirnya (supaya bab selesai terdeteksi).
    _setPage(spread ? pagesOfSpread(index, _total).last : index);
  }

  String _counter(int total) {
    if (!widget.mode.isPaged || !_spreadActive) return '${_current + 1} / $total';
    final pages = pagesOfSpread(spreadOfPage(_current), total);
    if (pages.length < 2) return '${_current + 1} / $total';
    return '${pages.first + 1}-${pages.last + 1} / $total';
  }

  /// True bila layar sedang menampilkan dua halaman berdampingan.
  bool _spreadActive = false;

  /// Controller diganti saat masuk/keluar mode spread (rotasi layar), dengan
  /// posisi dikonversi dari halaman yang sedang dibaca.
  /// Efek perpindahan halaman: [delta] = jarak halaman ini dari yang tampil
  /// (0 = di layar, ±1 = tepat di luar layar).
  Widget _transitioned(PageController controller, int index, Widget child) {
    final style = widget.display.transition;
    if (style == PageTransitionStyle.slide) return child;
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final page = controller.hasClients && controller.position.haveDimensions
            ? (controller.page ?? index.toDouble())
            : index.toDouble();
        final delta = (index - page).clamp(-1.0, 1.0);
        final away = delta.abs();
        switch (style) {
          case PageTransitionStyle.fade:
            return Opacity(opacity: 1 - away, child: child);
          case PageTransitionStyle.zoom:
            return Opacity(
              opacity: 1 - away * 0.6,
              child: Transform.scale(scale: 1 - away * 0.25, child: child),
            );
          case PageTransitionStyle.flip:
            return Transform(
              alignment: delta > 0 ? Alignment.centerLeft : Alignment.centerRight,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateY(delta * 1.1),
              child: child,
            );
          case PageTransitionStyle.slide:
            return child!;
        }
      },
    );
  }

  PageController _controllerFor(bool spread, int total) {
    if (_pageController != null && _spreadActive == spread) return _pageController!;
    final old = _pageController;
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    final page = _current.clamp(0, total == 0 ? 0 : total - 1);
    _spreadActive = spread;
    return _pageController = PageController(initialPage: spread ? spreadOfPage(page) : page);
  }

  /// Satu spread: dua halaman berdampingan, merapat di tengah (punggung buku).
  /// Mode kanan → kiri: halaman awal di kanan.
  Widget _spreadItem(int spread, List<String> urls, Map<String, String> headers) {
    final pages = pagesOfSpread(spread, urls.length);
    final rtl = widget.mode == ReaderMode.pagedRtl;
    Widget cell(int p, Alignment align, {int flex = 1}) => Expanded(
          flex: flex,
          child: Align(alignment: align, child: _image(urls[p], p, headers, BoxFit.contain)),
        );
    final Widget row;
    if (pages.length == 1) {
      // Sampul / halaman ganjil terakhir: setengah lebar di tengah.
      row = Row(children: [
        const Spacer(),
        cell(pages.first, Alignment.center, flex: 2),
        const Spacer(),
      ]);
    } else {
      // Urutan kiri→kanan di layar: LTR = (a, b); RTL = (b, a).
      final left = rtl ? pages[1] : pages[0];
      final right = rtl ? pages[0] : pages[1];
      row = Row(children: [cell(left, Alignment.centerRight), cell(right, Alignment.centerLeft)]);
    }
    return InteractiveViewer(minScale: 1, maxScale: 4, child: Center(child: row));
  }

  /// Ketuk sepertiga kiri/kanan layar untuk pindah halaman (mode per halaman).
  void _onTapPaged(TapUpDetails details, double width) {
    final controller = _pageController;
    if (controller == null || !controller.hasClients) return;
    final forward = ref
        .read(tapZonesProvider)
        .resolve(details.localPosition.dx, width, rtl: widget.mode == ReaderMode.pagedRtl);
    if (forward == null) return;
    const duration = Duration(milliseconds: 200);
    forward
        ? controller.nextPage(duration: duration, curve: Curves.easeOut)
        : controller.previousPage(duration: duration, curve: Curves.easeOut);
  }

  /// Ambil daftar halaman bab berikutnya + simpan 2 gambar pertama ke cache,
  /// supaya pindah bab terasa instan.
  void _preloadNext() {
    final next = widget.next;
    if (next == null || _total == 0 || _current < _total - _preloadWithin) return;
    final pages = ref.watch(sourcePagesProvider((sourceId: widget.source.id, chapter: next)));
    final urls = pages.valueOrNull;
    if (urls == null || _nextPrecached) return;
    _nextPrecached = true;
    final nextHeaders = widget.source.imageHeaders(referer: next.url);
    for (final url in urls.take(2).where((u) => u.startsWith('http'))) {
      precacheImage(CachedNetworkImageProvider(url, headers: nextHeaders), context).ignore();
    }
  }

  Widget _image(String url, int i, Map<String, String> headers, BoxFit fit) {
    if (widget.display.cropBorders) {
      final local = !url.startsWith('http');
      return CroppedPageImage(
        cacheKey: url,
        image: local ? FileImage(File(url)) : CachedNetworkImageProvider(url, headers: headers),
        vertical: widget.mode.isPaged,
        placeholder: (_) => const SizedBox(height: 400, child: LoadingView()),
        error: (_) => SizedBox(
          height: 200,
          child: Center(
              child: Text(local ? 'Halaman ${i + 1} gagal dibaca dari unduhan' : 'Halaman ${i + 1} gagal dimuat')),
        ),
      );
    }
    // Bab yang diunduh: path absolut di penyimpanan aplikasi.
    if (!url.startsWith('http')) {
      return Image.file(
        File(url),
        fit: fit,
        errorBuilder: (_, __, ___) => SizedBox(
          height: 200,
          child: Center(child: Text('Halaman ${i + 1} gagal dibaca dari unduhan')),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: headers,
      fit: fit,
      placeholder: (_, __) => const SizedBox(
        height: 400,
        child: LoadingView(),
      ),
      errorWidget: (_, __, ___) => SizedBox(
        height: 200,
        child: Center(child: Text('Halaman ${i + 1} gagal dimuat')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final key = (sourceId: widget.source.id, chapter: widget.chapter);
    final pages = ref.watch(sourcePagesProvider(key));
    // Banyak CDN menolak gambar tanpa Referer halaman bab.
    final headers = widget.source.imageHeaders(referer: widget.chapter.url);
    _preloadNext();

    return pages.when(
      loading: () => const LoadingView(),
      error: (error, _) => SourceErrorView(
        error: error,
        onRetry: () => ref.invalidate(sourcePagesProvider(key)),
        verifyUrl: widget.chapter.url,
      ),
      data: (urls) {
        _total = urls.length;
        final initial = _initialPage.clamp(0, urls.isEmpty ? 0 : urls.length - 1);
        final transition = _ChapterTransition(
          finished: widget.chapter,
          next: widget.next,
          onNext: widget.onNext,
        );

        final Widget body;
        if (widget.mode.isPaged) {
          if (_pageController == null) _current = initial;
          // Dua halaman hanya di layar lebar yang landscape (tablet). Dihitung
          // di sini (bukan di LayoutBuilder) agar penghitung halaman ikut berubah.
          final size = MediaQuery.sizeOf(context);
          final spread = widget.display.spread && size.width >= spreadMinWidth && size.width > size.height;
          final controller = _controllerFor(spread, urls.length);
          final units = spread ? spreadCount(urls.length) : urls.length;
          body = LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onTapUp: (d) => _onTapPaged(d, constraints.maxWidth),
                child: PageView.builder(
                  key: ValueKey(spread),
                  controller: controller,
                  reverse: widget.mode == ReaderMode.pagedRtl,
                  // Halaman transisi hanya bila ada bab berikutnya.
                  itemCount: units + (widget.next != null ? 1 : 0),
                  onPageChanged: _onPageChanged,
                  itemBuilder: (_, i) => i >= units
                      ? transition
                      : _transitioned(
                          controller,
                          i,
                          spread
                              ? _spreadItem(i, urls, headers)
                              : InteractiveViewer(
                                  minScale: 1,
                                  maxScale: 4,
                                  child: Center(child: _image(urls[i], i, headers, BoxFit.contain)),
                                ),
                        ),
                ),
              );
            },
          );
        } else {
          body = Listener(
            // Gulir otomatis jeda selama layar disentuh.
            onPointerDown: (_) => _touching = true,
            onPointerUp: (_) => _touching = false,
            onPointerCancel: (_) => _touching = false,
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 3,
              child: ScrollablePositionedList.builder(
                scrollOffsetController: _offsetController,
                itemCount: urls.length + 1,
                initialScrollIndex: initial,
                itemPositionsListener: _positions,
                // Pra-muat beberapa layar ke bawah.
                minCacheExtent: 2500,
                itemBuilder: (_, i) => i >= urls.length
                    ? SizedBox(height: 320, child: transition)
                    : _image(urls[i], i, headers, BoxFit.fitWidth),
              ),
            ),
          );
        }

        return Stack(
          children: [
            Positioned.fill(child: applyReaderFilters(widget.display, KeyedSubtree(key: _bodyKey, child: body))),
            if (!widget.mode.isPaged)
              Positioned(
                left: 12,
                bottom: 12,
                child: IconButton.filledTonal(
                  tooltip: _autoScroll ? 'Hentikan gulir otomatis' : 'Gulir otomatis',
                  icon: Icon(_autoScroll ? Icons.pause : Icons.keyboard_double_arrow_down),
                  onPressed: _toggleAutoScroll,
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
                      _counter(urls.length),
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

/// Kartu di akhir bab: "Selesai: X · Berikutnya: Y".
class _ChapterTransition extends StatelessWidget {
  const _ChapterTransition({required this.finished, required this.next, required this.onNext});

  final SourceChapter finished;
  final SourceChapter? next;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('Selesai'), style: theme.textTheme.labelLarge),
            Text(finished.name, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (next != null) ...[
              Text(tr('Berikutnya'), style: theme.textTheme.labelLarge),
              Text(next!.name, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onNext,
                icon: const Icon(Icons.skip_next),
                label: Text(tr('Lanjut ke bab berikutnya')),
              ),
            ] else
              Text(tr('Ini bab terbaru.'), style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
