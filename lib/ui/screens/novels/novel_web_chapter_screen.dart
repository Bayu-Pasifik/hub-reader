import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/platform/webview_bridge.dart';
import '../../../sources/source.dart';

/// Menyimpan bab yang sedang tampil di halaman. Mengembalikan judul bab yang
/// dikenali, atau null bila halaman tidak cocok dengan bab mana pun.
typedef WebChapterGrab = Future<String?> Function(String pageUrl, String html);

/// Membuka situs di WebView supaya pengguna menyelesaikan Turnstile (atau
/// login) sekali, lalu berpindah bab dengan tombol Next milik situs. Tiap
/// ketukan "Ambil bab" menyimpan bab yang sedang tampil lewat [onGrab]; layar
/// tetap terbuka sampai pengguna kembali.
class NovelWebChapterScreen extends StatefulWidget {
  const NovelWebChapterScreen({super.key, required this.url, required this.title, required this.onGrab});

  final String url;
  final String title;
  final WebChapterGrab onGrab;

  @override
  State<NovelWebChapterScreen> createState() => _NovelWebChapterScreenState();
}

class _NovelWebChapterScreenState extends State<NovelWebChapterScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _busy = false;
  final _saved = <String>[];
  String? _lastUrl;
  String _lastHead = '';

  // Cari induk yang menampung teks paragraf paling banyak, lalu ambil
  // paragraf dan judulnya saja (tanpa menu, iklan, atau tombol).
  static const _extractJs = r'''
(() => {
  const ps = [...document.querySelectorAll('p')].filter(p => p.innerText.trim().length > 0);
  const total = new Map();
  for (const p of ps) total.set(p.parentElement, (total.get(p.parentElement) || 0) + p.innerText.length);
  let best = null, bestLen = 0;
  total.forEach((len, el) => { if (len > bestLen) { best = el; bestLen = len; } });
  // Pesan situs (registrasi AI, Security Check) bukan isi bab.
  const junk = /requires registration|security check|complete the (security|turnstile)|unusual reading activity/i;
  if (best && bestLen >= 600 && !junk.test(best.innerText)) {
    return [...best.children]
      .filter(c => c.tagName === 'P' || /^H[1-6]$/.test(c.tagName))
      .map(c => c.outerHTML).join('');
  }
  // Tanpa <p> yang jelas: turun ke kontainer yang memegang mayoritas teks halaman.
  const skip = ['SCRIPT', 'STYLE', 'NAV', 'HEADER', 'FOOTER'];
  let box = document.body;
  for (let i = 0; i < 14; i++) {
    const len = box.innerText.length;
    const kid = [...box.children].find(c => !skip.includes(c.tagName) && c.innerText && c.innerText.length >= len * 0.6);
    if (!kid) break;
    box = kid;
  }
  const text = box.innerText.trim();
  if (text.length < 800 || junk.test(text)) return '';
  const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  // Satu paragraf per elemen daun; innerText kontainer sering tanpa baris baru.
  const leaves = [...box.querySelectorAll('*')]
    .filter(e => e.children.length === 0 && !skip.includes(e.tagName) && e.innerText && e.innerText.trim().length > 0)
    .map(e => e.innerText.trim());
  const lines = leaves.length > 3 ? leaves : text.split(/\n+/).map(l => l.trim()).filter(Boolean);
  return lines.map(l => '<p>' + esc(l) + '</p>').join('');
})()
''';

  // Tamu hanya mendapat terjemahan AI untuk beberapa bab pertama; setelah itu
  // halaman meminta registrasi. Pindah ke tab "Web" (atau tautan Google Web
  // Translation) supaya teks bab tampil tanpa login.
  static const _openWebTabJs = r'''
(() => {
  const tab = [...document.querySelectorAll('button,a,[role=tab],label,span,div')]
    .find(e => e.children.length === 0 && e.textContent.trim() === 'Web');
  if (tab) { tab.click(); return 'tab'; }
  const link = [...document.querySelectorAll('a,button,div')]
    .find(e => e.children.length <= 2 && /Google Web Translation/i.test(e.textContent));
  if (link) { link.click(); return 'link'; }
  return '';
})()
''';

  Future<String> _extract() async =>
      _jsString(await _controller.runJavaScriptReturningResult(_extractJs)) ?? '';

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

  static String? _jsString(Object? raw) {
    if (raw is! String) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is String ? decoded : raw;
    } on FormatException {
      return raw;
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 3)));
  }

  Future<void> _grab() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      var html = await _extract();
      if (html.trim().isEmpty) {
        await _controller.runJavaScriptReturningResult(_openWebTabJs);
        await Future<void>.delayed(const Duration(seconds: 4));
        html = await _extract();
      }
      final pageUrl = await _controller.currentUrl() ?? widget.url;
      // Cookie hasil verifikasi dipakai plugin untuk permintaan berikutnya.
      final uri = Uri.parse(pageUrl);
      final cookies = await WebViewBridge.cookiesFor(uri);
      if (cookies != null && cookies.isNotEmpty) HttpSource.cookies.save(uri, cookies);
      if (html.trim().isEmpty) {
        _toast(tr('Teks bab belum ditemukan. Selesaikan verifikasi, tunggu bab tampil, lalu coba lagi.'));
        return;
      }
      // Situs berpindah bab tanpa memuat ulang: alamat sudah baru tetapi teks
      // masih milik bab sebelumnya. Tolak sampai teksnya berganti.
      final sig = html.replaceAll(RegExp(r'<[^>]+>|\s+'), ' ').trim();
      final head = sig.length > 300 ? sig.substring(0, 300) : sig;
      if (_lastUrl != null && pageUrl != _lastUrl && head == _lastHead) {
        _toast(tr('Halaman belum berganti ke bab baru. Tunggu teksnya dimuat, lalu ketuk "Ambil bab" lagi.'));
        return;
      }
      final name = await widget.onGrab(pageUrl, html);
      if (name == null) {
        _toast(tr('Halaman ini tidak cocok dengan bab mana pun di daftar. Buka halaman bab lalu coba lagi.'));
        return;
      }
      _lastUrl = pageUrl;
      _lastHead = head;
      if (!_saved.contains(name)) _saved.add(name);
      _toast(trp('Tersimpan: {name}. Pindah bab dengan tombol Next di situs, lalu ketuk "Ambil bab" lagi.', {'name': name}));
    } catch (_) {
      _toast(tr('Gagal mengambil bab.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
            child: Text(_saved.isEmpty ? tr('Ambil bab') : trp('Ambil bab ({n})', {'n': _saved.length})),
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
              tr('Selesaikan verifikasi (dan login bila perlu). Saat teks bab tampil, ketuk "Ambil bab". Pindah bab dengan tombol Next di situs, ketuk "Ambil bab" lagi, lalu kembali untuk membaca.'),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
