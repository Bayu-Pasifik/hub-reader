import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';

import '../sources/source_exception.dart';
import 'novel_models.dart';
import 'novel_source.dart';

/// Isi EPUB yang sudah diekstrak: metadata + urutan bab.
class EpubBook {
  EpubBook({
    required this.dir,
    required this.title,
    required this.chapters,
    this.author,
    this.description,
    this.cover,
    this.subjects = const [],
  });

  /// Folder hasil ekstrak.
  final Directory dir;
  final String title;
  final String? author;
  final String? description;

  /// Path file sampul (absolut).
  final String? cover;
  final List<String> subjects;

  /// Href relatif terhadap akar arsip, sesuai urutan spine.
  final List<({String href, String name})> chapters;

  /// Baca folder EPUB yang sudah diekstrak.
  static EpubBook parse(Directory dir, {required String fallbackTitle}) {
    File at(String rel) => File([dir.path, ...rel.split('/')].join(Platform.pathSeparator));

    final container = at('META-INF/container.xml');
    if (!container.existsSync()) {
      throw const SourceException(SourceErrorKind.parse, detail: 'Bukan EPUB: META-INF/container.xml tidak ada.');
    }
    final rootfile = XmlDocument.parse(container.readAsStringSync())
        .findAllElements('rootfile', namespace: '*')
        .map((e) => e.getAttribute('full-path'))
        .whereType<String>()
        .firstOrNull;
    if (rootfile == null) throw const SourceException(SourceErrorKind.parse, detail: 'EPUB tanpa file OPF.');
    final opfFile = at(rootfile);
    if (!opfFile.existsSync()) throw const SourceException(SourceErrorKind.parse, detail: 'File OPF EPUB tidak ada.');
    final opfDir = rootfile.contains('/') ? rootfile.substring(0, rootfile.lastIndexOf('/') + 1) : '';
    final opf = XmlDocument.parse(opfFile.readAsStringSync());

    String? meta(String name) {
      final text = opf.findAllElements(name, namespace: '*').map((e) => e.innerText.trim()).where((t) => t.isNotEmpty);
      return text.isEmpty ? null : text.first;
    }

    // manifest: id → (href, media-type, properties)
    final items = <String, ({String href, String type, String props})>{};
    for (final item in opf.findAllElements('item', namespace: '*')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id == null || href == null) continue;
      items[id] = (
        href: normalize(opfDir + Uri.decodeFull(href)),
        type: item.getAttribute('media-type') ?? '',
        props: item.getAttribute('properties') ?? '',
      );
    }

    // Sampul: EPUB3 properties="cover-image", EPUB2 <meta name="cover">.
    String? coverHref = items.values.where((i) => i.props.split(' ').contains('cover-image')).firstOrNull?.href;
    if (coverHref == null) {
      final coverId = opf
          .findAllElements('meta', namespace: '*')
          .where((m) => m.getAttribute('name') == 'cover')
          .map((m) => m.getAttribute('content'))
          .firstOrNull;
      coverHref = items[coverId]?.href;
    }
    coverHref ??= items.entries
        .where((e) => e.value.type.startsWith('image/') && e.key.toLowerCase().contains('cover'))
        .firstOrNull
        ?.value
        .href;

    final titles = _tocTitles(opf, items, at);
    final spine = [
      for (final ref in opf.findAllElements('itemref', namespace: '*'))
        if (items[ref.getAttribute('idref')] case final item?)
          if (item.type.contains('html') && ref.getAttribute('linear') != 'no') item.href,
    ];
    final chapters = <({String href, String name})>[];
    for (final href in spine) {
      final file = at(href);
      if (!file.existsSync()) continue;
      var name = titles[href];
      if (name == null) {
        // Tanpa entri TOC: judul dari heading pertama, lewati halaman kosong.
        final doc = html_parser.parse(file.readAsStringSync());
        final text = doc.body?.text.trim() ?? '';
        if (text.isEmpty && doc.querySelector('img, image') == null) continue;
        name = doc.querySelector('h1, h2, h3')?.text.trim();
        if (name == null || name.isEmpty) name = 'Bagian ${chapters.length + 1}';
      }
      chapters.add((href: href, name: name.replaceAll(RegExp(r'\s+'), ' ')));
    }

