import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/json.dart';
import '../models/download.dart';

/// File halaman bab yang diunduh + indeksnya.
///
/// Struktur: `<documents>/downloads/<sumber>/<hash seri>/<hash bab>/001.jpg`.
/// Indeks (bab mana saja yang lengkap) disimpan di SharedPreferences.
class DownloadStore {
  DownloadStore(this.root, this._prefs);

  final Directory root;
  final SharedPreferences _prefs;

  static const _indexKey = 'downloads.index.v1';
  static const queueKey = 'downloads.queue.v1';

  static Future<DownloadStore> open(SharedPreferences prefs) async {
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory('${docs.path}${Platform.pathSeparator}downloads');
    await root.create(recursive: true);
    return DownloadStore(root, prefs);
  }

  Map<String, DownloadedChapter> readIndex() {
    final raw = _prefs.getString(_indexKey);
    if (raw == null) return {};
    try {
      return {
        for (final e in asList(jsonDecode(raw)))
          if (DownloadedChapter.tryParse(asMap(e)) case final c?) c.key: c,
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> writeIndex(Map<String, DownloadedChapter> index) =>
      _prefs.setString(_indexKey, jsonEncode([for (final c in index.values) c.toJson()]));

  List<DownloadTask> readQueue() {
    final raw = _prefs.getString(queueKey);
    if (raw == null) return const [];
    try {
      return [
        for (final e in asList(jsonDecode(raw)))
          if (DownloadTask.tryParse(asMap(e)) case final t?) t,
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> writeQueue(List<DownloadTask> queue) => queue.isEmpty
      ? _prefs.remove(queueKey)
      : _prefs.setString(queueKey, jsonEncode([for (final t in queue) t.toJson()]));

  /// Folder relatif untuk satu bab (dipakai saat mengunduh & di indeks).
  static String relativeDirFor(String sourceId, String mangaUrl, String chapterUrl) =>
      [_safe(sourceId), stableHash(mangaUrl), stableHash(chapterUrl)].join('/');

  Directory dirOf(String relativeDir) =>
      Directory('${root.path}/$relativeDir'.replaceAll('/', Platform.pathSeparator));

  /// Path absolut halaman, atau null bila ada file yang hilang (unduhan
  /// dianggap rusak; reader akan kembali memuat dari situs).
  List<String>? localPages(DownloadedChapter chapter) {
    final dir = dirOf(chapter.relativeDir).path;
    final paths = [for (final f in chapter.files) '$dir${Platform.pathSeparator}$f'];
    if (paths.isEmpty || paths.any((p) => !File(p).existsSync())) return null;
    return paths;
  }

  /// Nama file isi bab novel di folder babnya.
  static const novelChapterFile = 'chapter.html';

  /// Isi bab novel yang diunduh, atau null bila file hilang.
  Future<String?> readNovelChapter(DownloadedChapter chapter) async {
    final file = File('${dirOf(chapter.relativeDir).path}${Platform.pathSeparator}$novelChapterFile');
    try {
      return await file.exists() ? await file.readAsString() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteDir(String relativeDir) async {
    final dir = dirOf(relativeDir);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  static String _safe(String s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
}

/// Hash stabil untuk nama folder: dua FNV-1a 32-bit dengan seed berbeda
/// digabung (64 bit), cukup untuk menghindari tabrakan antar URL.
String stableHash(String input) {
  var a = 0x811c9dc5;
  var b = 0x01000193 ^ 0x5bd1e995;
  for (final byte in utf8.encode(input)) {
    a = ((a ^ byte) * 0x01000193) & 0xffffffff;
    b = ((b ^ byte) * 0x01000193) & 0xffffffff;
  }
  return a.toRadixString(16).padLeft(8, '0') + b.toRadixString(16).padLeft(8, '0');
}
