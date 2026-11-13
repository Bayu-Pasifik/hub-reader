import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../novels/novel_models.dart';
import '../../../novels/novel_source.dart';
import '../../../state/novel_health_provider.dart';
import '../../../state/novel_providers.dart';
import '../../router.dart';
import '../../widgets/source_widgets.dart';
import '../sources/sources_screen.dart' show languageName;

/// Hasil pencarian satu plugin.
class _PluginResult {
  _PluginResult(this.info);

  final NovelPluginInfo info;
  List<NovelItem>? items;
  Object? error;
  bool get loading => items == null && error == null;
}

/// Cari novel di banyak plugin sekaligus (seperti "Cari global" LNReader):
/// plugin yang pernah dibuka, atau semua plugin satu bahasa.
class NovelGlobalSearchScreen extends ConsumerStatefulWidget {
  const NovelGlobalSearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<NovelGlobalSearchScreen> createState() => _NovelGlobalSearchScreenState();
}

class _NovelGlobalSearchScreenState extends ConsumerState<NovelGlobalSearchScreen> {
  /// Plugin yang dicari bersamaan.
  static const _parallel = 4;
  static const _timeout = Duration(seconds: 40);

  late final _controller = TextEditingController(text: widget.initialQuery);

  /// null = plugin yang pernah dibuka; selain itu kode bahasa.
  String? _scope;
  List<_PluginResult> _results = const [];
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

  Future<List<NovelPluginInfo>> _targets() async {
    final manifest = await ref.read(novelManifestProvider.future);
    // Plugin rusak/mati dilewati bila disembunyikan di tab Novel.
    final health = ref.read(novelHealthProvider);
    final skipBroken = ref.read(novelHideBrokenProvider);
    bool usable(NovelPluginInfo p) => !skipBroken || novelUsable(health[p.id]);
    if (_scope != null) return manifest.plugins.where((p) => p.lang == _scope && usable(p)).toList();
    final installed = await ref.read(novelInstalledProvider.future);
    return manifest.plugins.where((p) => installed.contains(_safe(p.id)) && usable(p)).toList();
  }

  static String _safe(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    final run = ++_run;
    final targets = await _targets();
    if (!mounted || run != _run) return;
    final results = [for (final p in targets) _PluginResult(p)];
    setState(() => _results = results);

    var next = 0;
    Future<void> worker() async {
      while (next < results.length && run == _run) {
        final r = results[next++];
        try {
          final source = await ref.read(novelSourceProvider(r.info.id).future).timeout(_timeout);
          r.items = await source.search(query, 1).timeout(_timeout);
        } catch (e) {
          r.error = e is TimeoutException ? 'Waktu habis' : novelError(e, site: r.info.site).title;
        }
        if (mounted && run == _run) setState(() {});
      }
    }

    await Future.wait([for (var i = 0; i < _parallel; i++) worker()]);
    if (mounted && run == _run) {
      // Plugin dengan hasil di atas, lalu yang kosong, lalu yang gagal.
      int rank(_PluginResult r) => r.error != null ? 2 : (r.items!.isEmpty ? 1 : 0);
      setState(() => _results = [...results]..sort((a, b) => rank(a).compareTo(rank(b))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final manifest = ref.watch(novelManifestProvider).valueOrNull;
    final installedCount = ref.watch(novelInstalledProvider).valueOrNull?.length ?? 0;
    final counts = <String, int>{};
    for (final p in manifest?.plugins ?? const <NovelPluginInfo>[]) {
      counts[p.lang] = (counts[p.lang] ?? 0) + 1;
    }
    final langs = counts.keys.toList()
      ..sort((a, b) {
        int rank(String l) => switch (l) { 'id' => 0, 'en' => 1, _ => 2 };
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : counts[b]!.compareTo(counts[a]!);
      });
    final done = _results.where((r) => !r.loading).length;
    final shown = _onlyWithResults ? _results.where((r) => r.items?.isNotEmpty ?? false).toList() : _results;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: widget.initialQuery.isEmpty,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(hintText: 'Cari novel di semua sumber…', border: InputBorder.none),
          onSubmitted: (_) => _search(),
        ),
        actions: [
          IconButton(tooltip: 'Cari', icon: const Icon(Icons.search), onPressed: _search),
          IconButton(
            tooltip: _onlyWithResults ? 'Tampilkan semua sumber' : 'Hanya sumber dengan hasil',
            icon: Icon(_onlyWithResults ? Icons.filter_alt : Icons.filter_alt_outlined),
            onPressed: () => setState(() => _onlyWithResults = !_onlyWithResults),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_results.isNotEmpty && done < _results.length ? 56 : 52),
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
                        label: Text('Pernah dibuka ($installedCount)'),
                        selected: _scope == null,
                        onSelected: (_) => setState(() => _scope = null),
                      ),
                    ),
                    for (final l in langs)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text('${languageName(l)} (${counts[l]})'),
                          selected: _scope == l,
                          onSelected: (_) => setState(() => _scope = l),
                        ),
                      ),
                  ],
                ),
              ),
              if (_results.isNotEmpty && done < _results.length)
                LinearProgressIndicator(value: done / _results.length),
            ],
          ),
        ),
      ),
      body: _results.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  _scope == null
                      ? 'Mencari di plugin yang pernah dibuka. Pilih bahasa di atas untuk mencari di semua plugin bahasa itu.'
                      : 'Mencari di ${counts[_scope] ?? 0} plugin ${languageName(_scope!)}. Plugin pertama kali diunduh dulu, jadi bisa agak lama.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              itemCount: shown.length,
              itemBuilder: (context, i) => _PluginRow(result: shown[i]),
            ),
    );
  }
}

class _PluginRow extends ConsumerWidget {
  const _PluginRow({required this.result});

  final _PluginResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final info = result.info;
    final headers = ref.watch(loadedNovelSourceProvider(info.id))?.imageHeaders ?? const <String, String>{};
    final items = result.items;
    final status = result.loading
        ? 'mencari…'
        : result.error != null
            ? '${result.error}'
            : '${items!.length} hasil';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          dense: true,
          title: Text(info.name, style: theme.textTheme.titleSmall),
          subtitle: Text('${languageName(info.lang)} · $status'),
          trailing: result.loading
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.chevron_right),
          onTap: () => context.push(novelBrowseLocation(info.id)),
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
                final n = items[i];
                return InkWell(
                  onTap: () => context.push(novelDetailLocation(info.id, n.path)),
                  child: SizedBox(
                    width: 104,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SourceCover(url: n.cover, headers: headers, width: 104),
                        const SizedBox(height: 4),
                        Text(n.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
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