    return EpubBook(
      dir: dir,
      title: meta('title') ?? fallbackTitle,
      author: meta('creator'),
      description: _stripTags(meta('description')),
      subjects: [
        for (final s in opf.findAllElements('subject', namespace: '*'))
          if (s.innerText.trim().isNotEmpty) s.innerText.trim(),
      ],
      cover: coverHref != null && at(coverHref).existsSync() ? at(coverHref).path : null,
      chapters: chapters,
    );
  }

  /// Judul per file dari daftar isi EPUB3 (nav) atau EPUB2 (NCX). Bila
  /// beberapa entri menunjuk file yang sama, yang pertama dipakai.
  static Map<String, String> _tocTitles(
    XmlDocument opf,
    Map<String, ({String href, String type, String props})> items,
    File Function(String) at,
  ) {
    final titles = <String, String>{};
    void add(String baseDir, String? src, String? label) {
      if (src == null || label == null || label.trim().isEmpty) return;
      final href = normalize(baseDir + Uri.decodeFull(src.split('#').first));
      titles.putIfAbsent(href, () => label.trim());
    }

    String dirOf(String href) => href.contains('/') ? href.substring(0, href.lastIndexOf('/') + 1) : '';

    final nav = items.values.where((i) => i.props.split(' ').contains('nav')).firstOrNull;
    if (nav != null && at(nav.href).existsSync()) {
      final doc = html_parser.parse(at(nav.href).readAsStringSync());
      final toc = doc.querySelectorAll('nav').where((n) => (n.attributes['epub:type'] ?? '').contains('toc')).firstOrNull ??
          doc.querySelector('nav');
      for (final a in toc?.querySelectorAll('a') ?? const <dom.Element>[]) {
        add(dirOf(nav.href), a.attributes['href'], a.text);
      }
    }
    if (titles.isEmpty) {
      final ncx = items.values.where((i) => i.type == 'application/x-dtbncx+xml').firstOrNull;
      if (ncx != null && at(ncx.href).existsSync()) {
        final doc = XmlDocument.parse(at(ncx.href).readAsStringSync());
        for (final point in doc.findAllElements('navPoint', namespace: '*')) {
          final label = point.findElements('navLabel', namespace: '*').firstOrNull?.innerText;
          final src = point.findElements('content', namespace: '*').firstOrNull?.getAttribute('src');
          add(dirOf(ncx.href), src, label);
        }
      }
    }
    return titles;
  }

  static String? _stripTags(String? s) {
    if (s == null) return null;
    final text = html_parser.parseFragment(s).text?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  /// Rapikan path relatif ("a/./b/../c" → "a/c"). Null-kan yang keluar akar.
  static String normalize(String path) {
    final out = <String>[];
    for (final seg in path.split('/')) {
      if (seg.isEmpty || seg == '.') continue;
      if (seg == '..') {
        if (out.isNotEmpty) out.removeLast();
        continue;
      }
      out.add(seg);
    }
    return out.join('/');
  }
}

/// Novel EPUB dari penyimpanan perangkat, tampil di tab Novel sebagai
/// sumber "Lokal". Tidak memakai mesin plugin JS.
///
/// File disimpan di [root]; path novel `epub:/<nama file>` dan path bab
/// `epub:/<nama file>#<href>` (keduanya di-percent-encode).
class LocalNovelSource extends NovelSource {
  LocalNovelSource() : super.custom(info: pluginInfo);

  static const pluginId = 'local';
  static const pluginInfo = NovelPluginInfo(
    id: pluginId,
    name: 'Lokal (EPUB)',
    site: 'local',
    lang: 'local',
    version: '1',
    url: '',
  );

  static Directory? root;
  static Directory? cacheDir;

  static const _scheme = 'epub:/';
  static final _books = <String, EpubBook>{};

  static String novelPath(String fileName) => '$_scheme${Uri.encodeComponent(fileName)}';

