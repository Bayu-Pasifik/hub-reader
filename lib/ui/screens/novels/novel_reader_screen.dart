import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/reader_bridge.dart';
import '../../../data/models/source_library.dart';
import '../../../novels/novel_models.dart';
import '../../../novels/novel_source.dart';
import '../../../novels/novel_tts.dart';
import '../../../state/app_settings_provider.dart';
import '../../../sources/models.dart';
import '../../../state/novel_providers.dart';
import '../../../state/reading_stats_provider.dart';
import '../../../state/source_library_providers.dart';
import '../../../state/tracker_providers.dart';
import '../../router.dart';
import '../../widgets/novel_html.dart';
import '../../widgets/source_widgets.dart';
import 'novel_detail_screen.dart';

/// Pembaca novel: teks bab dengan gaya sendiri (ukuran huruf, tema), posisi
/// baca tersimpan per bab, dan pindah bab sebelumnya/berikutnya.
class NovelReaderScreen extends ConsumerStatefulWidget {
  const NovelReaderScreen({
    super.key,
    required this.pluginId,
    required this.novelPath,
    required this.chapterPath,
    this.page = 1,
  });

  final String pluginId;
  final String novelPath;
  final String chapterPath;

  /// Halaman daftar bab tempat bab ini berada (plugin berhalaman).
  final int page;

  @override
  ConsumerState<NovelReaderScreen> createState() => _NovelReaderScreenState();
}

class _NovelReaderScreenState extends ConsumerState<NovelReaderScreen> with SingleTickerProviderStateMixin {
  late String _chapterPath = widget.chapterPath;
  late int _page = widget.page;
  final _scroll = ScrollController();
  bool _chrome = true;
  Timer? _saveTimer;
  String? _restoredFor;
  String? _recordedFor;

  // ---- TTS
  final _tts = NovelTts();
  List<GlobalKey> _blockKeys = const [];
  List<NovelBlock> _blocks = const [];
  String? _blocksFor;
  int _lastTtsIndex = -1;

  /// Bab berikutnya sedang dimuat untuk dilanjutkan TTS.
  bool _ttsContinue = false;
  List<NovelChapter> _chapters = const [];
  int _totalPages = 1;
  bool _hasNext = false;

  /// Jarak tarik (overscroll) di akhir bab, untuk lanjut otomatis.
  double _pull = 0;
  static const _pullToNext = 140.0;

  // ---- gulir otomatis
  late final Ticker _ticker = createTicker(_onTick);
  Duration _lastTick = Duration.zero;
  bool _autoScroll = false;
  bool _dragging = false;

  /// Bab yang sudah memicu pindah otomatis (cegah pemicu ganda saat memuat).
  String? _advancedFrom;

  SourceItemKey get _libKey => (sourceId: novelLibraryId(widget.pluginId), url: widget.novelPath);

