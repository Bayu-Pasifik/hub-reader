import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/media_url.dart';
import '../../data/models/chapter.dart';
import '../../data/models/chapter_content.dart';
import '../../data/models/library_item.dart';
import '../../data/models/series.dart';
import '../../state/catalog_providers.dart';
import '../../state/core_providers.dart';
import '../../state/library_providers.dart';
import '../widgets/state_views.dart';

/// Pembaca bab. Tampilan dipilih berdasarkan konten yang tersedia:
///  - TextChapterContent  → pembaca teks novel native
///  - ImageChapterContent → pembaca komik vertikal (webtoon)
///  - null (kondisi saat ini, lihat TODO di chapter_content.dart)
///      → halaman sumber `Chapter.url` dibuka di WebView.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.type,
    required this.id,
    required this.initialChapter,
  });

  final SeriesType type;
  final int id;
  final double initialChapter;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late double _current = widget.initialChapter;
  double? _recordedFor;

  SeriesRef get _ref => (type: widget.type, id: widget.id);

  /// Data seri untuk riwayat: dari API/cache, atau dari entri lokal yang ada
  /// (agar riwayat tetap tercatat saat offline).
  LibraryItem? _libraryItem() {
    final series = ref.read(seriesDetailProvider(_ref)).valueOrNull?.data;
    if (series != null) return LibraryItem.fromSeries(series);
    for (final e in ref.read(historyProvider)) {
      if (e.item.type == widget.type && e.item.id == widget.id) return e.item;
    }
    for (final e in ref.read(favoritesProvider)) {
      if (e.item.type == widget.type && e.item.id == widget.id) return e.item;
    }
    return null;
  }

  void _recordHistory(Chapter chapter) {
    if (_recordedFor != null && chapter.isNumber(_recordedFor!)) return;
    final item = _libraryItem();
    if (item == null) return; // dicoba lagi saat detail selesai dimuat
    _recordedFor = chapter.number;
    // Ditunda ke setelah frame: provider tidak boleh diubah saat build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(historyProvider.notifier).record(item, chapter);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chapters = ref.watch(chaptersProvider(_ref));
    final series = ref.watch(seriesDetailProvider(_ref)).valueOrNull?.data;

    final list = chapters.valueOrNull?.data ?? const <Chapter>[];
    final index = list.indexWhere((c) => c.isNumber(_current));
    final chapter = index >= 0 ? list[index] : null;
    final prev = index > 0 ? list[index - 1] : null;
    final next = index >= 0 && index < list.length - 1 ? list[index + 1] : null;

    if (chapter != null) _recordHistory(chapter);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chapter?.label ?? 'Bab ${formatChapterNumber(_current)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (series != null)
              Text(
                series.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
      body: chapters.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(chaptersProvider(_ref)),
        ),
        data: (_) => chapter == null
            ? EmptyView(
                icon: Icons.find_in_page_outlined,
                title: 'Bab tidak ditemukan',
                message: 'Bab ${formatChapterNumber(_current)} tidak ada di daftar bab server.',
              )
            : _ChapterBody(seriesRef: _ref, chapter: chapter),
      ),
      bottomNavigationBar: chapter == null
          ? null
          : BottomAppBar(
              height: 64,
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: prev == null ? null : () => setState(() => _current = prev.number),
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Sebelumnya'),
                  ),
                  const Spacer(),
                  Text('${index + 1}/${list.length}'),
                  const Spacer(),
                  TextButton(
                    onPressed: next == null ? null : () => setState(() => _current = next.number),
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

class _ChapterBody extends ConsumerWidget {
  const _ChapterBody({required this.seriesRef, required this.chapter});

  final SeriesRef seriesRef;
  final Chapter chapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(chapterContentProvider(
      (type: seriesRef.type, id: seriesRef.id, number: chapter.number),
    ));

    return content.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      // Gagal mengambil konten native → tetap bisa dibaca dari sumber.
      error: (_, __) => _SourceWebView(chapter: chapter),
      data: (data) => switch (data) {
        TextChapterContent(:final paragraphs) when paragraphs.isNotEmpty =>
          _NovelTextReader(key: ValueKey(chapter.number), paragraphs: paragraphs),
        ImageChapterContent(:final pages) when pages.isNotEmpty =>
          _ComicImageReader(key: ValueKey(chapter.number), pages: pages),
        _ => _SourceWebView(chapter: chapter),
      },
    );
  }
}

