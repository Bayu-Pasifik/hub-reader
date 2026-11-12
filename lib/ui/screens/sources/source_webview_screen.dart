import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/platform/webview_bridge.dart';
import '../../../sources/source.dart';

/// Membuka situs di WebView agar pengguna bisa melewati verifikasi
/// Cloudflare. Begitu cookie `cf_clearance` muncul dan halaman bukan lagi
/// "Just a moment...", cookie disalin ke penyimpanan scraper lalu layar
/// ditutup dengan hasil `true`.
class SourceWebViewScreen extends StatefulWidget {
  const SourceWebViewScreen({super.key, required this.url});

  final String url;

  @override
  State<SourceWebViewScreen> createState() => _SourceWebViewScreenState();
}

class _SourceWebViewScreenState extends State<SourceWebViewScreen> {
  late final WebViewController _controller;
  Timer? _poll;
  int _progress = 0;
  bool _finished = false;

  Uri get _uri => Uri.parse(widget.url);

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // UA harus sama dengan Dio; cf_clearance terikat ke User-Agent.
      ..setUserAgent(HttpSource.userAgent)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onPageFinished: (_) => _check(),
      ))
      ..loadRequest(_uri);
    // Tantangan JS kadang selesai tanpa navigasi baru; cek berkala juga.
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _check());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<bool> _stillChallenged() async {
    try {
      final title = (await _controller.getTitle()) ?? '';
      return title.contains('Just a moment') || title.contains('Attention Required');
    } catch (_) {
      return true;
    }
  }

  Future<void> _check() async {
    if (_finished) return;
    final cookies = await WebViewBridge.cookiesFor(_uri);
    if (cookies == null || !cookies.contains('cf_clearance')) return;
    if (await _stillChallenged()) return;
    _complete(cookies, auto: true);
  }

  /// Simpan cookie (apa pun isinya) lalu kembali. Dipakai juga oleh tombol
  /// "Selesai" bila deteksi otomatis tidak terpicu.
  Future<void> _complete(String? cookies, {required bool auto}) async {
    if (_finished) return;
    _finished = true;
    _poll?.cancel();
    final value = cookies ?? await WebViewBridge.cookiesFor(_uri);
    HttpSource.cookies.save(_uri, value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(auto ? 'Verifikasi berhasil, memuat ulang…' : 'Cookie disimpan, memuat ulang…'),
      duration: const Duration(seconds: 2),
    ));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Verifikasi situs'),
            Text(_uri.host, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _complete(null, auto: false),
            child: const Text('Selesai'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progress < 100) LinearProgressIndicator(value: _progress / 100),
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              'Selesaikan verifikasi bila diminta. Layar ini menutup otomatis setelah berhasil.',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
