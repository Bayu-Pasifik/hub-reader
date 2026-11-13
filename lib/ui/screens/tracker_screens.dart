import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../state/tracker_providers.dart';
import '../../trackers/tracker.dart';

/// Login OAuth tracker di WebView. Hasil `true` bila berhasil.
class TrackerLoginScreen extends StatefulWidget {
  const TrackerLoginScreen({super.key, required this.tracker});

  final Tracker tracker;

  @override
  State<TrackerLoginScreen> createState() => _TrackerLoginScreenState();
}

class _TrackerLoginScreenState extends State<TrackerLoginScreen> {
  late final WebViewController _controller;
  bool _done = false;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onNavigationRequest: (req) async {
          if (await _check(req.url)) return NavigationDecision.prevent;
          return NavigationDecision.navigate;
        },
        onUrlChange: (change) => _check(change.url ?? ''),
        onPageFinished: _check,
      ))
      ..loadRequest(widget.tracker.authorizeUrl());
  }

  Future<bool> _check(String raw) async {
    if (_done) return true;
    final url = Uri.tryParse(raw);
    if (url == null) return false;
    try {
      if (!await widget.tracker.handleRedirect(url)) return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
      return false;
    }
    _done = true;
    if (mounted) Navigator.of(context).pop(true);
    return true;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('Login ${widget.tracker.name}'),
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(value: _progress / 100, minHeight: 2),
                )
              : null,
        ),
        body: WebViewWidget(controller: _controller),
      );
}

/// Pengaturan satu tracker: Client ID, login/logout.
class TrackerSettingsTile extends ConsumerStatefulWidget {
  const TrackerSettingsTile({super.key, required this.tracker});

  final Tracker tracker;

  @override
  ConsumerState<TrackerSettingsTile> createState() => _TrackerSettingsTileState();
}

class _TrackerSettingsTileState extends ConsumerState<TrackerSettingsTile> {
  Tracker get t => widget.tracker;

  Future<void> _editClientId() async {
    // Client ID bawaan build tidak ditampilkan; kolom kosong = pakai bawaan.
    final controller = TextEditingController(text: t.usesDefaultClientId ? '' : t.clientId ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Client ID ${t.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Buat aplikasi di ${t.developerUrl} dengan redirect URL:\n${t.redirectHint}\n'
                'lalu tempel Client ID-nya di sini.'
                '${t.defaultClientId.isNotEmpty ? '\nKosongkan untuk memakai Client ID bawaan aplikasi.' : ''}'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Client ID', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Simpan')),
        ],
      ),
    );
    if (value != null) {
      await t.setClientId(value);
      setState(() {});
    }
  }

  /// Kitsu / MangaUpdates: username & password, hanya token yang disimpan.
  Future<void> _passwordLogin() async {
    final user = TextEditingController(text: t.username ?? '');
    final pass = TextEditingController();
    String? error;
    var busy = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) {
          Future<void> submit() async {
            if (user.text.trim().isEmpty || pass.text.isEmpty) return;
            setDialog(() {
              busy = true;
              error = null;
            });
            try {
              await t.loginWithPassword(user.text.trim(), pass.text);
              if (context.mounted) Navigator.pop(context, true);
            } catch (e) {
              setDialog(() {
                busy = false;
                error = '$e';
              });
            }
          }

          return AlertDialog(
            title: Text('Login ${t.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: user,
                  autofocus: true,
                  enabled: !busy,
                  keyboardType: t.usernameLabel == 'Email' ? TextInputType.emailAddress : TextInputType.text,
                  autofillHints: const [AutofillHints.username],
                  decoration: InputDecoration(labelText: t.usernameLabel, border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pass,
                  enabled: !busy,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => submit(),
                  decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                Text(
                  error ?? 'Password tidak disimpan; hanya token sesi.',
                  style: TextStyle(
                    fontSize: 12,
                    color: error == null
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('Batal')),
              FilledButton(
                onPressed: busy ? null : submit,
                child: busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Login'),
              ),
            ],
          );
        },
      ),
    );
    user.dispose();
    pass.dispose();
    if (!mounted || ok != true) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Login ${t.name} berhasil${t.username != null ? ' (${t.username})' : ''}'),
    ));
  }

  Future<void> _login() async {
    if (t.passwordLogin) return _passwordLogin();
    if ((t.clientId ?? '').isEmpty) {
      await _editClientId();
      if ((t.clientId ?? '').isEmpty) return;
    }
    if (!mounted) return;
    final ok = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(builder: (_) => TrackerLoginScreen(tracker: t)),
    );
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          ok == true ? 'Login ${t.name} berhasil${t.username != null ? ' (${t.username})' : ''}' : 'Login dibatalkan'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasId = (t.clientId ?? '').isNotEmpty;
    return ListTile(
      leading: const Icon(Icons.sync_alt),
      title: Text(t.name),
      subtitle: Text(
        t.loggedIn
            ? 'Masuk${t.username != null ? ' sebagai ${t.username}' : ''}'
            : t.passwordLogin
                ? 'Belum login'
                : hasId
                ? 'Belum login${t.usesDefaultClientId ? ' · Client ID bawaan' : ''}'
                : 'Belum ada Client ID',
      ),
      onTap: t.passwordLogin ? null : _editClientId,
      trailing: t.loggedIn
          ? TextButton(
              onPressed: () async {
                await t.logout();
                setState(() {});
              },
              child: const Text('Keluar'),
            )
          : FilledButton.tonal(onPressed: _login, child: const Text('Login')),
    );
  }
}

