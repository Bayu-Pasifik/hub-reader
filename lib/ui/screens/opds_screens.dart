import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../novels/local_epub.dart';
import '../../opds/opds_client.dart';
import '../../sources/local/local_source.dart';
import '../../state/opds_providers.dart';
import '../router.dart';

String opdsBrowseLocation(String serverId, {String? url}) =>
    Uri(path: '/opds/browse', queryParameters: {'server': serverId, if (url != null) 'url': url}).toString();

/// Daftar server OPDS (Komga, Kavita, Calibre-Web, ...).
class OpdsServersScreen extends ConsumerWidget {
  const OpdsServersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(opdsServersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Server OPDS')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Tambah server'),
      ),
      body: servers.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Belum ada server. Tambahkan alamat katalog OPDS dari Komga, Kavita, atau Calibre-Web '
                  'untuk mengunduh buku dan komik ke perpustakaan Lokal.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              children: [
                for (final s in servers)
                  ListTile(
                    leading: const Icon(Icons.dns_outlined),
                    title: Text(s.name),
                    subtitle: Text(s.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => context.push(opdsBrowseLocation(s.id)),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') _edit(context, ref, s);
                        if (v == 'delete') ref.read(opdsServersProvider.notifier).remove(s.id);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Ubah')),
                        PopupMenuItem(value: 'delete', child: Text('Hapus')),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, OpdsServer? existing) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final url = TextEditingController(text: existing?.url ?? '');
    final user = TextEditingController(text: existing?.username ?? '');
    final pass = TextEditingController(text: existing?.password ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Tambah server OPDS' : 'Ubah server OPDS'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama')),
              TextField(
                controller: url,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'URL katalog', hintText: 'http://192.168.1.5:25600/opds/v1.2/catalog'),
              ),
              TextField(controller: user, decoration: const InputDecoration(labelText: 'Pengguna (opsional)')),
              TextField(
                controller: pass,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Kata sandi (opsional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
        ],
      ),
    );
    final uri = Uri.tryParse(url.text.trim());
    if (ok != true || uri == null || !(uri.isScheme('http') || uri.isScheme('https')) || uri.host.isEmpty) return;
    await ref.read(opdsServersProvider.notifier).upsert(OpdsServer(
          id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
          name: name.text.trim().isEmpty ? uri.host : name.text.trim(),
          url: url.text.trim(),
          username: user.text.trim(),
          password: pass.text,
        ));
  }
}

/// Jelajahi satu feed OPDS: sub-katalog dibuka, buku bisa diunduh ke Lokal.
class OpdsBrowseScreen extends ConsumerStatefulWidget {
  const OpdsBrowseScreen({super.key, required this.serverId, this.url});

  final String serverId;
  final String? url;

  @override
  ConsumerState<OpdsBrowseScreen> createState() => _OpdsBrowseScreenState();
}

class _OpdsBrowseScreenState extends ConsumerState<OpdsBrowseScreen> {
  final _entries = <OpdsEntry>[];
  String _title = 'OPDS';
  String? _next;
  String? _searchTemplate;
  Object? _error;
  bool _loading = true;
  bool _loadingMore = false;

  OpdsServer? get _server => ref.read(opdsServersProvider).where((s) => s.id == widget.serverId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _load(widget.url ?? _server?.url);
  }