  /// Lama membaca untuk statistik (gulir, auto-scroll, TTS).
  late final ReadingSession _session = () {
    final stats = ref.read(readingStatsProvider.notifier);
    return ReadingSession(stats.addReadingTime);
  }();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _session.activity();
    _lifecycle = AppLifecycleListener(onPause: _session.pause, onResume: _session.activity);
    _scroll.addListener(_onScroll);
    _tts.addListener(_onTts);
    _tts.onChapterEnd = _onTtsChapterEnd;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _applyPlatform(ref.read(novelReaderSettingsProvider));
  }

  /// Layar tetap menyala & tombol volume sesuai pengaturan.
  void _applyPlatform(NovelReaderSettings s) {
    ReaderBridge.setKeepScreenOn(s.keepScreenOn);
    ReaderBridge.setVolumeKeys(s.volumeKeys ? _onVolumeKey : null);
  }

  /// Volume turun: satu layar ke bawah (di akhir bab: bab berikutnya).
  /// Volume naik: satu layar ke atas.
  void _onVolumeKey(bool down) {
    if (!mounted || !_scroll.hasClients) return;
    final pos = _scroll.position;
    final step = pos.viewportDimension * 0.85;
    if (down && pos.extentAfter <= 1) {
      if (_hasNext) _step(1, _chapters, _totalPages);
      return;
    }
    final target = (pos.pixels + (down ? step : -step)).clamp(pos.minScrollExtent, pos.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  void _toggleAutoScroll() {
    setState(() => _autoScroll = !_autoScroll);
    if (_autoScroll) {
      _lastTick = Duration.zero;
      _ticker.start();
      setState(() => _chrome = false);
    } else {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (!_scroll.hasClients || _dragging || dt <= 0 || dt > 0.5) return;
    final pos = _scroll.position;
    if (pos.extentAfter <= 0) {
      if (_advancedFrom == _chapterPath) return;
      if (ref.read(novelReaderSettingsProvider).autoNext && _hasNext) {
        _advancedFrom = _chapterPath;
        _step(1, _chapters, _totalPages);
      } else {
        _toggleAutoScroll();
      }
      return;
    }
    final speed = ref.read(novelReaderSettingsProvider).autoScrollSpeed;
    _scroll.jumpTo((pos.pixels + speed * dt).clamp(pos.minScrollExtent, pos.maxScrollExtent));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _session.pause();
    _saveTimer?.cancel();
    _saveProgress();
    _tts.dispose();
    _ticker.dispose();
    ReaderBridge.setVolumeKeys(null);
    ReaderBridge.setKeepScreenOn(false);
    _scroll.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  double get _fraction {
    if (!_scroll.hasClients) return 0;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return 1;
    return (_scroll.offset / max).clamp(0.0, 1.0);
  }

  void _onScroll() {
    _session.activity();
    if (_chrome && _scroll.position.userScrollDirection != ScrollDirection.idle) {
      setState(() => _chrome = false);
    }
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _saveProgress);
  }

  /// Progres disimpan sebagai persen (0–99), total 100; 99 = selesai.
  /// Bab ini selesai: kirim progres ke tracker yang tertaut (sekali per bab).
  String? _trackedFor;
  void _trackRead() {
    if (_trackedFor == _chapterPath) return;
    _trackedFor = _chapterPath;
    final c = _chapters.where((c) => c.path == _chapterPath).firstOrNull;
    final name = c?.name ?? ref.read(sourceLastReadProvider(_libKey))?.chapterName;
    if (name == null) return;
    ref.read(trackLinksProvider.notifier).chapterRead('${_libKey.sourceId}|${_libKey.url}', name, number: c?.number);
  }

  void _saveProgress() {
    if (!_scroll.hasClients || _restoredFor != _chapterPath) return;
    final percent = (_fraction * 100).floor().clamp(0, 99);
    if (percent >= 99) _trackRead();
    ref.read(sourceProgressProvider.notifier).update(_libKey, _chapterPath, page: percent, total: 100);
  }

  void _restorePosition(String path) {
    if (_restoredFor == path) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final p = ref.read(sourceSeriesProgressProvider(_libKey))[path];
      final max = _scroll.position.maxScrollExtent;
      if (p != null && !p.done && p.page > 0 && max > 0) _scroll.jumpTo(max * p.page / 100);
      _restoredFor = path;
    });
  }

  void _record(NovelChapter chapter) {
    if (_recordedFor == chapter.path) return;
    final details = ref.read(novelDetailsProvider((pluginId: widget.pluginId, path: widget.novelPath))).valueOrNull;
    final history = ref.read(sourceLastReadProvider(_libKey));
    final item = details != null
        ? SourceLibraryItem(
            sourceId: novelLibraryId(widget.pluginId),
            url: widget.novelPath,
            title: details.name,
            thumbnailUrl: details.cover,
          )
        : history?.item;
    if (item == null) return;
    _recordedFor = chapter.path;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sourceHistoryProvider.notifier).record(item, SourceChapter(url: chapter.path, name: chapter.name));
    });
  }

  // ------------------------------------------------------------------ TTS

  void _onTts() {
    _session.activity();
    if (!mounted) return;
    final i = _tts.index;
    setState(() {});
    if (i >= 0 && i != _lastTtsIndex && i < _blockKeys.length) {
      _lastTtsIndex = i;
      final ctx = _blockKeys[i].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, alignment: 0.25, duration: const Duration(milliseconds: 300));
      }
    }
    if (i < 0) _lastTtsIndex = -1;
  }

  List<String?> get _ttsTexts => [for (final b in _blocks) b is TextBlock ? b.plain : null];

  /// Blok pertama yang terlihat di layar (titik mulai TTS).
  int _firstVisibleBlock() {
    final top = MediaQuery.paddingOf(context).top + 64;
    for (var i = 0; i < _blockKeys.length; i++) {
      final box = _blockKeys[i].currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      if (y + box.size.height > top) return i;
    }
    return 0;
  }

  Future<void> _startTts({int? from}) async {
    if (_blocks.isEmpty) return;
    final settings = ref.read(novelReaderSettingsProvider);
    final lang = ref.read(novelManifestProvider).valueOrNull?.byId(widget.pluginId)?.lang;
    await _tts.configure(
      rate: settings.ttsRate,
      pitch: settings.ttsPitch,
      language: lang == null ? null : ttsLanguageFor(lang),
    );
    await _tts.start(_ttsTexts, from: from ?? _firstVisibleBlock());
  }

  void _onTtsChapterEnd() {
    if (!mounted) return;
    if (ref.read(novelReaderSettingsProvider).ttsAutoNext && _hasNext) {
      _ttsContinue = true;
      _step(1, _chapters, _totalPages);
    }
  }

  void _goTo(NovelChapter chapter, int page) {
    if (!_ttsContinue) _tts.stop();
    _saveProgress();
    saveNovelLastPage(ref, widget.pluginId, widget.novelPath, page);
    setState(() {
      _chapterPath = chapter.path;
      _page = page;
      _restoredFor = null;
      _chrome = true;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// Tarik melewati akhir bab: pindah ke bab berikutnya.
  bool _onScrollNotification(ScrollNotification n) {
    // Gulir otomatis berhenti sejenak selama layar disentuh.
    if (n is ScrollStartNotification && n.dragDetails != null) _dragging = true;
    if (n is ScrollEndNotification) _dragging = false;
    if (!ref.read(novelReaderSettingsProvider).autoNext || !_hasNext) return false;
    if (n is OverscrollNotification && n.overscroll > 0 && n.metrics.extentAfter == 0) {
      setState(() => _pull += n.overscroll);
      if (_pull >= _pullToNext) {
        _pull = 0;
        _step(1, _chapters, _totalPages);
      }
    } else if (n is ScrollEndNotification && _pull > 0) {
      setState(() => _pull = 0);
    }
    return false;
  }

  /// Bab sebelum/sesudah dalam urutan plugin (lama → baru), lintas halaman.
  Future<void> _step(int delta, List<NovelChapter> chapters, int totalPages) async {
    // Maju ke bab berikutnya = bab ini selesai dibaca.
    if (delta > 0 && !ref.read(appSettingsProvider).incognito) {
      ref.read(sourceProgressProvider.notifier).setDone(_libKey, _chapterPath, done: true);
      _trackRead();
    }
    final i = chapters.indexWhere((c) => c.path == _chapterPath);
    final j = i + delta;
    if (i >= 0 && j >= 0 && j < chapters.length) return _goTo(chapters[j], _page);
    final targetPage = _page + delta;
    if (targetPage < 1 || targetPage > totalPages) return;
    try {
      final list = await ref.read(
        novelChapterPageProvider((pluginId: widget.pluginId, path: widget.novelPath, page: targetPage)).future,
      );
      if (list.isEmpty || !mounted) return;
      _goTo(delta > 0 ? list.first : list.last, targetPage);
    } catch (_) {
      // tombol cukup tidak melakukan apa-apa
    }
  }

  Color _bg(NovelReaderTheme t, ColorScheme scheme) => switch (t) {
        NovelReaderTheme.system => scheme.surface,
        NovelReaderTheme.light => const Color(0xFFFFFFFF),
        NovelReaderTheme.sepia => const Color(0xFFF4ECD8),
        NovelReaderTheme.dark => const Color(0xFF1E1F22),
        NovelReaderTheme.black => const Color(0xFF000000),
      };

  Color _fg(NovelReaderTheme t, ColorScheme scheme) => switch (t) {
        NovelReaderTheme.system => scheme.onSurface,
        NovelReaderTheme.light => const Color(0xFF1B1B1B),
        NovelReaderTheme.sepia => const Color(0xFF5B4636),
        NovelReaderTheme.dark => const Color(0xFFD7D7D7),
        NovelReaderTheme.black => const Color(0xFFBDBDBD),
      };

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(novelReaderSettingsProvider);
    ref.listen(novelReaderSettingsProvider, (prev, next) {
      if (prev?.volumeKeys != next.volumeKeys || prev?.keepScreenOn != next.keepScreenOn) _applyPlatform(next);
    });
    final source = ref.watch(novelSourceProvider(widget.pluginId)).valueOrNull;
    final details = ref.watch(novelDetailsProvider((pluginId: widget.pluginId, path: widget.novelPath)));
    final chaptersAsync =
        ref.watch(novelChapterPageProvider((pluginId: widget.pluginId, path: widget.novelPath, page: _page)));
    final chapters = chaptersAsync.valueOrNull ?? const <NovelChapter>[];
    final totalPages = details.valueOrNull?.totalPages ?? 1;
    _chapters = chapters;
    _totalPages = totalPages;
    final content = ref.watch(novelChapterProvider((pluginId: widget.pluginId, path: _chapterPath)));
    final scheme = Theme.of(context).colorScheme;
    final bg = _bg(settings.theme, scheme);
    final fg = _fg(settings.theme, scheme);

    final index = chapters.indexWhere((c) => c.path == _chapterPath);
    final chapter = index >= 0
        ? chapters[index]
        : NovelChapter(path: _chapterPath, name: ref.read(sourceLastReadProvider(_libKey))?.chapterName ?? 'Bab');
    if (chaptersAsync.hasValue) _record(chapter);
    final hasPrev = index > 0 || (index == 0 && _page > 1);
    final hasNext = (index >= 0 && index < chapters.length - 1) || (index == chapters.length - 1 && _page < totalPages);
    _hasNext = hasNext;

    // Prefetch bab berikutnya agar pindah bab terasa instan.
    if (index >= 0 && index < chapters.length - 1 && content.hasValue) {
      ref.listen(novelChapterProvider((pluginId: widget.pluginId, path: chapters[index + 1].path)), (_, __) {});
    }

    final textStyle = TextStyle(
      fontSize: settings.fontSize,
      height: settings.lineHeight,
      color: fg,
      fontFamily: settings.font.family,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: bg,
        body: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => setState(() => _chrome = !_chrome),
                child: content.when(
                  loading: () => Center(child: CircularProgressIndicator(color: fg)),
                  error: (e, _) => SafeArea(
                    child: SourceErrorView(
                      error: novelError(e, site: source?.site),
                      verifyUrl: source?.site,
                      onRetry: () =>
                          ref.invalidate(novelChapterProvider((pluginId: widget.pluginId, path: _chapterPath))),
                    ),
                  ),
                  data: (html) {
                    if (_blocksFor != _chapterPath || _blocks.isEmpty && html.isNotEmpty) {
                      _blocks = parseNovelHtml(html, baseUrl: source == null ? null : Uri.tryParse(source.site));
                      _blockKeys = List.generate(_blocks.length, (_) => GlobalKey());
                      _blocksFor = _chapterPath;
                      if (_ttsContinue) {
                        _ttsContinue = false;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _startTts(from: 0);
                        });
                      }
                    }
                    final blocks = _blocks;
                    final ttsIndex = _tts.index;
                    _restorePosition(_chapterPath);
                    return NotificationListener<ScrollNotification>(
                      onNotification: _onScrollNotification,
                      child: SingleChildScrollView(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                        padding: EdgeInsets.fromLTRB(
                          settings.padding,
                          MediaQuery.paddingOf(context).top + 64,
                          settings.padding,
                          MediaQuery.paddingOf(context).bottom + 32,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Banyak situs sudah menulis judul bab di isi bab;
                            // judul dari daftar bab hanya ditampilkan bila beda.
                            if (!startsWithTitle(blocks, chapter.name))
                              Padding(
                                padding: EdgeInsets.only(bottom: settings.fontSize * 1.2),
                                child: Text(
                                  chapter.name,
                                  style: textStyle.copyWith(
                                      fontSize: settings.fontSize * 1.3, fontWeight: FontWeight.w700),
                                ),
                              ),
                            if (blocks.isEmpty)
                              Text('(Bab ini kosong)', style: textStyle)
                            else
                              for (var i = 0; i < blocks.length; i++)
                                Container(
                                  key: _blockKeys[i],
                                  decoration: i == ttsIndex
                                      ? BoxDecoration(
                                          color: scheme.primary.withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(6),
                                        )
                                      : null,
                                  child: NovelBlockView(
                                    block: blocks[i],
                                    style: textStyle,
                                    justify: settings.justify,
                                    imageHeaders: source?.imageHeaders ?? const {},
                                  ),
                                ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: hasPrev ? () => _step(-1, chapters, totalPages) : null,
                                    icon: const Icon(Icons.chevron_left),
                                    label: const Text('Sebelumnya'),
                                    style: OutlinedButton.styleFrom(foregroundColor: fg),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: hasNext ? () => _step(1, chapters, totalPages) : null,
                                    icon: const Icon(Icons.chevron_right),
                                    label: const Text('Berikutnya'),
                                  ),
                                ),
                              ],
                            ),
                            if (settings.autoNext && hasNext) ...[
                              const SizedBox(height: 16),
                              LinearProgressIndicator(value: (_pull / _pullToNext).clamp(0.0, 1.0), color: fg),
                              const SizedBox(height: 8),
                              Text(
                                'Tarik terus ke atas untuk lanjut ke bab berikutnya',
                                textAlign: TextAlign.center,
                                style: textStyle.copyWith(fontSize: 13, color: fg.withValues(alpha: 0.6)),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Bilah atas
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              top: _chrome ? 0 : -120,
              left: 0,
              right: 0,
              child: Material(
                color: scheme.surfaceContainer,
                elevation: 2,
                child: SafeArea(
                  bottom: false,
                  child: ListTile(
                    leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
                    title: Text(chapter.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      details.valueOrNull?.name ?? source?.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Buka di WebView',
                          icon: const Icon(Icons.public),
                          onPressed: source == null
                              ? null
                              : () async {
                                  final url = await source.webUrl(_chapterPath, isNovel: false);
                                  if (!context.mounted) return;
                                  final ok = await context.push<bool>(sourceWebViewLocation(url));
                                  if (ok == true) {
                                    ref.invalidate(
                                        novelChapterProvider((pluginId: widget.pluginId, path: _chapterPath)));
                                  }
                                },
                        ),
                        IconButton(
                          tooltip: 'Bacakan (TTS)',
                          icon: Icon(_tts.active ? Icons.stop_circle_outlined : Icons.headphones),
                          onPressed: content.hasValue ? () => _tts.active ? _tts.stop() : _startTts() : null,
                        ),
                        IconButton(
                          tooltip: _autoScroll ? 'Hentikan gulir otomatis' : 'Gulir otomatis',
                          icon: Icon(_autoScroll ? Icons.pause_circle_outline : Icons.keyboard_double_arrow_down),
                          onPressed: content.hasValue ? _toggleAutoScroll : null,
                        ),
                        IconButton(
                          tooltip: 'Tampilan',
                          icon: const Icon(Icons.text_fields),
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            showDragHandle: true,
                            isScrollControlled: true,
                            builder: (_) => const _ReaderSettingsSheet(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Bilah bawah
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              bottom: _chrome ? 0 : -120,
              left: 0,
              right: 0,
              child: Material(
                color: scheme.surfaceContainer,
                elevation: 2,
                child: SafeArea(
                  top: false,
                  child: _tts.active
                      ? _ttsBar(context)
                      : Row(
                          children: [
                            IconButton(
                              tooltip: 'Bab sebelumnya',
                              onPressed: hasPrev ? () => _step(-1, chapters, totalPages) : null,
                              icon: const Icon(Icons.skip_previous),
                            ),
                            Expanded(
                              child: Text(
                                index >= 0
                                    ? 'Bab ${index + 1} dari ${chapters.length}${totalPages > 1 ? ' · hal. $_page/$totalPages' : ''}'
                                    : '',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Bab berikutnya',
                              onPressed: hasNext ? () => _step(1, chapters, totalPages) : null,
                              icon: const Icon(Icons.skip_next),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on _NovelReaderScreenState {
  Widget _ttsBar(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
              tooltip: 'Paragraf sebelumnya', icon: const Icon(Icons.fast_rewind), onPressed: () => _tts.skip(-1)),
          IconButton.filled(
            tooltip: _tts.playing ? 'Jeda' : 'Lanjutkan',
            iconSize: 32,
            icon: Icon(_tts.playing ? Icons.pause : Icons.play_arrow),
            onPressed: () => _tts.playing ? _tts.pause() : _tts.resume(),
          ),
          IconButton(
              tooltip: 'Paragraf berikutnya', icon: const Icon(Icons.fast_forward), onPressed: () => _tts.skip(1)),
          IconButton(tooltip: 'Berhenti', icon: const Icon(Icons.stop), onPressed: _tts.stop),
        ],
      );
}

class _ReaderSettingsSheet extends ConsumerWidget {
  const _ReaderSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(novelReaderSettingsProvider);
    final n = ref.read(novelReaderSettingsProvider.notifier);
    const themes = {
      NovelReaderTheme.system: 'Sistem',
      NovelReaderTheme.light: 'Terang',
      NovelReaderTheme.sepia: 'Sepia',
      NovelReaderTheme.dark: 'Gelap',
      NovelReaderTheme.black: 'Hitam',
    };
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in themes.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: s.theme == e.key,
                  onSelected: (_) => n.update((x) => x.copyWith(theme: e.key)),
                ),
            ]),
            const SizedBox(height: 8),
            _slider(context, 'Ukuran huruf', s.fontSize, 12, 32, 20, (v) => n.update((x) => x.copyWith(fontSize: v)),
                s.fontSize.toStringAsFixed(0)),
            _slider(context, 'Jarak baris', s.lineHeight, 1.1, 2.4, 13,
                (v) => n.update((x) => x.copyWith(lineHeight: v)), s.lineHeight.toStringAsFixed(1)),
            _slider(context, 'Margin', s.padding, 6, 40, 17, (v) => n.update((x) => x.copyWith(padding: v)),
                s.padding.toStringAsFixed(0)),
            Row(
              children: [
                const SizedBox(width: 110, child: Text('Huruf')),
                Expanded(
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final f in NovelFont.values)
                      ChoiceChip(
                        label: Text(f.label, style: TextStyle(fontFamily: f.family)),
                        selected: s.font == f,
                        onSelected: (_) => n.update((x) => x.copyWith(font: f)),
                      ),
                  ]),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Rata kiri-kanan'),
              value: s.justify,
              onChanged: (v) => n.update((x) => x.copyWith(justify: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tarik di akhir bab untuk lanjut'),
              value: s.autoNext,
              onChanged: (v) => n.update((x) => x.copyWith(autoNext: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tombol volume untuk menggulir'),
              subtitle: const Text('Volume turun = halaman berikutnya'),
              value: s.volumeKeys,
              onChanged: (v) => n.update((x) => x.copyWith(volumeKeys: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Layar tetap menyala'),
              value: s.keepScreenOn,
              onChanged: (v) => n.update((x) => x.copyWith(keepScreenOn: v)),
            ),
            _slider(context, 'Gulir otomatis', s.autoScrollSpeed, 10, 200, 19,
                (v) => n.update((x) => x.copyWith(autoScrollSpeed: v)), s.autoScrollSpeed.toStringAsFixed(0)),
            const Divider(),
            Text('Suara (TTS)', style: Theme.of(context).textTheme.titleSmall),
            _slider(context, 'Kecepatan', s.ttsRate, 0.1, 1.0, 18, (v) => n.update((x) => x.copyWith(ttsRate: v)),
                '${(s.ttsRate * 2).toStringAsFixed(1)}x'),
            _slider(context, 'Nada', s.ttsPitch, 0.5, 2.0, 15, (v) => n.update((x) => x.copyWith(ttsPitch: v)),
                s.ttsPitch.toStringAsFixed(1)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Lanjut ke bab berikutnya'),
              value: s.ttsAutoNext,
              onChanged: (v) => n.update((x) => x.copyWith(ttsAutoNext: v)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider(BuildContext context, String label, double value, double min, double max, int divisions,
          ValueChanged<double> onChanged, String display) =>
      Row(
        children: [
          SizedBox(width: 110, child: Text(label)),
          Expanded(
            child: Slider(value: value.clamp(min, max), min: min, max: max, divisions: divisions, onChanged: onChanged),
          ),
          SizedBox(width: 36, child: Text(display, textAlign: TextAlign.end)),
        ],
      );
}
