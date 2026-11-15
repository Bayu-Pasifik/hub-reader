import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../opds/opds_client.dart';

/// Tujuan cadangan di server WebDAV (Nextcloud, ownCloud, Synology, Koofr, dll).
class WebDavConfig {
  const WebDavConfig({this.url = '', this.username = '', this.password = '', this.enabled = false});

  /// Alamat folder tujuan, mis. `https://cloud.example.com/remote.php/dav/files/me/HubReader`.
  final String url;
  final String username;
  final String password;

  /// Unggah juga setiap cadangan otomatis ke server ini.
  final bool enabled;

  bool get configured => Uri.tryParse(url)?.hasAuthority ?? false;

  WebDavConfig copyWith({String? url, String? username, String? password, bool? enabled}) => WebDavConfig(
        url: url ?? this.url,
        username: username ?? this.username,
        password: password ?? this.password,
        enabled: enabled ?? this.enabled,
      );

  static const _urlKey = 'backup.webdav.url.v1';
  static const _userKey = 'backup.webdav.user.v1';
  static const _enabledKey = 'backup.webdav.enabled.v1';
  static const _passKey = 'backup.webdav.pass';
  static const _storage = FlutterSecureStorage();

  /// Kata sandi ada di penyimpanan aman (Keystore), bukan di prefs/cadangan.
  static Future<WebDavConfig> read(SharedPreferences prefs) async {
    var password = '';
    try {
      password = await _storage.read(key: _passKey) ?? '';
    } on Object {
      // Keystore tidak tersedia
    }
    return WebDavConfig(
      url: prefs.getString(_urlKey) ?? '',
      username: prefs.getString(_userKey) ?? '',
      password: password,
      enabled: prefs.getBool(_enabledKey) ?? false,
    );
  }

  Future<void> write(SharedPreferences prefs) async {
    await prefs.setString(_urlKey, url);
    await prefs.setString(_userKey, username);
    await prefs.setBool(_enabledKey, enabled);
    try {
      if (password.isEmpty) {
        await _storage.delete(key: _passKey);
      } else {
        await _storage.write(key: _passKey, value: password);
      }
    } on Object {
      // Keystore tidak tersedia: kata sandi tidak disimpan.
    }
  }
}

class WebDavException implements Exception {
  const WebDavException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Satu berkas di server WebDAV.
class WebDavFile {
  const WebDavFile({required this.name, required this.modified, required this.size});
  final String name;
  final DateTime modified;
  final int size;
}

/// Klien WebDAV minimal: buat folder, unggah, daftar, unduh, hapus.
class WebDavClient {
  WebDavClient(this.config, {Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 60),
              sendTimeout: const Duration(seconds: 60),
              validateStatus: (_) => true,
            ));

  final WebDavConfig config;
  final Dio _dio;

  /// Login Basic lewat HTTP polos ke host publik terkirim tanpa enkripsi,
  /// jadi hanya HTTPS atau jaringan lokal yang diterima.
  String get _base {
    final uri = Uri.tryParse(config.url);
    if (uri == null || !OpdsServer.isCleartextAllowed(uri)) {
      throw const WebDavException('WebDAV ke host publik wajib memakai HTTPS (http:// hanya untuk jaringan lokal).');
    }
    return config.url.endsWith('/') ? config.url : '${config.url}/';
  }

  Map<String, String> get _headers => {
        if (config.username.isNotEmpty || config.password.isNotEmpty)
          'Authorization': 'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}',
      };

  String _fileUrl(String name) => '$_base${Uri.encodeComponent(name)}';

  Never _fail(int? status, String action) {
    final why = switch (status) {
      401 || 403 => 'login ditolak ($status)',
      404 => 'folder tidak ditemukan (404)',
      507 => 'penyimpanan server penuh (507)',
      null => 'tidak ada respons',
      _ => 'HTTP $status',
    };
    throw WebDavException('WebDAV $action gagal: $why');
  }

  /// Buat folder tujuan bila belum ada (405 = sudah ada).
  Future<void> ensureFolder() async {
    final res = await _dio.request<Object>(_base, options: Options(method: 'MKCOL', headers: _headers));
    final s = res.statusCode ?? 0;
    if (s == 201 || s == 405 || s == 200) return;
    // Server tanpa MKCOL di tingkat ini: biarkan PUT yang menentukan.
    if (s == 301 || s == 409) return;
    _fail(s, 'buat folder');
  }