/// Lembar tracking untuk satu seri: tautkan, ubah progres/status, lepas.
class TrackingSheet extends ConsumerWidget {
  const TrackingSheet({
    super.key,
    required this.seriesKey,
    required this.title,
    required this.novel,
    this.localProgress,
  });

  final String seriesKey;
  final String title;
  final bool novel;

  /// Nomor bab tertinggi yang sudah dibaca di aplikasi.
  final int? localProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackers = ref.watch(trackersProvider);
    final links = ref.watch(trackLinksProvider.select((m) => m[seriesKey] ?? const <TrackLink>[]));
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Tracking', style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final t in trackers)
              _TrackerRow(
                tracker: t,
                link: links.where((l) => l.tracker == t.id).firstOrNull,
                seriesKey: seriesKey,
                title: title,
                novel: novel,
                localProgress: localProgress,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Progres dikirim otomatis saat bab selesai dibaca (tidak saat mode samaran).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackerRow extends ConsumerStatefulWidget {
  const _TrackerRow({
    required this.tracker,
    required this.link,
    required this.seriesKey,
    required this.title,
    required this.novel,
    required this.localProgress,
  });

  final Tracker tracker;
  final TrackLink? link;
  final String seriesKey;
  final String title;
  final bool novel;
  final int? localProgress;

  @override
  ConsumerState<_TrackerRow> createState() => _TrackerRowState();
}

class _TrackerRowState extends ConsumerState<_TrackerRow> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _link() async {
    final picked = await showDialog<TrackSearchResult>(
      context: context,
      builder: (_) => _TrackSearchDialog(tracker: widget.tracker, query: widget.title, novel: widget.novel),
    );
    if (picked == null) return;
    await _run(() async {
      final remote = await widget.tracker.entry(picked.id);
      final local = widget.localProgress ?? 0;
      final progress = [remote?.progress ?? 0, local].reduce((a, b) => a > b ? a : b);
      final link = TrackLink(
        tracker: widget.tracker.id,
        mediaId: picked.id,
        title: picked.title,
        progress: progress,
        total: remote?.total ?? picked.total,
        status: remote?.status ?? TrackStatus.reading,
        url: picked.url,
      );
      await ref.read(trackLinksProvider.notifier).push(widget.seriesKey, link);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tracker;
    final link = widget.link;
    final theme = Theme.of(context);
    if (!t.loggedIn) {
      return ListTile(title: Text(t.name), subtitle: const Text('Belum login (Pengaturan → Tracker)'));
    }
    if (link == null) {
      return ListTile(
        title: Text(t.name),
        subtitle: const Text('Belum ditautkan'),
        trailing: _busy
            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : FilledButton.tonal(onPressed: _link, child: const Text('Tautkan')),
      );
    }
    final notifier = ref.read(trackLinksProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${t.name} · ${link.title}', style: theme.textTheme.titleSmall, maxLines: 2),
              ),
              if (_busy) const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              IconButton(
                tooltip: 'Lepas tautan',
                icon: const Icon(Icons.link_off),
                onPressed: () => notifier.remove(widget.seriesKey, t.id),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: _busy || link.progress <= 0
                    ? null
                    : () => _run(() => notifier.push(widget.seriesKey, link.copyWith(progress: link.progress - 1))),
              ),
              Text('Bab ${link.progress}${link.total != null ? ' / ${link.total}' : ''}'),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _busy
                    ? null
                    : () => _run(() => notifier.push(widget.seriesKey, link.copyWith(progress: link.progress + 1))),
              ),
              const Spacer(),
              DropdownButton<TrackStatus>(
                value: link.status,
                items: [for (final s in TrackStatus.values) DropdownMenuItem(value: s, child: Text(s.label))],
                onChanged: _busy ? null : (s) => _run(() => notifier.push(widget.seriesKey, link.copyWith(status: s))),
              ),
            ],
          ),
          const Divider(height: 8),
        ],
      ),
    );
  }
}

class _TrackSearchDialog extends StatefulWidget {
  const _TrackSearchDialog({required this.tracker, required this.query, required this.novel});

  final Tracker tracker;
  final String query;
  final bool novel;

  @override
  State<_TrackSearchDialog> createState() => _TrackSearchDialogState();
}

class _TrackSearchDialogState extends State<_TrackSearchDialog> {
  late final _q = TextEditingController(text: widget.query);
  Future<List<TrackSearchResult>>? _results;

  @override
  void initState() {
    super.initState();
    _search();
  }

  void _search() => setState(() => _results = widget.tracker.search(_q.text.trim(), novel: widget.novel));

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Cari di ${widget.tracker.name}'),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        content: SizedBox(
          width: double.maxFinite,
          height: 420,
          child: Column(
            children: [
              TextField(
                controller: _q,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _search),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<TrackSearchResult>>(
                  future: _results,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) return Center(child: Text('${snap.error}'));
                    final list = snap.data ?? const [];
                    if (list.isEmpty) return const Center(child: Text('Tidak ada hasil'));
                    return ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final r = list[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: SizedBox(
                            width: 40,
                            height: 56,
                            child: r.cover == null
                                ? const Icon(Icons.image_outlined)
                                : CachedNetworkImage(imageUrl: r.cover!, fit: BoxFit.cover),
                          ),
                          title: Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle:
                              Text([r.format, if (r.total != null) '${r.total} bab'].whereType<String>().join(' · ')),
                          onTap: () => Navigator.pop(context, r),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal'))],
      );
}
