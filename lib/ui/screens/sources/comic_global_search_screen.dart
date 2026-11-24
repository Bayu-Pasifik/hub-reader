import 'dart:async';
import '../../../core/i18n/strings.dart';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../sources/models.dart';
import '../../../sources/source.dart';
import '../../../sources/source_exception.dart';
import '../../../state/comic_global_search.dart';
import '../../../state/novel_providers.dart' show isNovelSourceId;
import '../../../state/source_health_provider.dart';
import '../../../state/source_library_providers.dart';
import '../../../state/source_providers.dart';
import '../../../state/source_settings_provider.dart';
import '../../router.dart';
import '../../../state/browse_layout_provider.dart';
import '../../widgets/browse_layout.dart';
import '../../widgets/cover_hero.dart';
import 'sources_screen.dart' show languageName;

/// Hasil pencarian satu sumber.
class _SourceResult {
  _SourceResult(this.source);

  final MangaSource source;
  List<SourceManga>? items;
  String? error;
  bool get loading => items == null && error == null;
}

/// Cari komik di banyak sumber sekaligus (seperti "Global search" Mihon):
/// sumber yang dipakai di favorit/riwayat, atau semua sumber satu bahasa.
class ComicGlobalSearchScreen extends ConsumerStatefulWidget {
  const ComicGlobalSearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<ComicGlobalSearchScreen> createState() => _ComicGlobalSearchScreenState();
}

class _ComicGlobalSearchScreenState extends ConsumerState<ComicGlobalSearchScreen> {
  /// Sumber yang dicari bersamaan.
  static const _parallel = 6;
  static const _timeout = Duration(seconds: 120);

  late final _controller = TextEditingController(text: widget.initialQuery);

  /// null = belum dipilih (ditentukan saat build pertama).
  ComicSearchScope? _scope;
  List<_SourceResult> _results = const [];
  int _run = 0;

  /// Membatalkan request pencarian yang masih jalan (tutup layar / cari ulang).
  CancelToken? _cancel;
  bool _onlyWithResults = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _run++;
    _cancel?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Sumber komik yang ada di favorit atau riwayat.
  Set<String> _usedIds() => {
        for (final f in ref.read(sourceFavoritesProvider)) f.item.sourceId,
        for (final h in ref.read(sourceHistoryProvider)) h.item.sourceId,
      }..removeWhere(isNovelSourceId);

  ComicSearchScope _defaultScope(Set<String> used, Map<String, int> langs) {
    if (used.isNotEmpty) return const UsedSourcesScope();
    if (langs.containsKey('id') || langs.isEmpty) return const LanguageScope('id');
    return LanguageScope(langs.keys.first);
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    final run = ++_run;
    _cancel?.cancel();
    final cancel = _cancel = CancelToken();
    final targets = comicSearchTargets(
      ref.read(sourceRegistryProvider).sources,
      scope: _scope ?? const UsedSourcesScope(),
      usedIds: _usedIds(),
      health: ref.read(sourceHealthProvider),
      showNsfw: ref.read(showNsfwSourcesProvider),
    );
    final results = [for (final s in targets) _SourceResult(s)];
    setState(() => _results = results);

    var next = 0;
    Future<void> worker() async {
      while (next < results.length && run == _run) {
        final r = results[next++];
        await _searchOne(r, query, cancel, run);
        if (mounted && run == _run) setState(() {});
      }
    }

    await Future.wait([for (var i = 0; i < _parallel; i++) worker()]);
    if (mounted && run == _run) {
      // Sumber dengan hasil di atas, lalu yang kosong, lalu yang gagal.
      int rank(_SourceResult r) => r.error != null ? 2 : (r.items!.isEmpty ? 1 : 0);
      setState(() => _results = [...results]..sort((a, b) => rank(a).compareTo(rank(b))));
    }
  }

