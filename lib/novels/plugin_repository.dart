import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../core/utils/json.dart';
import 'novel_models.dart';

/// Daftar & kode plugin dari repo lnreader-plugins (branch `plugins/v3.0.0`,
/// hasil compile yang sama dengan yang dipasang aplikasi LNReader).
///
/// Manifest dan kode plugin disimpan di disk: setelah sekali diunduh, sumber
/// novel tetap bisa dibuka walau GitHub tidak bisa dihubungi. Kode plugin
/// diunduh ulang hanya bila versinya di manifest berubah.
class NovelPluginRepository {
  NovelPluginRepository(this._dir, {Dio? dio, this.manifestUrl = defaultManifestUrl})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 40),
              responseType: ResponseType.plain,
            ));

  static const defaultManifestUrl =
      'https://raw.githubusercontent.com/lnreader/lnreader-plugins/plugins/v3.0.0/.dist/plugins.min.json';

  /// Manifest dianggap segar selama ini; setelahnya diperbarui di latar.
  static const manifestMaxAge = Duration(hours: 12);

  final Directory _dir;
  final Dio _dio;
  final String manifestUrl;

  File get _manifestFile => File('${_dir.path}/manifest.json');
  File _codeFile(String id) => File('${_dir.path}/plugins/${safeId(id)}.js');
  File _versionFile(String id) => File('${_dir.path}/plugins/${safeId(id)}.version');

  /// Nama file aman untuk id plugin.
  static String safeId(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  /// Manifest tersimpan (null bila belum pernah diunduh) + waktu simpannya.
  Future<(List<NovelPluginInfo>, DateTime)?> cachedManifest() async {
    try {
      if (!await _manifestFile.exists()) return null;
      final list = _parseManifest(await _manifestFile.readAsString());
      return (list, await _manifestFile.lastModified());
    } catch (_) {
      return null;
    }
  }

  /// Unduh manifest terbaru dan simpan.
  Future<List<NovelPluginInfo>> fetchManifest() async {
    final response = await _dio.get<String>(
      manifestUrl,
      options: Options(headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'}),
    );
    final body = response.data ?? '[]';
    final list = _parseManifest(body);
    if (list.isEmpty) throw const FormatException('Manifest plugin kosong');
    await _dir.create(recursive: true);
    await _manifestFile.writeAsString(body, flush: true);
    return list;
  }

  /// Kode plugin versi [info.version]; pakai salinan lokal bila versinya sama.
  /// Bila unduhan gagal, salinan lama (versi berapa pun) tetap dipakai.
  Future<String> code(NovelPluginInfo info) async {
    final file = _codeFile(info.id);
    final versionFile = _versionFile(info.id);
    final hasLocal = await file.exists();
    if (hasLocal && await versionFile.exists() && (await versionFile.readAsString()).trim() == info.version) {
      return file.readAsString();
    }
    try {
      final response = await _dio.get<String>(
        info.url,
        options: Options(headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'}),
      );
      final code = response.data ?? '';
      if (code.trim().isEmpty) throw const FormatException('Kode plugin kosong');
      await file.parent.create(recursive: true);
      await file.writeAsString(code, flush: true);
      await versionFile.writeAsString(info.version, flush: true);
      return code;
    } catch (_) {
      if (hasLocal) return file.readAsString();
      rethrow;
    }
  }

  /// Plugin yang kodenya sudah tersimpan di perangkat.
  Future<Set<String>> installedIds() async {
    final dir = Directory('${_dir.path}/plugins');
    if (!await dir.exists()) return {};
    return {
      await for (final f in dir.list())
        if (f.path.endsWith('.js')) f.uri.pathSegments.last.replaceAll(RegExp(r'\.js$'), ''),
    };
  }

  static List<NovelPluginInfo> _parseManifest(String body) =>
      asList(jsonDecode(body)).map((e) => NovelPluginInfo.tryParse(asMap(e))).whereType<NovelPluginInfo>().toList();
}