  Future<void> upload(String name, List<int> bytes) async {
    await ensureFolder();
    final res = await _dio.put<Object>(
      _fileUrl(name),
      data: Stream.fromIterable([bytes]),
      options: Options(headers: {
        ..._headers,
        'Content-Type': 'application/json',
        'Content-Length': bytes.length.toString(),
      }),
    );
    final s = res.statusCode ?? 0;
    if (s < 200 || s >= 300) _fail(s, 'unggah');
  }

  Future<List<WebDavFile>> list() async {
    final res = await _dio.request<String>(
      _base,
      data: '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:getlastmodified/><d:getcontentlength/></d:prop></d:propfind>',
      options: Options(
        method: 'PROPFIND',
        headers: {..._headers, 'Depth': '1', 'Content-Type': 'application/xml'},
        responseType: ResponseType.plain,
      ),
    );
    final s = res.statusCode ?? 0;
    if (s != 207) _fail(s, 'daftar');
    return parseListing(res.data ?? '');
  }

  /// Berkas `.json` di folder, terbaru dulu.
  static List<WebDavFile> parseListing(String xml) {
    final files = <WebDavFile>[];
    final blocks = RegExp(r'<(?:\w+:)?response[ >].*?</(?:\w+:)?response>', dotAll: true).allMatches(xml);
    for (final b in blocks) {
      final block = b.group(0)!;
      final href = RegExp(r'<(?:\w+:)?href>(.*?)</(?:\w+:)?href>', dotAll: true).firstMatch(block)?.group(1)?.trim();
      if (href == null || href.endsWith('/')) continue;
      final name = Uri.decodeComponent(href.split('/').last);
      if (!name.endsWith('.json')) continue;
      final modified = RegExp(r'<(?:\w+:)?getlastmodified>(.*?)</', dotAll: true).firstMatch(block)?.group(1);
      final size = RegExp(r'<(?:\w+:)?getcontentlength>(\d+)</').firstMatch(block)?.group(1);
      files.add(WebDavFile(
        name: name,
        modified: _httpDate(modified) ?? DateTime.fromMillisecondsSinceEpoch(0),
        size: int.tryParse(size ?? '') ?? 0,
      ));
    }
    files.sort((a, b) => b.modified.compareTo(a.modified));
    return files;
  }

  static const _months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

  /// `Sun, 15 Nov 2026 08:49:00 GMT`.
  static DateTime? _httpDate(String? raw) {
    final m = RegExp(r'(\d{1,2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2})').firstMatch(raw ?? '');
    if (m == null) return null;
    final month = _months.indexOf(m.group(2)!.toLowerCase()) + 1;
    if (month == 0) return null;
    return DateTime.utc(int.parse(m.group(3)!), month, int.parse(m.group(1)!), int.parse(m.group(4)!),
            int.parse(m.group(5)!), int.parse(m.group(6)!))
        .toLocal();
  }

  Future<String> download(String name) async {
    final res = await _dio.get<List<int>>(
      _fileUrl(name),
      options: Options(headers: _headers, responseType: ResponseType.bytes),
    );
    final s = res.statusCode ?? 0;
    if (s != 200) _fail(s, 'unduh');
    return utf8.decode(res.data ?? const []);
  }

  Future<void> delete(String name) async {
    final res = await _dio.delete<Object>(_fileUrl(name), options: Options(headers: _headers));
    final s = res.statusCode ?? 0;
    if (s != 404 && (s < 200 || s >= 300)) _fail(s, 'hapus');
  }

  /// Tes koneksi & login: daftar folder (dibuat dulu bila belum ada).
  Future<void> test() async {
    await ensureFolder();
    await list();
  }

  /// Hapus cadangan otomatis terlama di server melebihi [keep].
  Future<void> prune(int keep, {String prefix = 'hub_reader_auto_'}) async {
    final files = (await list()).where((f) => f.name.startsWith(prefix)).toList();
    for (final old in files.skip(keep < 1 ? 1 : keep)) {
      try {
        await delete(old.name);
      } catch (_) {
        // dicoba lagi di putaran berikutnya
      }
    }
  }
}
