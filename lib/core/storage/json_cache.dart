import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../utils/json.dart';

class CachedJson {
  const CachedJson(this.data, this.savedAt);

  final JsonMap data;
  final DateTime savedAt;
}

/// Cache respons API sederhana: satu file JSON per key di folder cache aplikasi.
///
/// Dipakai repository dengan strategi "network first, cache fallback":
/// setiap respons sukses disimpan, dan saat server tidak bisa dihubungi
/// aplikasi menampilkan versi terakhir yang tersimpan.
class JsonCache {
  JsonCache(this._dir);

  final Directory _dir;

  static Future<JsonCache> open() async {
    final base = await getApplicationCacheDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}api_cache');
    await dir.create(recursive: true);
    return JsonCache(dir);
  }

  Future<void> write(String key, JsonMap data) async {
    try {
      final payload = jsonEncode({
        'key': key,
        'saved_at': DateTime.now().toIso8601String(),
        'data': data,
      });
      await _file(key).writeAsString(payload, flush: true);
    } catch (_) {
      // Cache bersifat best-effort; gagal menulis tidak boleh mengganggu UI.
    }
  }

  Future<CachedJson?> read(String key) async {
    try {
      final file = _file(key);
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic> || decoded['key'] != key) return null;
      final data = decoded['data'];
      final savedAt = DateTime.tryParse('${decoded['saved_at']}');
      if (data is! Map<String, dynamic> || savedAt == null) return null;
      return CachedJson(data, savedAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      if (await _dir.exists()) {
        await _dir.delete(recursive: true);
      }
      await _dir.create(recursive: true);
    } catch (_) {}
  }

  /// Nama file = hash FNV-1a dari key (key pencarian bisa panjang / berisi
  /// karakter yang tidak valid untuk nama file). Key asli disimpan di dalam
  /// file dan dicek saat dibaca untuk menghindari tabrakan hash.
  File _file(String key) =>
      File('${_dir.path}${Platform.pathSeparator}${_fnv1a(key)}.json');

  static String _fnv1a(String input) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(input)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return '${hash.toRadixString(16).padLeft(8, '0')}_${input.length}';
  }
}