  static ({String file, String? href}) parsePath(String path) {
    if (!path.startsWith(_scheme)) throw SourceException(SourceErrorKind.parse, detail: 'Bukan path EPUB: $path');
    final rest = path.substring(_scheme.length);
    final hash = rest.indexOf('#');
    final file = Uri.decodeComponent(hash < 0 ? rest : rest.substring(0, hash));
    if (file.isEmpty || file.contains('/') || file.contains(r'\') || file == '..') {
      throw SourceException(SourceErrorKind.parse, detail: 'Path EPUB tidak valid: $path');
    }
    return (file: file, href: hash < 0 ? null : Uri.decodeComponent(rest.substring(hash + 1)));
  }

  static File _file(String name) {
    final r = root;
    if (r == null) throw const SourceException(SourceErrorKind.unknown, detail: 'Folder lokal belum siap.');
    return File('${r.path}${Platform.pathSeparator}$name');
  }

  /// Ekstrak (sekali per versi file) lalu parse.
  static Future<EpubBook> book(String fileName) async {
    final file = _file(fileName);
    if (!await file.exists()) {
      throw SourceException(SourceErrorKind.notFound, detail: 'File "$fileName" tidak ada lagi.');
    }
    final stat = await file.stat();
    final key = '$fileName|${stat.size}|${stat.modified.millisecondsSinceEpoch}';
    final cached = _books[key];
    if (cached != null) return cached;
    final cache = cacheDir;
    if (cache == null) throw const SourceException(SourceErrorKind.unknown, detail: 'Folder cache belum siap.');
    final dir = Directory('${cache.path}${Platform.pathSeparator}${_fnv(key)}');
    final done = File('${dir.path}${Platform.pathSeparator}.done');
    if (!await done.exists()) {
      if (await dir.exists()) await dir.delete(recursive: true);
      await dir.create(recursive: true);
      await extractSafely(file.path, dir);
      await done.writeAsString('ok');
    }
    final stem = fileName.toLowerCase().endsWith('.epub') ? fileName.substring(0, fileName.length - 5) : fileName;
    final parsed = EpubBook.parse(dir, fallbackTitle: stem);
    return _books[key] = parsed;
  }

  /// Ekstrak ZIP dengan menjaga struktur folder, tapi entri yang keluar dari
  /// [out] (`../`, path absolut) dilewati.
  static Future<void> extractSafely(String zipPath, Directory out) async {
    final input = InputFileStream(zipPath);
    try {
      final archive = ZipDecoder().decodeStream(input);
      for (final entry in archive.files) {
        if (!entry.isFile) continue;
        final raw = entry.name.replaceAll(r'\', '/');
        if (raw.startsWith('/') || raw.split('/').contains('..') || RegExp(r'^[A-Za-z]:').hasMatch(raw)) continue;
        final rel = EpubBook.normalize(raw);
        if (rel.isEmpty) continue;
        final target = File([out.path, ...rel.split('/')].join(Platform.pathSeparator));
        await target.parent.create(recursive: true);
        final bytes = entry.readBytes();
        if (bytes != null) await target.writeAsBytes(bytes, flush: false);
      }
    } on FormatException catch (e) {
      throw SourceException(SourceErrorKind.parse, detail: 'EPUB rusak: ${e.message}');
    } finally {
      await input.close();
    }
  }

  static String _fnv(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  Future<List<NovelItem>> _all() async {
    final r = root;
    if (r == null || !await r.exists()) return const [];
    final files = [
      await for (final e in r.list(followLinks: false))
        if (e is File && e.path.toLowerCase().endsWith('.epub')) e,
    ];
    final items = <NovelItem>[];
    for (final f in files) {
      final name = f.uri.pathSegments.last;
      try {
        final b = await book(name);
        items.add(NovelItem(path: novelPath(name), name: b.title, cover: b.cover));
      } catch (_) {
        items.add(NovelItem(path: novelPath(name), name: '$name (rusak)'));
      }
    }
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  @override
  Future<List<NovelItem>> popular(int page, {bool latest = false, NovelFilterValues filters = const {}}) async =>
      page == 1 ? _all() : const [];

  @override
  Future<List<NovelItem>> search(String query, int page) async {
    if (page != 1) return const [];
    final q = query.trim().toLowerCase();
    return [for (final n in await _all()) if (n.name.toLowerCase().contains(q)) n];
  }

  @override
  Future<Map<String, Object?>> detailsRaw(String path) async {
    final file = parsePath(path).file;
    final b = await book(file);
    return {
      'path': path,
      'name': b.title,
      'cover': b.cover,
      'author': b.author,
      'summary': b.description,
      'genres': b.subjects.join(', '),
      'status': 'Completed',
      'chapters': [
        for (final (i, c) in b.chapters.indexed)
          {'path': '${novelPath(file)}#${Uri.encodeComponent(c.href)}', 'name': c.name, 'chapterNumber': i + 1},
      ],
    };
  }

  @override
  Future<Map<String, Object?>> chapterPageRaw(String path, int page) async =>
      {'chapters': (await detailsRaw(path))['chapters']};

  /// HTML isi bab; gambar diarahkan ke file hasil ekstrak (`file://`).
  @override
  Future<String> chapter(String path) async {
    final p = parsePath(path);
    final href = p.href;
    if (href == null) throw const SourceException(SourceErrorKind.parse, detail: 'Path bab EPUB tanpa href.');
    final b = await book(p.file);
    final rel = EpubBook.normalize(href);
    final file = File([b.dir.path, ...rel.split('/')].join(Platform.pathSeparator));
    if (!await file.exists()) throw const SourceException(SourceErrorKind.notFound, detail: 'Bab tidak ada di EPUB.');
    final doc = html_parser.parse(await file.readAsString());
    final baseDir = rel.contains('/') ? rel.substring(0, rel.lastIndexOf('/') + 1) : '';
    String? local(String? src) {
      if (src == null || src.isEmpty || src.startsWith('data:') || src.contains('://')) return null;
      final target = EpubBook.normalize(baseDir + Uri.decodeFull(src.split('#').first));
      final f = File([b.dir.path, ...target.split('/')].join(Platform.pathSeparator));
      return f.existsSync() ? f.uri.toString() : null;
    }

    for (final img in doc.querySelectorAll('img')) {
      final url = local(img.attributes['src']);
      if (url != null) img.attributes['src'] = url;
    }
    // Gambar SVG (<image xlink:href>) di halaman sampul → <img>.
    for (final image in doc.querySelectorAll('image')) {
      // Atribut asing SVG disimpan sebagai AttributeName (xlink:href), bukan String.
      final href = image.attributes.entries.where((e) => '${e.key}'.endsWith('href')).map((e) => e.value).firstOrNull;
      final url = local(href);
      final svg = image.parent?.localName == 'svg' ? image.parent! : image;
      svg.replaceWith(url == null ? dom.Text('') : (dom.Element.tag('img')..attributes['src'] = url));
    }
    return doc.body?.innerHtml ?? '';
  }

  @override
  Future<String> webUrl(String path, {required bool isNovel}) async =>
      throw const SourceException(SourceErrorKind.unknown, detail: 'Novel lokal tidak punya halaman web.');

  /// Salin file EPUB ke [root]. Mengembalikan path novel.
  static Future<String> importFile(String name, Future<void> Function(String path) saveTo) async {
    final r = root;
    if (r == null) throw const SourceException(SourceErrorKind.unknown, detail: 'Folder lokal belum siap.');
    await r.create(recursive: true);
    var safe = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').trim().replaceAll(RegExp(r'^\.+'), '');
    if (safe.isEmpty) safe = 'buku.epub';
    if (!safe.toLowerCase().endsWith('.epub')) safe = '$safe.epub';
    var target = File('${r.path}${Platform.pathSeparator}$safe');
    for (var n = 2; await target.exists(); n++) {
      target = File('${r.path}${Platform.pathSeparator}${safe.substring(0, safe.length - 5)} ($n).epub');
    }
    await saveTo(target.path);
    return novelPath(target.uri.pathSegments.last);
  }

  /// Hapus file EPUB.
  static Future<void> delete(String path) async {
    final f = _file(parsePath(path).file);
    if (await f.exists()) await f.delete();
  }
}
