import 'dart:async';
import '../../../core/i18n/strings.dart';

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
import '../../widgets/source_widgets.dart';
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
  static const _parallel = 5;
  static const _timeout = Duration(seconds: 30);

  late final _controller = TextEditingController(text: widget.initialQuery);

  /// null = belum dipilih (ditentukan saat build pertama).
  ComicSearchScope? _scope;
  List<_SourceResult> _results = const [];
  int _run = 0;
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
        try {
          final page = await r.source.search(1, query).timeout(_timeout);
          r.items = page.items.toSet().toList();
        } catch (e) {
          r.error = e is TimeoutException ? 'Waktu habis' : toSourceException(e).title;
        }
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
          IconButton(tooltip: tr('Cari'), icon: const Icon(Icons.search), onPressed: _search),
          IconButton(
            tooltip: _onlyWithResults ? 'Tampilkan semua sumber' : 'Hanya sumber dengan hasil',
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
                        label: Text('Dipakai ($usedCount)'),
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
                        ? 'Belum ada sumber di favorit atau riwayat. Pilih bahasa di atas untuk mencari di semua sumber bahasa itu.'
                        : 'Mencari di $usedCount sumber yang ada di favorit atau riwayat. Pilih bahasa di atas untuk mencari lebih luas.',
                    LanguageScope(:final lang) =>
                      'Mencari di ${counts[lang] ?? 0} sumber ${languageName(lang)}. Sumber mati atau rusak dilewati.',
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
                          ? 'Mencari… $done/${_results.length} sumber · $found dengan hasil'
                          : '$found dari ${_results.length} sumber punya hasil',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  );
                }
                return _SourceRow(result: shown[i - 1]);
              },
            ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.result});

  final _SourceResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = result.source;
    final items = result.items;
    final status = result.loading
        ? 'mencari…'
        : result.error != null
            ? '${result.error}'
            : items!.isEmpty
                ? 'tidak ada hasil'
                : '${items.length} hasil';

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
              : const Icon(Icons.chevron_right),
          onTap: () => context.push(sourceBrowseLocation(source.id)),
        ),
        if (items != null && items.isNotEmpty)
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final m = items[i];
                return InkWell(
                  onTap: () => context.push(sourceMangaLocation(source.id, m.url)),
                  child: SizedBox(
                    width: 104,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SourceCover(url: m.thumbnailUrl, headers: source.imageHeaders(), width: 104),
                        const SizedBox(height: 4),
                        Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}
