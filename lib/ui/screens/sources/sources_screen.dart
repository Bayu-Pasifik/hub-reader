import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../sources/models.dart';
import '../../../sources/source.dart';
import '../../../state/download_providers.dart';
import '../../../state/source_settings_provider.dart';
import '../../../state/source_providers.dart';
import '../../router.dart';
import '../../widgets/source_widgets.dart';

/// Nama bahasa untuk judul kelompok (kode dari katalog keiyoushi).
const _languageNames = {
  'id': 'Indonesia',
  'en': 'English',
  'all': 'Multi-bahasa',
  'ar': 'العربية (Arab)',
  'cs': 'Čeština',
  'de': 'Deutsch',
  'es': 'Español',
  'es-419': 'Español (Latinoamérica)',
  'fr': 'Français',
  'it': 'Italiano',
  'ja': '日本語 (Jepang)',
  'ko': '한국어 (Korea)',
  'pt': 'Português',
  'pt-BR': 'Português (Brasil)',
  'ru': 'Русский (Rusia)',
  'th': 'ไทย (Thai)',
  'tr': 'Türkçe',
  'uk': 'Українська',
  'vi': 'Tiếng Việt',
  'zh': '中文 (Tionghoa)',
};

String languageName(String code) => _languageNames[code] ?? code.toUpperCase();

/// Urutan bahasa: Indonesia, English, lalu sisanya menurut jumlah sumber.
List<String> _orderedLanguages(Map<String, int> counts) => counts.keys.toList()
  ..sort((a, b) {
    int rank(String l) => switch (l) { 'id' => 0, 'en' => 1, _ => 2 };
    final r = rank(a).compareTo(rank(b));
    return r != 0 ? r : counts[b]!.compareTo(counts[a]!);
  });

/// Tab "Sumber": extension on-device dikelompokkan per bahasa, dengan
/// pencarian, filter bahasa, dan toggle sumber 18+.
class SourcesScreen extends ConsumerStatefulWidget {
  const SourcesScreen({super.key});

  @override
  ConsumerState<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends ConsumerState<SourcesScreen> {
  final _search = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(sourceRegistryProvider);
    final showNsfw = ref.watch(showNsfwSourcesProvider);
    final selectedLang = ref.watch(sourceLanguageProvider);
    final queueCount = ref.watch(downloadQueueProvider.select((q) => q.length));
    final scheme = Theme.of(context).colorScheme;

    final visible = registry.sources.where((s) => showNsfw || s.contentWarning != ContentWarning.nsfw).toList();
    final counts = <String, int>{};
    for (final s in visible) {
      counts[s.lang] = (counts[s.lang] ?? 0) + 1;
    }
    final languages = _orderedLanguages(counts);
    final lang = languages.contains(selectedLang) ? selectedLang : null;

    final query = _search.text.trim().toLowerCase();
    final filtered = visible.where((s) {
      if (lang != null && s.lang != lang) return false;
      if (query.isEmpty) return true;
      return s.name.toLowerCase().contains(query) || s.baseUrl.toLowerCase().contains(query);
    }).toList();

    // Baris datar: header bahasa lalu sumbernya (urut nama).
    final rows = <Object>[];
    for (final l in languages) {
      final group = filtered.where((s) => s.lang == l).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (group.isEmpty) continue;
      rows.add((lang: l, count: group.length));
      rows.addAll(group);
    }

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Cari sumber…', border: InputBorder.none),
                onChanged: (_) => setState(() {}),
              )
            : const Text('Sumber'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Tutup pencarian' : 'Cari sumber',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _search.clear();
            }),
          ),
          IconButton(
            tooltip: 'Unduhan',
            icon: Badge(
              isLabelVisible: queueCount > 0,
              label: Text('$queueCount'),
              child: const Icon(Icons.download_outlined),
            ),
            onPressed: () => context.push('/downloads'),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'nsfw') ref.read(showNsfwSourcesProvider.notifier).set(!showNsfw);
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem(value: 'nsfw', checked: showNsfw, child: const Text('Tampilkan sumber 18+')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('Semua (${visible.length})'),
                    selected: lang == null,
                    onSelected: (_) => ref.read(sourceLanguageProvider.notifier).set(null),
                  ),
                ),
                for (final l in languages)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('${l.toUpperCase()} (${counts[l]})'),
                      selected: lang == l,
                      onSelected: (_) => ref.read(sourceLanguageProvider.notifier).set(l),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: rows.isEmpty
          ? const Center(child: Text('Tidak ada sumber yang cocok.'))
          : ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final row = rows[i];
                if (row is ({String lang, int count})) {
                  return Container(
                    color: scheme.surfaceContainerHigh,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Text(
                      '${languageName(row.lang)} · ${row.count}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  );
                }
                final source = row as MangaSource;
                return _SourceTile(
                  source: source,
                  experimental: registry.experimentalIds.contains(source.id),
                );
              },
            ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.source, required this.experimental});

  final MangaSource source;
  final bool experimental;

  @override
  Widget build(BuildContext context) {
    final s = source;
    final host = Uri.tryParse(s.baseUrl)?.host ?? s.baseUrl;
    final overridden = s is HttpSource && s.baseUrl != s.defaultBaseUrl;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(child: Text(s.name.characters.first.toUpperCase())),
      title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '$host${overridden ? ' (diubah)' : ''}${experimental ? ' · eksperimental' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: experimental ? TextStyle(color: scheme.tertiary) : null,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ContentWarningChip(warning: s.contentWarning),
          if (s is HttpSource)
            IconButton(
              tooltip: 'Ganti domain',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _BaseUrlDialog(source: s),
              ),
            ),
        ],
      ),
      onTap: () => context.push(sourceBrowseLocation(s.id)),
    );
  }
}

