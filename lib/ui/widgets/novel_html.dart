import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Satu blok isi bab hasil konversi HTML.
sealed class NovelBlock {
  const NovelBlock();
}

class TextBlock extends NovelBlock {
  const TextBlock(this.spans, {this.heading = 0, this.quote = false, this.center = false});

  final List<InlineRun> spans;

  /// 1–6 untuk h1–h6, 0 = paragraf biasa.
  final int heading;
  final bool quote;
  final bool center;

  String get plain => spans.map((s) => s.text).join();
}

class ImageBlock extends NovelBlock {
  const ImageBlock(this.url);

  final String url;
}

class RuleBlock extends NovelBlock {
  const RuleBlock();
}

class InlineRun {
  const InlineRun(this.text, {this.bold = false, this.italic = false, this.underline = false, this.strike = false});

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
}

const _blockTags = {
  'p',
  'div',
  'section',
  'article',
  'header',
  'footer',
  'main',
  'li',
  'ul',
  'ol',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'blockquote',
  'pre',
  'table',
  'tr',
  'tbody',
  'thead',
  'figure',
  'figcaption',
  'center',
  'dl',
  'dt',
  'dd',
  'aside',
};
const _skipTags = {'script', 'style', 'noscript', 'iframe', 'svg', 'button', 'form', 'input', 'select', 'template'};

/// HTML bab (keluaran `parseChapter`) → daftar blok untuk ditampilkan
/// dengan gaya pembaca sendiri (ukuran huruf, tema). Gaya inline situs dibuang.
List<NovelBlock> parseNovelHtml(String html, {Uri? baseUrl}) {
  final fragment = html_parser.parseFragment(html);
  final blocks = <NovelBlock>[];
  var runs = <InlineRun>[];
  var heading = 0;
  var quote = false;
  var center = false;

  void flush() {
    // Rapikan spasi: gabung whitespace, buang di awal/akhir baris.
    final cleaned = <InlineRun>[];
    for (final r in runs) {
      final t = r.text.replaceAll(RegExp(r'[ \t\r\f ]+'), ' ');
      if (t.isEmpty) continue;
      cleaned.add(InlineRun(t, bold: r.bold, italic: r.italic, underline: r.underline, strike: r.strike));
    }
    final text = cleaned.map((r) => r.text).join();
    if (text.trim().isNotEmpty) {
      // Trim kiri run pertama & kanan run terakhir, serta spasi di sekitar \n.
      final out = <InlineRun>[];
      var atLineStart = true;
      for (var i = 0; i < cleaned.length; i++) {
        var t = cleaned[i].text.replaceAll(RegExp(r' *\n *'), '\n');
        if (atLineStart) t = t.replaceFirst(RegExp(r'^ +'), '');
        if (i == cleaned.length - 1) t = t.trimRight();
        // Spasi sebelum <br> di run berikutnya.
        if (i + 1 < cleaned.length && cleaned[i + 1].text.startsWith('\n')) t = t.replaceFirst(RegExp(r' +$'), '');
        if (t.isEmpty) continue;
        atLineStart = t.endsWith('\n');
        final r = cleaned[i];
        out.add(InlineRun(t, bold: r.bold, italic: r.italic, underline: r.underline, strike: r.strike));
      }
      if (out.isNotEmpty && out.first.text.startsWith('\n')) {
        final f = out.removeAt(0);
        final t = f.text.replaceFirst(RegExp(r'^\n+'), '');
        if (t.isNotEmpty) {
          out.insert(0, InlineRun(t, bold: f.bold, italic: f.italic, underline: f.underline, strike: f.strike));
        }
      }
      if (out.isNotEmpty) blocks.add(TextBlock(out, heading: heading, quote: quote, center: center));
    }
    runs = [];
  }

  void walk(dom.Node node, {bool bold = false, bool italic = false, bool underline = false, bool strike = false}) {
    if (node is dom.Text) {
      runs.add(
          InlineRun(node.text.replaceAll('\n', ' '), bold: bold, italic: italic, underline: underline, strike: strike));
      return;
    }
    if (node is! dom.Element) {
      for (final c in node.nodes) {
        walk(c, bold: bold, italic: italic, underline: underline, strike: strike);
      }
      return;
    }
    final tag = node.localName ?? '';
    if (_skipTags.contains(tag)) return;
    final style = (node.attributes['style'] ?? '').toLowerCase().replaceAll(' ', '');
    if (style.contains('display:none') || style.contains('visibility:hidden')) return;
    switch (tag) {
      case 'br':
        runs.add(const InlineRun('\n'));
        return;
      case 'hr':
        flush();
        blocks.add(const RuleBlock());
        return;
      case 'img':
        final src = ['src', 'data-src', 'data-lazy-src', 'data-original']
            .map((a) => node.attributes[a]?.trim())
            .firstWhere((v) => v != null && v.isNotEmpty && !v.startsWith('data:image/gif'), orElse: () => null);
        if (src != null) {
          flush();
          final resolved = baseUrl != null ? baseUrl.resolve(src).toString() : src;
          // file:// = gambar dari EPUB lokal yang sudah diekstrak.
          if (resolved.startsWith('http') || resolved.startsWith('file://')) blocks.add(ImageBlock(resolved));
        }
        return;
    }
    final isBlock = _blockTags.contains(tag);
    final prev = (heading: heading, quote: quote, center: center);
    if (isBlock) {
      flush();
      if (tag.length == 2 && tag[0] == 'h' && int.tryParse(tag[1]) != null) heading = int.parse(tag[1]);
      if (tag == 'blockquote') quote = true;
      if (tag == 'center' ||
          (node.attributes['style'] ?? '').contains('text-align: center') ||
          node.attributes['align'] == 'center') {
        center = true;
      }
      if (tag == 'li') runs.add(const InlineRun('• '));
    }
    final b = bold ||
        tag == 'b' ||
        tag == 'strong' ||
        style.contains('font-weight:bold') ||
        style.contains('font-weight:700');
    final it = italic || tag == 'i' || tag == 'em' || tag == 'cite' || style.contains('font-style:italic');
    final u = underline || tag == 'u' || tag == 'ins';
    final s = strike || tag == 's' || tag == 'del' || tag == 'strike';
    for (final c in node.nodes) {
      walk(c, bold: b, italic: it, underline: u, strike: s);
    }
    if (tag == 'td' || tag == 'th') runs.add(const InlineRun('  '));
    if (isBlock) {
      flush();
      heading = prev.heading;
      quote = prev.quote;
      center = prev.center;
    }
  }

  walk(fragment);
  flush();
  return blocks;
}

