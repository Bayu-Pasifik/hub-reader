import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../sources/source.dart';
import '../../../state/download_providers.dart';
import '../../../state/source_settings_provider.dart';
import '../../../state/source_providers.dart';
import '../../router.dart';
import '../../widgets/source_widgets.dart';

/// Tab "Sumber": daftar extension on-device (scraping langsung dari HP).
class SourcesScreen extends ConsumerWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourceRegistryProvider).sources;
    final scheme = Theme.of(context).colorScheme;
    final queueCount = ref.watch(downloadQueueProvider.select((q) => q.length));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sumber'),
        actions: [
          IconButton(
            tooltip: 'Unduhan',
            icon: Badge(
              isLabelVisible: queueCount > 0,
              label: Text('$queueCount'),
              child: const Icon(Icons.download_outlined),
            ),
            onPressed: () => context.push('/downloads'),
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: sources.length + 1,
        separatorBuilder: (_, i) => i == 0 ? const SizedBox.shrink() : const Divider(height: 1),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                'Konten diambil langsung dari situs oleh HP ini, tanpa lewat server scraper-hub.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
              ),
            );
          }
          final source = sources[i - 1];
          final host = Uri.tryParse(source.baseUrl)?.host ?? source.baseUrl;
          final overridden = source is HttpSource && source.baseUrl != source.defaultBaseUrl;
          return ListTile(
            leading: CircleAvatar(child: Text(source.name.characters.first.toUpperCase())),
            title: Text(source.name),
            subtitle: Text('${source.lang.toUpperCase()} · $host${overridden ? ' (diubah)' : ''}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ContentWarningChip(warning: source.contentWarning),
                if (source is HttpSource)
                  IconButton(
                    tooltip: 'Ganti domain',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => _BaseUrlDialog(source: source),
                    ),
                  ),
              ],
            ),
            onTap: () => context.push(sourceBrowseLocation(source.id)),
          );
        },
      ),
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