/// Ganti domain sumber tanpa build ulang (situs sering pindah domain).
class _BaseUrlDialog extends ConsumerStatefulWidget {
  const _BaseUrlDialog({required this.source});

  final HttpSource source;

  @override
  ConsumerState<_BaseUrlDialog> createState() => _BaseUrlDialogState();
}

class _BaseUrlDialogState extends ConsumerState<_BaseUrlDialog> {
  late final _controller = TextEditingController(text: widget.source.baseUrl);
  String? _testResult;
  bool _testing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _error {
    final uri = Uri.tryParse(_controller.text.trim());
    if (uri == null || !uri.hasScheme || !uri.scheme.startsWith('http') || uri.host.isEmpty) {
      return 'Masukkan URL lengkap, mis. https://domain-baru.com';
    }
    return null;
  }

  Future<void> _test() async {
    if (_error != null) return;
    setState(() {
      _testing = true;
      _testResult = null;
    });
    String result;
    try {
      final res = await Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        responseType: ResponseType.plain,
        validateStatus: (_) => true,
        headers: {'User-Agent': HttpSource.userAgent},
      )).get<String>(_controller.text.trim());
      final cf = (res.data ?? '').contains('Just a moment');
      result = res.statusCode == 200
          ? 'Terhubung (HTTP 200)'
          : 'HTTP ${res.statusCode}${cf ? ' — perlu verifikasi Cloudflare' : ''}';
    } on DioException catch (e) {
      result = 'Gagal terhubung: ${e.type.name}';
    }
    if (mounted) {
      setState(() {
        _testing = false;
        _testResult = result;
      });
    }
  }

  Future<void> _save() async {
    if (_error != null) return;
    await ref
        .read(sourceBaseUrlProvider.notifier)
        .set(widget.source.id, _controller.text, currentUrl: widget.source.baseUrl);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _reset() async {
    await ref.read(sourceBaseUrlProvider.notifier).reset(
          widget.source.id,
          currentUrl: widget.source.baseUrl,
          defaultUrl: widget.source.defaultBaseUrl,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('Domain ${widget.source.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(labelText: 'Base URL', errorText: _error),
            onChanged: (_) => setState(() => _testResult = null),
          ),
          const SizedBox(height: 8),
          Text('Bawaan: ${widget.source.defaultBaseUrl}', style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            'Favorit & riwayat dari domain lama tetap bisa dibuka (dialihkan otomatis).',
            style: theme.textTheme.bodySmall,
          ),
          if (_testing) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          if (_testResult != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_testResult!, style: theme.textTheme.bodyMedium),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: _testing ? null : _test, child: const Text('Tes')),
        TextButton(onPressed: _reset, child: const Text('Bawaan')),
        FilledButton(onPressed: _error == null ? _save : null, child: const Text('Simpan')),
      ],
    );
  }
}