  /// Cari satu sumber. Gagal karena sinyal lemot (timeout/tanpa koneksi) dicoba
  /// sekali lagi sebelum dianggap gagal, supaya jaringan lambat tidak menghabiskan hasil.
  Future<void> _searchOne(_SourceResult r, String query, CancelToken cancel, int run) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final page = await runCancellable(cancel, () => r.source.search(1, query)).timeout(_timeout);
        r.items = page.items.toSet().toList();
        r.error = null;
        return;
      } catch (e) {
        if (run != _run) return;
        final ex = e is TimeoutException ? const SourceException(SourceErrorKind.timeout) : toSourceException(e);
        final flaky = ex.kind == SourceErrorKind.timeout || ex.kind == SourceErrorKind.noConnection;
        r.error = e is TimeoutException ? tr('Waktu habis') : ex.title;
        if (!flaky) return;
      }
    }
  }

  /// Ulangi pencarian untuk satu sumber yang gagal (ketuk barisnya).
  Future<void> _retry(_SourceResult r) async {
    final query = _controller.text.trim();
    if (query.isEmpty || r.loading) return;
    final run = _run;
    final cancel = _cancel ??= CancelToken();
    setState(() {
      r.error = null;
      r.items = null;
    });
    await _searchOne(r, query, cancel, run);
    if (mounted && run == _run) setState(() {});
  }

  void _setScope(ComicSearchScope scope) {
    setState(() => _scope = scope);
    if (_controller.text.trim().isNotEmpty) _search();
  }

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(sourceRegistryProvider);
    final health = ref.watch(sourceHealthProvider);
    final showNsfw = ref.watch(showNsfwSourcesProvider);
    ref.watch(sourceFavoritesProvider);
    ref.watch(sourceHistoryProvider);

    final used = _usedIds();
    final usedCount = comicSearchTargets(
      registry.sources,
      scope: const UsedSourcesScope(),
      usedIds: used,
      health: health,
      showNsfw: showNsfw,
    ).length;
    final counts = comicSearchLanguages(registry.sources, health: health, showNsfw: showNsfw);
    final langs = counts.keys.toList()
      ..sort((a, b) {
        int rank(String l) => switch (l) { 'id' => 0, 'en' => 1, _ => 2 };
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : counts[b]!.compareTo(counts[a]!);
      });
    final scope = _scope ??= _defaultScope(used, counts);
    final scopeLang = switch (scope) { LanguageScope(:final lang) => lang, UsedSourcesScope() => null };

    final done = _results.where((r) => !r.loading).length;
    final found = _results.where((r) => r.items?.isNotEmpty ?? false).length;
    final shown = _onlyWithResults ? _results.where((r) => r.items?.isNotEmpty ?? false).toList() : _results;
    final searching = _results.isNotEmpty && done < _results.length;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: widget.initialQuery.isEmpty,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(hintText: tr('Cari komik di semua sumber…'), border: InputBorder.none),
          onSubmitted: (_) => _search(),
        ),
        actions: [
          IconButton(
            tooltip: tr('Tampilan'),
            icon: const Icon(Icons.grid_view_outlined),
            onPressed: () => showBrowseLayoutSheet(
              context,
              provider: comicBrowseLayoutProvider,
              title: tr('Tampilan hasil pencarian komik'),
            ),
          ),
          IconButton(tooltip: tr('Cari'), icon: const Icon(Icons.search), onPressed: _search),
          IconButton(
            tooltip: _onlyWithResults ? tr('Tampilkan semua sumber') : tr('Hanya sumber dengan hasil'),
            icon: Icon(_onlyWithResults ? Icons.filter_alt : Icons.filter_alt_outlined),
            onPressed: () => setState(() => _onlyWithResults = !_onlyWithResults),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(trp('Dipakai ({n})', {'n': usedCount})),
                        selected: scope is UsedSourcesScope,
                        onSelected: (_) => _setScope(const UsedSourcesScope()),
                      ),
                    ),
                    for (final l in langs)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text('${languageName(l)} (${counts[l]})'),
                          selected: scopeLang == l,
                          onSelected: (_) => _setScope(LanguageScope(l)),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 4,
                child: searching ? LinearProgressIndicator(value: done / _results.length) : null,
              ),
            ],
          ),
        ),
      ),
      body: _results.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  switch (scope) {
                    UsedSourcesScope() => usedCount == 0
                        ? tr('Belum ada sumber di favorit atau riwayat. Pilih bahasa di atas untuk mencari di semua sumber bahasa itu.')
                        : trp('Mencari di {usedCount} sumber yang ada di favorit atau riwayat. Pilih bahasa di atas untuk mencari lebih luas.', {'usedCount': usedCount}),
                    LanguageScope(:final lang) =>
                      trp('Mencari di {lang} sumber {lang2}. Sumber mati atau rusak dilewati.', {'lang': counts[lang] ?? 0, 'lang2': languageName(lang)}),
                  },
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              itemCount: shown.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                    child: Text(
                      searching
                          ? trp('Mencari… {done}/{length} sumber · {found} dengan hasil', {'done': done, 'length': _results.length, 'found': found})
                          : trp('{found} dari {length} sumber punya hasil', {'found': found, 'length': _results.length}),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  );
                }
                final row = shown[i - 1];
                return _SourceRow(result: row, onRetry: () => _retry(row));
              },
            ),
    );
  }
}

class _SourceRow extends ConsumerWidget {
  const _SourceRow({required this.result, required this.onRetry});

  final _SourceResult result;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final layout = ref.watch(comicBrowseLayoutProvider);
    final source = result.source;
    final items = result.items;
    final status = result.loading
        ? 'mencari…'
        : result.error != null
            ? '${result.error}'
            : items!.isEmpty
                ? tr('tidak ada hasil')
                : trp('{n} hasil', {'n': items.length});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          dense: true,
          title: Text(source.name, style: theme.textTheme.titleSmall),
          subtitle: Text(
            '${languageName(source.lang)} · $status',
            style: result.error != null ? TextStyle(color: theme.colorScheme.error) : null,
          ),
          trailing: result.loading
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : result.error != null
                  ? IconButton(tooltip: tr('Coba lagi'), icon: const Icon(Icons.refresh), onPressed: onRetry)
                  : const Icon(Icons.chevron_right),
          onTap: () => context.push(sourceBrowseLocation(source.id)),
        ),
        if (items != null && items.isNotEmpty)
          BrowseInline(
            layout: layout,
            headers: source.imageHeaders(),
            items: [
              for (var i = 0; i < items.length; i++)
                BrowseItem(
                  title: items[i].title,
                  cover: items[i].thumbnailUrl,
                  heroTag: coverHeroTagAt(items, i, source.id, (x) => x.url),
                  onTap: () => context.push(
                    sourceMangaLocation(source.id, items[i].url),
                    extra: SeriesPreview(title: items[i].title, coverUrl: items[i].thumbnailUrl),
                  ),
                ),
            ],
          ),
        const Divider(height: 1),
      ],
    );
  }
}
