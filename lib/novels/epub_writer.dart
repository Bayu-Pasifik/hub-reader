import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Satu bab untuk diekspor: judul + HTML isi (dari plugin / unduhan).
class EpubChapter {
  const EpubChapter({required this.title, required this.html});

  final String title;
  final String html;
}

/// Membuat file EPUB 3 (dengan NCX untuk pembaca EPUB 2) dari bab-bab novel.
///
/// HTML dari situs dibersihkan menjadi XHTML yang valid: hanya tag teks
/// yang aman, atribut dibuang, gambar jarak jauh dilewati (pembaca EPUB
/// tidak memuat gambar dari internet).
class EpubWriter {
  EpubWriter({
    required this.title,
    required this.chapters,
    this.author,
    this.description,
    this.language = 'id',
    this.subjects = const [],
    this.cover,
    String? identifier,
    DateTime? modified,
  })  : identifier = identifier ?? 'urn:hub-reader:${_slug(title)}',
        modified = (modified ?? DateTime.now()).toUtc();

  final String title;
  final String? author;
  final String? description;
  final String language;
  final List<String> subjects;
  final List<EpubChapter> chapters;

  /// Byte gambar sampul (JPEG/PNG/WebP/GIF), opsional.
  final Uint8List? cover;
  final String identifier;
  final DateTime modified;

  static const _keep = {
    'p', 'br', 'hr', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'em', 'strong', 'b', 'i', 'u', 's', //
    'blockquote', 'ul', 'ol', 'li', 'sup', 'sub', 'small', 'pre', 'code', 'table', 'tr', 'td', 'th',
    'tbody', 'thead',
  };
  static const _void = {'br', 'hr'};

  static const _drop = {'script', 'style', 'noscript', 'iframe', 'img', 'svg', 'button', 'form', 'input', 'head'};

  static String escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      // Karakter kontrol tidak valid di XML 1.0.
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

  /// HTML bebas → potongan XHTML yang well-formed.
  static String sanitize(String html) {
    final out = StringBuffer();
    void walk(dom.Node node) {
      if (node is dom.Text) {
        out.write(escape(node.text));
        return;
      }
      if (node is! dom.Element) return;
      final tag = node.localName ?? '';
      if (_drop.contains(tag)) return;
      if (_keep.contains(tag)) {
        if (_void.contains(tag)) {
          out.write('<$tag/>');
          return;
        }
        out.write('<$tag>');
        node.nodes.forEach(walk);
        out.write('</$tag>');
        return;
      }
      // Tag lain (div, span, …): isinya saja. div tanpa <p> di dalamnya
      // dijadikan paragraf supaya baris tidak menyatu.
      final blockish = tag == 'div' && node.querySelector('p, div, h1, h2, h3, h4, h5, h6, ul, ol, table') == null;
      if (blockish && node.text.trim().isNotEmpty) {
        out.write('<p>');
        node.nodes.forEach(walk);
        out.write('</p>');
      } else {
        node.nodes.forEach(walk);
      }
    }

    final fragment = html_parser.parseFragment(html);
    fragment.nodes.forEach(walk);
    return out.toString();
  }

  static String _slug(String s) {
    final slug = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'novel' : slug;
  }

