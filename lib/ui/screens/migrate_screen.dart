import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/source_library.dart';
import '../../novels/novel_source.dart';
import '../../state/migration.dart';
import '../../state/novel_health_provider.dart';
import '../../state/novel_providers.dart';
import '../../state/source_health_provider.dart';
import '../../state/source_library_providers.dart';
import '../../state/source_providers.dart';
import '../widgets/library_routing.dart';
import '../widgets/source_widgets.dart';
import 'sources/sources_screen.dart' show languageName;

/// Satu sumber tujuan beserta hasil pencariannya.
class _Target {
  _Target({required this.sourceId, required this.name, required this.search});

  final String sourceId;
  final String name;
  final Future<List<({String url, String title, String? cover})>> Function(String query) search;
  List<({String url, String title, String? cover})>? items;
  String? error;
  bool get loading => items == null && error == null;
}

/// Pindah sumber: cari judul yang sama di sumber lain, lalu pindahkan
/// favorit, kategori, tanda sudah dibaca, dan riwayat ke sumber itu.
class MigrateScreen extends ConsumerStatefulWidget {
  const MigrateScreen({super.key, required this.sourceId, required this.url, required this.title});

  final String sourceId;
  final String url;
  final String title;

  @override
  ConsumerState<MigrateScreen> createState() => _MigrateScreenState();
}

class _MigrateScreenState extends ConsumerState<MigrateScreen> {
  static const _parallel = 4;
  static const _timeout = Duration(seconds: 40);