/// Fallback: buka halaman bab di situs sumber.
class _SourceWebView extends StatefulWidget {
  const _SourceWebView({required this.chapter});

  final Chapter chapter;

  @override
  State<_SourceWebView> createState() => _SourceWebViewState();
}

class _SourceWebViewState extends State<_SourceWebView> {
  late final WebViewController _controller;
  int _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onPageStarted: (_) {
          if (mounted) setState(() => _error = null);
        },
        onWebResourceError: (error) {
          // Abaikan error iklan/gambar; hanya error dokumen utama yang fatal.
          if (error.isForMainFrame ?? true) {
            if (mounted) setState(() => _error = error.description);
          }
        },
      ));
    _load();
  }

  @override
  void didUpdateWidget(covariant _SourceWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapter.url != widget.chapter.url) _load();
  }

  /// Dipanggil dari initState/didUpdateWidget (build menyusul otomatis),
  /// jadi field diubah langsung tanpa setState.
  void _load() {
    final uri = Uri.tryParse(widget.chapter.url);
    if (uri == null || !uri.hasScheme) {
      _error = 'URL bab tidak valid: ${widget.chapter.url}';
      return;
    }
    _error = null;
    _progress = 0;
    _controller.loadRequest(uri);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: scheme.surfaceContainerHigh,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            widget.chapter.isLocked
                ? 'Bab ini terkunci di situs sumber; mungkin perlu login/membeli di sana.'
                : 'Ditampilkan dari situs sumber (API belum menyediakan isi bab).',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
        if (_progress < 100 && _error == null) LinearProgressIndicator(value: _progress / 100),
        Expanded(
          child: _error != null
              ? EmptyView(
                  icon: Icons.wifi_off_rounded,
                  title: 'Gagal memuat halaman sumber',
                  message: _error,
                  action: FilledButton.tonalIcon(
                    onPressed: () {
                      setState(() => _error = null);
                      _controller.reload();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba lagi'),
                  ),
                )
              : WebViewWidget(controller: _controller),
        ),
      ],
    );
  }
}

/// Siap dipakai saat endpoint isi bab novel tersedia.
class _NovelTextReader extends StatefulWidget {
  const _NovelTextReader({super.key, required this.paragraphs});

  final List<String> paragraphs;

  @override
  State<_NovelTextReader> createState() => _NovelTextReaderState();
}

class _NovelTextReaderState extends State<_NovelTextReader> {
  double _fontSize = 17;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
          itemCount: widget.paragraphs.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SelectableText(
              widget.paragraphs[i],
              style: TextStyle(fontSize: _fontSize, height: 1.6),
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: Card(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Perkecil teks',
                  onPressed: _fontSize <= 12 ? null : () => setState(() => _fontSize -= 1),
                  icon: const Icon(Icons.text_decrease),
                ),
                IconButton(
                  tooltip: 'Perbesar teks',
                  onPressed: _fontSize >= 28 ? null : () => setState(() => _fontSize += 1),
                  icon: const Icon(Icons.text_increase),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Siap dipakai saat endpoint isi bab komik tersedia.
class _ComicImageReader extends ConsumerWidget {
  const _ComicImageReader({super.key, required this.pages});

  final List<String> pages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final origin = ref.watch(apiOriginProvider);
    return InteractiveViewer(
      minScale: 1,
      maxScale: 3,
      child: ListView.builder(
        itemCount: pages.length,
        itemBuilder: (_, i) {
          final url = resolveMediaUrl(pages[i], origin);
          if (url == null) return const SizedBox(height: 200);
          return CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.fitWidth,
            placeholder: (_, __) => const SizedBox(
              height: 400,
              child: Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (_, __, ___) => SizedBox(
              height: 200,
              child: Center(child: Text('Halaman ${i + 1} gagal dimuat')),
            ),
          );
        },
      ),
    );
  }
}