  static ({String ext, String mime})? _imageType(Uint8List b) {
    if (b.length > 3 && b[0] == 0xFF && b[1] == 0xD8) return (ext: 'jpg', mime: 'image/jpeg');
    if (b.length > 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
      return (ext: 'png', mime: 'image/png');
    }
    if (b.length > 12 && ascii.decode(b.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(b.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return (ext: 'webp', mime: 'image/webp');
    }
    if (b.length > 6 && ascii.decode(b.sublist(0, 3), allowInvalid: true) == 'GIF') return (ext: 'gif', mime: 'image/gif');
    return null;
  }

  String _page(String pageTitle, String body) => '<?xml version="1.0" encoding="utf-8"?>\n'
      '<!DOCTYPE html>\n'
      '<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" '
      'xml:lang="${escape(language)}" lang="${escape(language)}">\n'
      '<head><meta charset="utf-8"/><title>${escape(pageTitle)}</title>'
      '<link rel="stylesheet" type="text/css" href="style.css"/></head>\n'
      '<body>\n$body\n</body>\n</html>\n';

  static String _chapterFile(int i) => 'chapter-${(i + 1).toString().padLeft(4, '0')}.xhtml';

  /// Byte file .epub.
  Uint8List build() {
    final archive = Archive();
    void text(String name, String content, {bool store = false}) {
      final file = ArchiveFile.bytes(name, utf8.encode(content));
      if (store) file.compression = CompressionType.none;
      archive.addFile(file);
    }

    // mimetype wajib pertama dan tidak dikompres.
    text('mimetype', 'application/epub+zip', store: true);
    text('META-INF/container.xml', '<?xml version="1.0" encoding="utf-8"?>\n'
        '<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">\n'
        '<rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>\n'
        '</container>\n');
    text('OEBPS/style.css', 'body{font-family:serif;line-height:1.5;margin:0 4%}'
        'h1,h2,h3{text-align:center;line-height:1.2}p{text-indent:1.2em;margin:0 0 .6em}'
        '.cover{text-align:center;margin:0;padding:0}.cover img{max-width:100%;max-height:100%}');

    final coverType = cover == null ? null : _imageType(cover!);
    final manifest = StringBuffer()
      ..writeln('<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>')
      ..writeln('<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>')
      ..writeln('<item id="css" href="style.css" media-type="text/css"/>');
    final spine = StringBuffer();
    if (coverType != null) {
      archive.addFile(ArchiveFile.bytes('OEBPS/cover.${coverType.ext}', cover!));
      manifest
        ..writeln('<item id="cover-image" href="cover.${coverType.ext}" media-type="${coverType.mime}" '
            'properties="cover-image"/>')
        ..writeln('<item id="cover" href="cover.xhtml" media-type="application/xhtml+xml"/>');
      spine.writeln('<itemref idref="cover" linear="yes"/>');
      text('OEBPS/cover.xhtml',
          _page(title, '<div class="cover"><img src="cover.${coverType.ext}" alt="${escape(title)}"/></div>'));
    }

    final navItems = StringBuffer();
    final ncxPoints = StringBuffer();
    for (final (i, c) in chapters.indexed) {
      final file = _chapterFile(i);
      final body = sanitize(c.html);
      // Banyak situs sudah menaruh judul bab di isi; jangan dobel.
      final hasHeading = RegExp(r'^\s*<h[1-3]>').hasMatch(body);
      text('OEBPS/$file', _page(c.title, '${hasHeading ? '' : '<h2>${escape(c.title)}</h2>\n'}$body'));
      manifest.writeln('<item id="c${i + 1}" href="$file" media-type="application/xhtml+xml"/>');
      spine.writeln('<itemref idref="c${i + 1}"/>');
      navItems.writeln('<li><a href="$file">${escape(c.title)}</a></li>');
      ncxPoints.writeln('<navPoint id="n${i + 1}" playOrder="${i + 1}"><navLabel><text>${escape(c.title)}</text>'
          '</navLabel><content src="$file"/></navPoint>');
    }

    text('OEBPS/nav.xhtml',
        _page('Daftar isi', '<nav epub:type="toc" id="toc"><h1>Daftar isi</h1><ol>\n$navItems</ol></nav>'));
    text('OEBPS/toc.ncx', '<?xml version="1.0" encoding="utf-8"?>\n'
        '<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">\n'
        '<head><meta name="dtb:uid" content="${escape(identifier)}"/></head>\n'
        '<docTitle><text>${escape(title)}</text></docTitle>\n'
        '<navMap>\n$ncxPoints</navMap>\n</ncx>\n');

    final stamp = '${modified.toIso8601String().split('.').first}Z';
    text('OEBPS/content.opf', '<?xml version="1.0" encoding="utf-8"?>\n'
        '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid" '
        'xml:lang="${escape(language)}">\n'
        '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">\n'
        '<dc:identifier id="bookid">${escape(identifier)}</dc:identifier>\n'
        '<dc:title>${escape(title)}</dc:title>\n'
        '<dc:language>${escape(language)}</dc:language>\n'
        '${author == null ? '' : '<dc:creator>${escape(author!)}</dc:creator>\n'}'
        '${description == null ? '' : '<dc:description>${escape(description!)}</dc:description>\n'}'
        '${subjects.map((s) => '<dc:subject>${escape(s)}</dc:subject>\n').join()}'
        '<meta property="dcterms:modified">$stamp</meta>\n'
        '${coverType == null ? '' : '<meta name="cover" content="cover-image"/>\n'}'
        '</metadata>\n'
        '<manifest>\n$manifest</manifest>\n'
        '<spine toc="ncx">\n$spine</spine>\n'
        '</package>\n');

    return ZipEncoder().encodeBytes(archive);
  }
}
