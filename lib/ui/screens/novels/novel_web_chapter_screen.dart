import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/platform/webview_bridge.dart';
import '../../../sources/source.dart';

/// Membuka satu bab novel di WebView supaya pengguna bisa menyelesaikan
/// Turnstile (atau login) sendiri, lalu mengambil teks bab dari halaman.
/// Hasilnya (HTML sederhana) dikembalikan lewat `Navigator.pop`.
class NovelWebChapterScreen extends StatefulWidget {
  const NovelWebChapterScreen({super.key, required this.url, required this.title});

  final String url;
  final String title;

  @override
  State<NovelWebChapterScreen> createState() => _NovelWebChapterScreenState();
}

class _NovelWebChapterScreenState extends State<NovelWebChapterScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _busy = false;

  // Cari induk yang menampung teks paragraf paling banyak, lalu ambil
  // paragraf dan judulnya saja (tanpa menu, iklan, atau tombol).
  static const _extractJs = r'''
(() => {
  const ps = [...document.querySelectorAll('p')].filter(p => p.innerText.trim().length > 0);
  const total = new Map();
  for (const p of ps) total.set(p.parentElement, (total.get(p.parentElement) || 0) + p.innerText.length);
  let best = null, bestLen = 0;
  total.forEach((len, el) => { if (len > bestLen) { best = el; bestLen = len; } });
  if (best && bestLen >= 200) {
    return [...best.children]
      .filter(c => c.tagName === 'P' || /^H[1-6]$/.test(c.tagName))
      .map(c => c.outerHTML).join('');
  }
  const box = document.querySelector('article') || document.querySelector('main');
  const text = box ? box.innerText.trim() : '';
  if (text.length < 200) return '';
  const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  return text.split(/\n+/).map(l => l.trim()).filter(Boolean).map(l => '<p>' + esc(l) + '</p>').join('');
})()
''';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(HttpSource.userAgent)
      ..setNavigationDelegate(NavigationDelegate(onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      }))
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _grab() async {
    if (_busy) return;
    setState(() => _busy = true);
    String html = '';
    try {
      final raw = await _controller.runJavaScriptReturningResult(_extractJs);
      if (raw is String) {
        try {
          final decoded = jsonDecode(raw);
          html = decoded is String ? decoded : raw;
        } on FormatException {
          html = raw;
        }
      }
    } catch (_) {
      html = '';
    }
    // Cookie hasil verifikasi (Turnstile menghitung per klien) disalin supaya
    // permintaan plugin berikutnya ikut lolos, termasuk bab-bab selanjutnya.
    final uri = Uri.parse(widget.url);
    final cookies = await WebViewBridge.cookiesFor(uri);
    if (cookies != null && cookies.isNotEmpty) HttpSource.cookies.save(uri, cookies);
    if (!mounted) return;
    if (html.trim().isEmpty && (cookies == null || cookies.isEmpty)) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(tr('Teks bab belum ditemukan. Selesaikan verifikasi, tunggu bab tampil, lalu coba lagi.')),
        ));
      return;
    }
    // Teks kosong: pembaca mencoba plugin lagi dengan cookie yang baru.
    Navigator.of(context).pop(html);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
            onPressed: _busy ? null : _grab,
            child: Text(tr('Ambil bab')),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progress < 100) LinearProgressIndicator(value: _progress / 100),
          Container(
            width: double.infinity,
            color: scheme.surfaceContainerHigh,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              tr('Selesaikan verifikasi (dan login bila perlu). Setelah teks bab tampil, ketuk "Ambil bab".'),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