  late final _query = TextEditingController(text: widget.title);
  late final bool _novel = isNovelSourceId(widget.sourceId);
  String? _lang;
  List<_Target> _targets = const [];
  int _run = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _lang = await _currentLang();
      if (mounted) _search();
    });
  }

  @override
  void dispose() {
    _run++;
    _query.dispose();
    super.dispose();
  }

  Future<String?> _currentLang() async {
    if (_novel) {
      final m = await ref.read(novelManifestProvider.future);
      return m.byId(pluginIdOf(widget.sourceId))?.lang;
    }
    return ref.read(sourceProvider(widget.sourceId))?.lang;
  }

  /// Bahasa → jumlah sumber.
  Map<String, int> _languages() {
    final counts = <String, int>{};
    if (_novel) {
      for (final p in ref.watch(novelManifestProvider).valueOrNull?.plugins ?? const []) {
        counts[p.lang] = (counts[p.lang] ?? 0) + 1;
      }
    } else {
      for (final s in ref.watch(sourceRegistryProvider).sources) {
        counts[s.lang] = (counts[s.lang] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<List<_Target>> _buildTargets() async {
    if (_novel) {
      final manifest = await ref.read(novelManifestProvider.future);
      final health = ref.read(novelHealthProvider);
      final installed = await ref.read(novelInstalledProvider.future);
      final self = pluginIdOf(widget.sourceId);
      final plugins = manifest.plugins.where((p) {
        if (p.id == self || !novelUsable(health[p.id])) return false;
        return _lang == null ? installed.contains(p.id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')) : p.lang == _lang;
      });
      return [
        for (final p in plugins)
          _Target(
            sourceId: novelLibraryId(p.id),
            name: p.name,
            search: (q) async {
              final source = await ref.read(novelSourceProvider(p.id).future);
              return [for (final n in await source.search(q, 1)) (url: n.path, title: n.name, cover: n.cover)];
            },
          ),
      ];
    }
    final health = ref.read(sourceHealthProvider);
    final sources = ref.read(sourceRegistryProvider).sources.where((s) {
      if (s.id == widget.sourceId) return false;
      final status = health[s.id]?.status;
      if (status == HealthStatus.dead || status == HealthStatus.broken) return false;
      return _lang == null || s.lang == _lang;
    });
    return [
      for (final s in sources)
        _Target(
          sourceId: s.id,
          name: s.name,
          search: (q) async => [
            for (final m in (await s.search(1, q)).items) (url: m.url, title: m.title, cover: m.thumbnailUrl),
          ],
        ),
    ];
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    final run = ++_run;
    final targets = await _buildTargets();
    if (!mounted || run != _run) return;
    setState(() => _targets = targets);
    var next = 0;
    Future<void> worker() async {
      while (next < targets.length && run == _run) {
        final t = targets[next++];
        try {
          t.items = await t.search(q).timeout(_timeout);
        } catch (e) {
          t.error = e is TimeoutException ? 'Waktu habis' : novelError(e).title;
        }
        if (mounted && run == _run) setState(() {});
      }
    }

    await Future.wait([for (var i = 0; i < _parallel; i++) worker()]);
    if (mounted && run == _run) {
      int rank(_Target t) => t.error != null ? 2 : (t.items!.isEmpty ? 1 : 0);
      setState(() => _targets = [...targets]..sort((a, b) => rank(a).compareTo(rank(b))));
    }
  }

  Future<void> _confirm(_Target target, ({String url, String title, String? cover}) pick) async {
    var keepOld = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Pindah sumber?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('"${widget.title}" dipindah ke ${target.name}:\n"${pick.title}".\n\n'
                  'Favorit, kategori, tanda sudah dibaca (dicocokkan lewat nomor bab), dan bab terakhir dibaca ikut dipindah.'),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Simpan juga favorit lama'),
                value: keepOld,
                onChanged: (v) => setDialog(() => keepOld = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Pindahkan')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content:
            Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Expanded(child: Text('Memindahkan…'))]),
      ),
    );
    final messenger = ScaffoldMessenger.of(context);
    final from = ref.read(sourceFavoritesProvider).where((f) => f.item.key == '${widget.sourceId}|${widget.url}');
    try {
      final result = await migrateSeries(
        ref.read,
        from: from.firstOrNull?.item ??
            SourceLibraryItem(sourceId: widget.sourceId, url: widget.url, title: widget.title),
        to: SourceLibraryItem(sourceId: target.sourceId, url: pick.url, title: pick.title, thumbnailUrl: pick.cover),
        keepOld: keepOld,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // dialog progres
      messenger.showSnackBar(SnackBar(
        content: Text([
          'Dipindah ke ${target.name}',
          if (result.markedRead > 0) '${result.markedRead} bab ditandai dibaca',
          if (result.lastRead != null) 'lanjut di ${result.lastRead}',
        ].join(' · ')),
      ));
      context.pushReplacement(librarySourceInfo(ref, target.sourceId).detailLocation(pick.url));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text('Gagal memindahkan: ${novelError(e).title}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final langs = _languages();
    final ordered = langs.keys.toList()
      ..sort((a, b) {
        int rank(String l) => switch (l) { 'id' => 0, 'en' => 1, _ => 2 };
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : langs[b]!.compareTo(langs[a]!);
      });
    final done = _targets.where((t) => !t.loading).length;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(hintText: 'Judul di sumber lain…', border: InputBorder.none),
          onSubmitted: (_) => _search(),
        ),
        actions: [IconButton(tooltip: 'Cari', icon: const Icon(Icons.search), onPressed: _search)],
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
                    if (_novel)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: const Text('Pernah dibuka'),
                          selected: _lang == null,
                          onSelected: (_) {
                            setState(() => _lang = null);
                            _search();
                          },
                        ),
                      ),
                    for (final l in ordered)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text('${languageName(l)} (${langs[l]})'),
                          selected: _lang == l,
                          onSelected: (_) {
                            setState(() => _lang = l);
                            _search();
                          },
                        ),
                      ),
                  ],
                ),
              ),
              if (_targets.isNotEmpty && done < _targets.length)
                LinearProgressIndicator(value: done / _targets.length, minHeight: 2),
            ],
          ),
        ),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Pilih judul yang sama di sumber lain untuk memindahkan "${widget.title}".',
              style: theme.textTheme.bodySmall,
            ),
          ),
          for (final t in _targets)
            if (t.loading || (t.items?.isNotEmpty ?? false) || t.error != null) ...[
              ListTile(
                dense: true,
                title: Text(t.name, style: theme.textTheme.titleSmall),
                subtitle: Text(t.loading ? 'mencari…' : (t.error ?? '${t.items!.length} hasil')),
                trailing: t.loading
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
              ),
              if (t.items?.isNotEmpty ?? false)
                SizedBox(
                  height: 210,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: t.items!.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final m = t.items![i];
                      final headers = librarySourceInfo(ref, t.sourceId).imageHeaders;
                      return InkWell(
                        onTap: () => _confirm(t, m),
                        child: SizedBox(
                          width: 104,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SourceCover(url: m.cover, headers: headers, width: 104),
                              const SizedBox(height: 4),
                              Text(m.title,
                                  maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const Divider(height: 1),
            ],
        ],
      ),
    );
  }
}
