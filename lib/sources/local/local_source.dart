import 'dart:io';

import 'package:archive/archive_io.dart';

import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

/// Komik dari penyimpanan perangkat (Mihon "Local source").
///
/// Struktur folder [root]:
/// ```
/// <root>/
///   Judul Seri/            satu seri
///     cover.jpg            sampul (opsional; default halaman pertama)
///     Chapter 1.cbz        satu bab per arsip CBZ/ZIP …
///     Chapter 2/           … atau per folder berisi gambar
///   Komik Satuan.cbz       arsip di akar = seri dengan satu bab
/// ```
///
/// URL seri & bab: `local:/<segmen>/<segmen>` (relatif terhadap [root],
/// tiap segmen di-percent-encode) agar tetap berlaku setelah dipulihkan di
/// perangkat lain.
class LocalSource extends MangaSource {
  LocalSource();

  static const sourceId = 'local';
  static const _scheme = 'local:/';
  static const archiveExtensions = {'.cbz', '.zip'};
  static const imageExtensions = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.avif', '.bmp'};

  /// Folder komik lokal; diisi saat startup (lihat `AppDependencies`).
  static Directory? root;

  /// Folder hasil ekstrak arsip (boleh dihapus kapan saja).
  static Directory? cacheDir;

  static const _pageSize = 60;

  @override
  String get id => sourceId;
  @override
  String get name => 'Lokal';
  @override
  String get lang => 'local';
  @override
  String get baseUrl => root?.path ?? 'local';
  @override
  ContentWarning get contentWarning => ContentWarning.safe;
  @override
  bool get supportsLatest => true;

  @override
  Map<String, String> imageHeaders({String? referer}) => const {};

  Directory get _root {
    final r = root;
    if (r == null) throw const SourceException(SourceErrorKind.unknown, detail: 'Folder lokal belum siap.');
    return r;
  }

  // ------------------------------------------------------------- URL

  static String urlFor(List<String> segments) => '$_scheme${segments.map(Uri.encodeComponent).join('/')}';

  static List<String> segmentsOf(String url) {
    if (!url.startsWith(_scheme)) {
      throw SourceException(SourceErrorKind.parse, detail: 'Bukan URL lokal: $url');
    }
    final segments = url.substring(_scheme.length).split('/').map(Uri.decodeComponent).toList();
    // Tolak "..": URL hanya boleh menunjuk ke dalam [root].
    if (segments.any((s) => s.isEmpty || s == '.' || s == '..')) {
      throw SourceException(SourceErrorKind.parse, detail: 'URL lokal tidak valid: $url');
    }
    return segments;
  }

  String _pathOf(String url) => [_root.path, ...segmentsOf(url)].join(Platform.pathSeparator);

  // ---------------------------------------------------------- daftar

  static String _ext(String path) {
    final name = path.split(RegExp(r'[\\/]')).last;
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? '' : name.substring(dot).toLowerCase();
  }