  Future<void> _load(String? url, {bool more = false}) async {
    final server = _server;
    if (server == null || url == null) {
      setState(() {
        _loading = false;
        _error = 'Server tidak ditemukan';
      });
      return;
    }
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
        _entries.clear();
      }
    });
    try {
      final feed = await ref.read(opdsClientProvider).fetch(server, url);
      if (!mounted) return;
      setState(() {
        _title = feed.title;
        _entries.addAll(feed.entries);
        _next = feed.next;
        _searchTemplate ??= feed.searchTemplate;
        _loading = false;
        _loadingMore = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _search() async {
    final template = _searchTemplate;
    if (template == null) return;
    final controller = TextEditingController();
    final q = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cari di server'),
        content: TextField(controller: controller, autofocus: true, onSubmitted: (v) => Navigator.pop(context, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Cari')),
        ],
      ),
    );
    if (q == null || q.trim().isEmpty || !mounted) return;
    context.push(opdsBrowseLocation(widget.serverId, url: template.replaceAll('{searchTerms}', Uri.encodeComponent(q.trim()))));
  }

  @override
  Widget build(BuildContext context) {
    final server = _server;
    return Scaffold(
      appBar: AppBar(
        title: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_searchTemplate != null) IconButton(tooltip: 'Cari', icon: const Icon(Icons.search), onPressed: _search),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Gagal memuat katalog\n${_describe(_error!)}', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: () => _load(widget.url ?? server?.url), child: const Text('Coba lagi')),
                      ],
                    ),
                  ),
                )
              : _entries.isEmpty
                  ? const Center(child: Text('Katalog kosong'))
                  : ListView.builder(
                      itemCount: _entries.length + (_next != null ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= _entries.length) {
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: Center(
                              child: _loadingMore
                                  ? const CircularProgressIndicator()
                                  : OutlinedButton(onPressed: () => _load(_next, more: true), child: const Text('Muat lagi')),
                            ),
                          );
                        }
                        final e = _entries[i];
                        return _EntryTile(
                          entry: e,
                          headers: server?.headers ?? const {},
                          onTap: () => e.navigateTo != null
                              ? context.push(opdsBrowseLocation(widget.serverId, url: e.navigateTo))
                              : _showBook(e),
                        );
                      },
                    ),
    );
  }

  String _describe(Object e) => e.toString().split('\n').first;

  void _showBook(OpdsEntry e) {
    final server = _server;
    if (server == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BookSheet(entry: e, server: server),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.headers, required this.onTap});

  final OpdsEntry entry;
  final Map<String, String> headers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isBook = entry.isBook;
    return ListTile(
      leading: SizedBox(
        width: 44,
        height: 60,
        child: entry.thumbnail != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: entry.thumbnail!,
                  httpHeaders: headers,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const Icon(Icons.book_outlined),
                ),
              )
            : Icon(isBook ? Icons.book_outlined : Icons.folder_outlined),
      ),
      title: Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: entry.author != null
          ? Text(entry.author!, maxLines: 1, overflow: TextOverflow.ellipsis)
          : (entry.summary != null && !isBook ? Text(entry.summary!, maxLines: 1, overflow: TextOverflow.ellipsis) : null),
      trailing: Icon(isBook ? Icons.download_outlined : Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _BookSheet extends ConsumerStatefulWidget {
  const _BookSheet({required this.entry, required this.server});

  final OpdsEntry entry;
  final OpdsServer server;

  @override
  ConsumerState<_BookSheet> createState() => _BookSheetState();
}

class _BookSheetState extends ConsumerState<_BookSheet> {
  String? _busy;
  String? _message;

  Future<void> _download(OpdsAcquisition a) async {
    final client = ref.read(opdsClientProvider);
    final entry = widget.entry;
    final ext = a.extension!;
    setState(() {
      _busy = a.url;
      _message = null;
    });
    try {
      final safe = entry.title.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').trim();
      if (ext == 'epub') {
        final path = await LocalNovelSource.importFile('$safe.epub', (p) => client.download(widget.server, a.url, p));
        if (!mounted) return;
        Navigator.pop(context);
        context.push(novelDetailLocation(LocalNovelSource.pluginId, path));
      } else {
        final url = await LocalSource.importFiles(safe, [
          (name: '$safe.cbz', saveTo: (p) => client.download(widget.server, a.url, p)),
        ]);
        if (!mounted) return;
        Navigator.pop(context);
        context.push(sourceMangaLocation(LocalSource.sourceId, url));
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = null;
          _message = 'Gagal mengunduh: ${e.toString().split('\n').first}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(e.title, style: theme.textTheme.titleMedium),
            if (e.author != null) Text(e.author!, style: theme.textTheme.bodySmall),
            if (e.summary != null) ...[
              const SizedBox(height: 12),
              Text(e.summary!, maxLines: 8, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 16),
            for (final a in e.acquisitions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton.tonalIcon(
                  onPressed: a.importable && _busy == null ? () => _download(a) : null,
                  icon: _busy == a.url
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download),
                  label: Text(a.importable ? 'Unduh ke Lokal (${a.formatLabel})' : '${a.formatLabel} (tidak didukung)'),
                ),
              ),
            if (_message != null) Text(_message!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ),
      ),
    );
  }
}