/// Tampilan satu blok dengan gaya pembaca.
class NovelBlockView extends StatelessWidget {
  const NovelBlockView({
    super.key,
    required this.block,
    required this.style,
    required this.justify,
    this.imageHeaders = const {},
  });

  final NovelBlock block;
  final TextStyle style;
  final bool justify;
  final Map<String, String> imageHeaders;

  @override
  Widget build(BuildContext context) {
    final b = block;
    final size = style.fontSize ?? 18;
    switch (b) {
      case RuleBlock():
        return Padding(
          padding: EdgeInsets.symmetric(vertical: size * 0.8),
          child: Divider(color: style.color?.withValues(alpha: 0.3)),
        );
      case ImageBlock():
        return Padding(
          padding: EdgeInsets.symmetric(vertical: size * 0.5),
          child: b.url.startsWith('file://')
              ? Image.file(
                  File.fromUri(Uri.parse(b.url)),
                  fit: BoxFit.fitWidth,
                  errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, color: style.color),
                )
              : CachedNetworkImage(
                  imageUrl: b.url,
                  httpHeaders: imageHeaders,
                  fit: BoxFit.fitWidth,
                  placeholder: (_, __) => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
                  errorWidget: (_, __, ___) => Icon(Icons.broken_image_outlined, color: style.color),
                ),
        );
      case TextBlock():
        final scale = switch (b.heading) { 1 => 1.5, 2 => 1.35, 3 => 1.2, 4 || 5 || 6 => 1.1, _ => 1.0 };
        final base = style.copyWith(
          fontSize: size * scale,
          fontWeight: b.heading > 0 ? FontWeight.w700 : null,
          fontStyle: b.quote ? FontStyle.italic : null,
        );
        Widget text = Text.rich(
          TextSpan(children: [
            for (final r in b.spans)
              TextSpan(
                text: r.text,
                style: TextStyle(
                  fontWeight: r.bold ? FontWeight.w700 : null,
                  fontStyle: r.italic ? FontStyle.italic : null,
                  decoration: TextDecoration.combine([
                    if (r.underline) TextDecoration.underline,
                    if (r.strike) TextDecoration.lineThrough,
                  ]),
                ),
              ),
          ]),
          style: base,
          textAlign: b.center || b.heading > 0
              ? TextAlign.center
              : justify
                  ? TextAlign.justify
                  : TextAlign.start,
        );
        if (b.quote) {
          text = Container(
            padding: EdgeInsets.only(left: size * 0.8),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: style.color?.withValues(alpha: 0.4) ?? Colors.grey, width: 3)),
            ),
            child: text,
          );
        }
        return Padding(padding: EdgeInsets.only(bottom: size * 0.9), child: text);
    }
  }
}

/// Huruf & angka saja, huruf kecil (untuk membandingkan judul).
String _titleKey(String s) => s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');

/// Apakah isi bab sudah dibuka dengan judul bab [title] (blok teks pertama,
/// atau salah satu dari dua blok pertama yang berupa judul). Dipakai agar
/// judul tidak tampil dua kali di pembaca.
bool startsWithTitle(List<NovelBlock> blocks, String title) {
  final want = _titleKey(title);
  if (want.isEmpty) return false;
  var seen = 0;
  for (final b in blocks) {
    if (b is! TextBlock) continue;
    final got = _titleKey(b.plain);
    if (got.isEmpty) continue;
    if (got == want) return true;
    // "Chapter 12" vs "Chapter 12: Judul" (atau sebaliknya), bila blok itu pendek.
    if (got.length <= want.length * 2 + 8 &&
        (got.startsWith(want) || want.startsWith(got)) &&
        got.length >= 6 &&
        (got.length >= want.length * 0.6 || RegExp(r'\d').hasMatch(got))) {
      return true;
    }
    if (++seen >= 2 || b.heading == 0) return false;
  }
  return false;
}