  static String _baseName(String path) => path.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).last;

  static String _stem(String path) {
    final name = _baseName(path);
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  static bool isArchive(String path) => archiveExtensions.contains(_ext(path));
  static bool isImage(String path) => imageExtensions.contains(_ext(path));

  /// Urutan alami: "Chapter 2" sebelum "Chapter 10".
  static int naturalCompare(String a, String b) {
    final re = RegExp(r'(\d+)|(\D+)');
    final pa = re.allMatches(a.toLowerCase()).map((m) => m[0]!).toList();
    final pb = re.allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
    for (var i = 0; i < pa.length && i < pb.length; i++) {
      final na = int.tryParse(pa[i]), nb = int.tryParse(pb[i]);
      final c = na != null && nb != null ? na.compareTo(nb) : pa[i].compareTo(pb[i]);
      if (c != 0) return c;
    }
    return pa.length.compareTo(pb.length);
  }

  /// Semua seri, urut terbaru diubah dulu bila [latest].
  Future<List<({SourceManga manga, DateTime modified})>> _allSeries() async {
    final dir = _root;
    if (!await dir.exists()) return const [];
    final out = <({SourceManga manga, DateTime modified})>[];
    await for (final e in dir.list(followLinks: false)) {
      final name = _baseName(e.path);
      if (name.startsWith('.')) continue;
      if (e is Directory) {
        out.add((
          manga: SourceManga(url: urlFor([name]), title: name, thumbnailUrl: await _cover(e)),
          modified: (await e.stat()).modified,
        ));
      } else if (e is File && isArchive(e.path)) {
        out.add((
          manga: SourceManga(url: urlFor([name]), title: _stem(name), thumbnailUrl: _cachedCover(e.path)),
          modified: (await e.stat()).modified,
        ));
      }
    }
    return out;
  }

  MangaPage _page(List<SourceManga> all, int page) {
    final start = (page - 1) * _pageSize;
    if (start >= all.length) return const MangaPage([], hasNextPage: false);
    final end = (start + _pageSize).clamp(0, all.length);
    return MangaPage(all.sublist(start, end), hasNextPage: end < all.length);
  }

  @override
  Future<MangaPage> popular(int page) async {
    final all = (await _allSeries()).map((s) => s.manga).toList()..sort((a, b) => naturalCompare(a.title, b.title));
    return _page(all, page);
  }

  @override
  Future<MangaPage> latest(int page) async {
    final all = (await _allSeries())..sort((a, b) => b.modified.compareTo(a.modified));
    return _page([for (final s in all) s.manga], page);
  }

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    final q = query.trim().toLowerCase();
    final all = (await _allSeries()).map((s) => s.manga).where((m) => m.title.toLowerCase().contains(q)).toList()
      ..sort((a, b) => naturalCompare(a.title, b.title));
    return _page(all, page);
  }

  // ----------------------------------------------------------- detail

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final segments = segmentsOf(mangaUrl);
    final path = _pathOf(mangaUrl);
    if (await FileSystemEntity.isFile(path)) {
      // Arsip tunggal di akar: seri satu bab.
      final file = File(path);
      return SourceMangaDetails(
        url: mangaUrl,
        title: _stem(path),
        thumbnailUrl: _cachedCover(path) ?? await _tryExtractCover(path),
        chapters: [
          SourceChapter(url: mangaUrl, name: _stem(path), number: 1, uploadedAt: (await file.stat()).modified),
        ],
      );
    }
    final dir = Directory(path);
    if (!await dir.exists()) {
      throw SourceException(SourceErrorKind.notFound, detail: 'Folder "${segments.last}" tidak ada lagi.');
    }
    final chapters = <SourceChapter>[];
    var hasLooseImages = false;
    await for (final e in dir.list(followLinks: false)) {
      final name = _baseName(e.path);
      if (name.startsWith('.')) continue;
      if (e is File && isImage(e.path)) {
        if (!_stem(name).toLowerCase().startsWith('cover')) hasLooseImages = true;
        continue;
      }
      final isChapter = (e is File && isArchive(e.path)) || (e is Directory && await _hasImages(e));
      if (!isChapter) continue;
      final stem = e is File ? _stem(name) : name;
      chapters.add(SourceChapter(
        url: urlFor([...segments, name]),
        name: stem,
        number: _chapterNumber(stem),
        uploadedAt: (await e.stat()).modified,
      ));
    }
    // Folder seri yang langsung berisi gambar = satu bab.
    if (chapters.isEmpty && hasLooseImages) {
      chapters.add(SourceChapter(url: mangaUrl, name: segments.last, number: 1));
    }
    chapters.sort((a, b) => naturalCompare(b.name, a.name)); // terbaru di atas
    return SourceMangaDetails(
      url: mangaUrl,
      title: segments.last,
      thumbnailUrl: await _cover(dir, extract: true),
      description: await _readText(dir, const ['description.txt', 'details.txt']),
      chapters: chapters,
    );
  }

  static final _numberRe = RegExp(r'(\d+(?:[.,]\d+)?)');

  static double? _chapterNumber(String name) {
    final matches = _numberRe.allMatches(name).toList();
    if (matches.isEmpty) return null;
    // Ambil angka setelah kata bab bila ada, kalau tidak angka terakhir.
    final labelled = RegExp(r'(?:ch(?:apter)?|bab|ep(?:isode)?)\.?\s*(\d+(?:[.,]\d+)?)', caseSensitive: false).firstMatch(name);
    final raw = labelled?.group(1) ?? matches.last.group(1)!;
    return double.tryParse(raw.replaceAll(',', '.'));
  }

  static Future<String?> _readText(Directory dir, List<String> names) async {
    for (final n in names) {
      final f = File('${dir.path}${Platform.pathSeparator}$n');
      if (await f.exists()) {
        final text = (await f.readAsString()).trim();
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  static Future<bool> _hasImages(Directory dir) async {
    await for (final e in dir.list(followLinks: false)) {
      if (e is File && isImage(e.path)) return true;
    }
    return false;
  }

  /// `cover.*` di folder seri, atau gambar pertama bab pertama yang sudah
  /// diekstrak/berupa folder.
  Future<String?> _cover(Directory dir, {bool extract = false}) async {
    final images = <File>[];
    final chapterDirs = <Directory>[];
    final archives = <File>[];
    await for (final e in dir.list(followLinks: false)) {
      if (e is File && isImage(e.path)) {
        if (_stem(e.path).toLowerCase() == 'cover') return e.path;
        images.add(e);
      } else if (e is Directory) {
        chapterDirs.add(e);
      } else if (e is File && isArchive(e.path)) {
        archives.add(e);
      }
    }
    if (images.isNotEmpty) {
      images.sort((a, b) => naturalCompare(a.path, b.path));
      return images.first.path;
    }
    chapterDirs.sort((a, b) => naturalCompare(a.path, b.path));
    for (final d in chapterDirs) {
      final pages = await _folderPages(d);
      if (pages.isNotEmpty) return pages.first;
    }
    archives.sort((a, b) => naturalCompare(a.path, b.path));
    for (final a in archives) {
      final cached = _cachedCover(a.path);
      if (cached != null) return cached;
    }
    // Detail seri: ekstrak bab pertama sekali untuk sampul. Daftar seri
    // hanya memakai yang sudah diekstrak (supaya menjelajah tetap cepat).
    if (extract && archives.isNotEmpty) {
      try {
        return (await extractArchive(archives.first.path)).first;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  // ---------------------------------------------------------- halaman

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final path = _pathOf(chapter.url);
    if (await FileSystemEntity.isDirectory(path)) {
      final pages = await _folderPages(Directory(path));
      if (pages.isEmpty) throw const SourceException(SourceErrorKind.parse, detail: 'Folder bab tidak berisi gambar.');
      return pages;
    }
    if (!await File(path).exists()) {
      throw const SourceException(SourceErrorKind.notFound, detail: 'File bab tidak ada lagi.');
    }
    return extractArchive(path);
  }

  static Future<List<String>> _folderPages(Directory dir) async {
    final files = <String>[
      await for (final e in dir.list(followLinks: false))
        if (e is File && isImage(e.path) && _stem(e.path).toLowerCase() != 'cover') e.path,
    ]..sort(naturalCompare);
    return files;
  }

  /// Folder ekstrak untuk satu arsip: nama berdasar path + ukuran + waktu
  /// ubah, jadi arsip yang diganti otomatis diekstrak ulang.
  static Directory? _extractDirFor(String archivePath) {
    final cache = cacheDir;
    if (cache == null) return null;
    final stat = File(archivePath).statSync();
    final key = _fnv('$archivePath|${stat.size}|${stat.modified.millisecondsSinceEpoch}');
    return Directory('${cache.path}${Platform.pathSeparator}$key');
  }

  static Future<String?> _tryExtractCover(String archivePath) async {
    try {
      return (await extractArchive(archivePath)).first;
    } catch (_) {
      return null;
    }
  }

  static String? _cachedCover(String archivePath) {
    try {
      final dir = _extractDirFor(archivePath);
      if (dir == null || !File('${dir.path}${Platform.pathSeparator}.done').existsSync()) return null;
      final pages = dir.listSync().whereType<File>().where((f) => isImage(f.path)).map((f) => f.path).toList()
        ..sort(naturalCompare);
      return pages.firstOrNull;
    } catch (_) {
      return null;
    }
  }

  /// Ekstrak gambar dari CBZ/ZIP ke cache, urut alami. Nama file keluaran
  /// diganti nomor urut (bukan nama di arsip) supaya entri berbahaya seperti
  /// `../x` tidak bisa menulis di luar folder cache.
  static Future<List<String>> extractArchive(String archivePath) async {
    final dir = _extractDirFor(archivePath);
    if (dir == null) throw const SourceException(SourceErrorKind.unknown, detail: 'Folder cache belum siap.');
    final done = File('${dir.path}${Platform.pathSeparator}.done');
    if (!await done.exists()) {
      if (await dir.exists()) await dir.delete(recursive: true);
      await dir.create(recursive: true);
      final input = InputFileStream(archivePath);
      try {
        final archive = ZipDecoder().decodeStream(input);
        final entries = archive.files.where((f) => f.isFile && isImage(f.name) && !f.name.contains('__MACOSX')).toList()
          ..sort((a, b) => naturalCompare(a.name, b.name));
        for (final (i, entry) in entries.indexed) {
          final bytes = entry.readBytes();
          if (bytes == null) continue;
          final out = File('${dir.path}${Platform.pathSeparator}${(i + 1).toString().padLeft(4, '0')}${_ext(entry.name)}');
          await out.writeAsBytes(bytes, flush: false);
        }
      } on FormatException catch (e) {
        throw SourceException(SourceErrorKind.parse, detail: 'Arsip rusak: ${e.message}');
      } finally {
        await input.close();
      }
      await done.writeAsString('ok');
    }
    final pages = [
      await for (final e in dir.list())
        if (e is File && isImage(e.path)) e.path,
    ]..sort(naturalCompare);
    if (pages.isEmpty) throw const SourceException(SourceErrorKind.parse, detail: 'Arsip tidak berisi gambar.');
    return pages;
  }

  static String _fnv(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  // ------------------------------------------------------------- impor

  /// Salin arsip/gambar ke folder seri [series]. [files] memberi nama asli
  /// dan cara menyalin isinya ke path tujuan (file picker Android memberi
  /// content URI, bukan path). Mengembalikan URL seri.
  static Future<String> importFiles(
    String series,
    List<({String name, Future<void> Function(String path) saveTo})> files,
  ) async {
    final r = root;
    if (r == null) throw const SourceException(SourceErrorKind.unknown, detail: 'Folder lokal belum siap.');
    final safe = sanitizeName(series);
    final dir = Directory('${r.path}${Platform.pathSeparator}$safe');
    await dir.create(recursive: true);
    for (final f in files) {
      var name = sanitizeName(f.name);
      var target = File('${dir.path}${Platform.pathSeparator}$name');
      for (var n = 2; await target.exists(); n++) {
        final dot = name.lastIndexOf('.');
        final alt = dot <= 0 ? '$name ($n)' : '${name.substring(0, dot)} ($n)${name.substring(dot)}';
        target = File('${dir.path}${Platform.pathSeparator}$alt');
      }
      await f.saveTo(target.path);
    }
    return urlFor([safe]);
  }

  /// Nama file/folder yang aman di Android.
  static String sanitizeName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').trim();
    final noDots = cleaned.replaceAll(RegExp(r'^\.+'), '');
    return noDots.isEmpty ? 'Tanpa judul' : noDots;
  }

  /// Hapus seri (folder atau arsip tunggal) dari penyimpanan.
  Future<void> deleteSeries(String mangaUrl) async {
    final path = _pathOf(mangaUrl);
    final type = await FileSystemEntity.type(path);
    if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    } else if (type == FileSystemEntityType.file) {
      await File(path).delete();
    }
  }
}
