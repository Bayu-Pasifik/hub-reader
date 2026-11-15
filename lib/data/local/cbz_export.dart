import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/download.dart';
import 'download_store.dart';

/// Ekspor bab komik yang sudah diunduh menjadi arsip CBZ (ZIP berisi gambar
/// berurutan + `ComicInfo.xml`), supaya bisa dibaca di aplikasi lain.
class CbzExport {
  const CbzExport._();

  /// Nama file aman untuk bab: `<Seri> - <Bab>.cbz`.
  static String fileName(DownloadedChapter chapter) {
    final name = '${chapter.mangaTitle} - ${chapter.chapterName}'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return '${name.length > 120 ? name.substring(0, 120) : name}.cbz';
  }

  /// Isi `ComicInfo.xml` (dibaca Komga, Kavita, Tachiyomi/Mihon, dll).
  static String comicInfo({required String series, required String title, required int pageCount}) {
    String esc(String s) => s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
    return '<?xml version="1.0" encoding="utf-8"?>\n'
        '<ComicInfo>\n'
        '  <Series>${esc(series)}</Series>\n'
        '  <Title>${esc(title)}</Title>\n'
        '  <PageCount>$pageCount</PageCount>\n'
        '</ComicInfo>\n';
  }

  /// Bangun CBZ dari file halaman [pagePaths] (sudah berurutan). Halaman
  /// dinamai ulang `001.ext`, `002.ext`, ... agar urutan tetap benar di
  /// pembaca mana pun. Berjalan di isolate; gambar sudah terkompresi jadi
  /// ZIP hanya menyimpan (tanpa kompresi ulang).
  static Future<Uint8List> build({
    required List<String> pagePaths,
    required String series,
    required String title,
  }) =>
      Isolate.run(() => buildSync(pagePaths: pagePaths, series: series, title: title));

  static Uint8List buildSync({
    required List<String> pagePaths,
    required String series,
    required String title,
  }) {
    final archive = Archive();
    final width = pagePaths.length.toString().length < 3 ? 3 : pagePaths.length.toString().length;
    for (var i = 0; i < pagePaths.length; i++) {
      final path = pagePaths[i];
      final dot = path.lastIndexOf('.');
      final slash = path.lastIndexOf(RegExp(r'[\\/]'));
      final ext = dot > slash ? path.substring(dot) : '.jpg';
      final name = '${(i + 1).toString().padLeft(width, '0')}$ext';
      archive.addFile(ArchiveFile.bytes(name, File(path).readAsBytesSync())..compression = CompressionType.none);
    }
    final info = ArchiveFile.string(
      'ComicInfo.xml',
      comicInfo(series: series, title: title, pageCount: pagePaths.length),
    );
    archive.addFile(info);
    return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
  }

  /// CBZ satu bab terunduh, atau null bila file halamannya tidak lengkap.
  static Future<Uint8List?> forChapter(DownloadStore store, DownloadedChapter chapter) async {
    final pages = store.localPages(chapter);
    if (pages == null) return null;
    return build(pagePaths: pages, series: chapter.mangaTitle, title: chapter.chapterName);
  }
}
