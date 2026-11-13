import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../core/utils/json.dart';
import 'novel_models.dart';

/// Hasil penggabungan manifest semua repo + plugin yatim di perangkat.
typedef PluginCatalog = ({List<NovelPluginInfo> plugins, DateTime savedAt, Object? error});

/// Daftar & kode plugin novel dari satu atau beberapa repo bergaya
/// lnreader-plugins (`plugins.min.json`). Default: branch `plugins/v3.0.0`,
/// hasil compile yang sama dengan yang dipasang aplikasi LNReader.
///
/// Semua disimpan di disk supaya tahan bila repo hilang:
/// - manifest tiap repo (dipakai bila repo tidak bisa dihubungi);
/// - kode plugin + info-nya (`<id>.js`, `<id>.version`, `<id>.json`).
///
/// Plugin yang kodenya tersimpan tapi sudah tidak ada di repo mana pun
/// (dihapus/di-takedown) tetap muncul sebagai plugin "yatim" dan tetap jalan.
class NovelPluginRepository {
  NovelPluginRepository(this._dir, {Dio? dio})
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

  Directory get _pluginsDir => Directory('${_dir.path}/plugins');

  /// Repo default memakai `manifest.json` (lokasi lama, kompatibel ke belakang).
  File _manifestFile(String repo) => repo == defaultManifestUrl
      ? File('${_dir.path}/manifest.json')
      : File('${_dir.path}/manifests/${_hash(repo)}.json');
  File _codeFile(String id) => File('${_pluginsDir.path}/${safeId(id)}.js');
  File _versionFile(String id) => File('${_pluginsDir.path}/${safeId(id)}.version');
  File _infoFile(String id) => File('${_pluginsDir.path}/${safeId(id)}.json');

  /// Nama file aman untuk id plugin.
  static String safeId(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  /// FNV-1a 32-bit, untuk nama file manifest per URL.
  static String _hash(String s) {
    var h = 0x811c9dc5;
    for (final b in utf8.encode(s)) {
      h = ((h ^ b) * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  /// Katalog dari salinan lokal saja. Null bila belum ada apa pun.
  /// `savedAt` = manifest tertua; epoch bila ada repo yang belum pernah diunduh.
  Future<PluginCatalog?> cachedManifest(List<String> repos) async {
    final lists = <List<NovelPluginInfo>>[];
    DateTime? oldest;
    var missing = false;
    for (final repo in repos) {
      final cached = await _readCache(repo);
      if (cached == null) {
        missing = true;
        continue;
      }
      lists.add(cached.$1);
      if (oldest == null || cached.$2.isBefore(oldest)) oldest = cached.$2;
    }
    final merged = _merge(lists);
    final orphans = await _orphans(merged);
    if (lists.isEmpty && orphans.isEmpty) return null;
    final savedAt = missing || oldest == null ? DateTime.fromMillisecondsSinceEpoch(0) : oldest;
    return (plugins: [...merged, ...orphans], savedAt: savedAt, error: null);
  }

  /// Unduh manifest semua repo. Repo yang gagal memakai salinan lokalnya;
  /// gagal total (semua repo) melempar error.
  Future<PluginCatalog> fetchManifest(List<String> repos) async {
    Object? firstError;
    var ok = 0;
    final results = await Future.wait(repos.map((repo) async {
      try {
        final list = await _download(repo);
        ok++;
        return list;
      } catch (e) {
        firstError ??= e;
        return (await _readCache(repo))?.$1;
      }
    }));
    if (repos.isNotEmpty && ok == 0) throw firstError!;
    final merged = _merge(results.whereType<List<NovelPluginInfo>>().toList());
    await _backfillInfo(merged);
    final orphans = await _orphans(merged);
    return (plugins: [...merged, ...orphans], savedAt: DateTime.now(), error: firstError);
  }

  Future<List<NovelPluginInfo>> _download(String repo) async {
    final response = await _dio.get<String>(
      repo,
      options: Options(headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'}),
    );
    final body = response.data ?? '[]';
    final list = _parseManifest(body, repo);
    if (list.isEmpty) throw const FormatException('Manifest plugin kosong');
    final file = _manifestFile(repo);
    await file.parent.create(recursive: true);
    await file.writeAsString(body, flush: true);
    return list;
  }

  Future<(List<NovelPluginInfo>, DateTime)?> _readCache(String repo) async {
    try {
      final file = _manifestFile(repo);
      if (!await file.exists()) return null;
      return (_parseManifest(await file.readAsString(), repo), await file.lastModified());
    } catch (_) {
      return null;
    }
  }

  /// Repo di atas menang bila id plugin sama.
  static List<NovelPluginInfo> _merge(List<List<NovelPluginInfo>> lists) {
    final seen = <String>{};
    return [
      for (final list in lists)
        for (final p in list)
          if (seen.add(p.id)) p,
    ];
  }

  /// Plugin terpasang yang info-nya belum tersimpan (dipasang sebelum info
  /// disimpan) dicatat sekarang, selagi masih ada di manifest.
  Future<void> _backfillInfo(List<NovelPluginInfo> plugins) async {
    final installed = await installedIds();
    for (final p in plugins) {
      if (!installed.contains(safeId(p.id))) continue;
      try {
        final file = _infoFile(p.id);
        if (!await file.exists()) await file.writeAsString(jsonEncode(p.toJson()), flush: true);
      } catch (_) {
        // tidak fatal
      }
    }
  }

  /// Semua manifest yang pernah tersimpan di perangkat, termasuk milik repo
  /// yang sudah dihapus dari daftar (id aman → info).
  Future<Map<String, NovelPluginInfo>> _allCachedInfos() async {
    final files = <File>[File('${_dir.path}/manifest.json')];
    final dir = Directory('${_dir.path}/manifests');
    if (await dir.exists()) files.addAll((await dir.list().toList()).whereType<File>());
    final result = <String, NovelPluginInfo>{};
    for (final f in files) {
      try {
        if (!await f.exists()) continue;
        final base = f.path.endsWith('manifest.json') && f.parent.path == _dir.path ? defaultManifestUrl : null;
        for (final p in _parseManifest(await f.readAsString(), base)) {
          result.putIfAbsent(safeId(p.id), () => p);
        }
      } catch (_) {
        // manifest rusak: lewati
      }
    }
    return result;
  }

  /// Plugin yang kodenya tersimpan tapi tidak ada di [known].
  Future<List<NovelPluginInfo>> _orphans(List<NovelPluginInfo> known) async {
    final knownIds = {for (final p in known) safeId(p.id)};
    final result = <NovelPluginInfo>[];
    Map<String, NovelPluginInfo>? cachedInfos;
    for (final id in await installedIds()) {
      if (knownIds.contains(id)) continue;
      NovelPluginInfo? info;
      final infoFile = File('${_pluginsDir.path}/$id.json');
      try {
        if (await infoFile.exists()) info = NovelPluginInfo.tryParse(asMap(jsonDecode(await infoFile.readAsString())));
      } catch (_) {
        info = null;
      }
      if (info == null) {
        // Dipasang sebelum info disimpan: cari di manifest lama mana pun.
        cachedInfos ??= await _allCachedInfos();
        info = cachedInfos[id];
        if (info != null) {
          try {
            await infoFile.writeAsString(jsonEncode(info.toJson()), flush: true);
          } catch (_) {
            // tidak fatal
          }
        }
      }
      if (info == null) {
        // Terpasang sebelum info disimpan: rekonstruksi seadanya.
        final versionFile = File('${_pluginsDir.path}/$id.version');
        final version = await versionFile.exists() ? (await versionFile.readAsString()).trim() : '?';
        info = NovelPluginInfo(id: id, name: id, site: '', lang: 'all', version: version, url: '');
      }
      result.add(info.asOrphan());
    }
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  /// Kode plugin versi [info.version]; pakai salinan lokal bila versinya sama.
  /// Bila unduhan gagal (atau plugin yatim), salinan lama tetap dipakai.
  Future<String> code(NovelPluginInfo info) async {
    final file = _codeFile(info.id);
    final versionFile = _versionFile(info.id);
    final hasLocal = await file.exists();
    if (hasLocal &&
        (info.orphaned ||
            info.url.isEmpty ||
            (await versionFile.exists() && (await versionFile.readAsString()).trim() == info.version))) {
      return file.readAsString();
    }
    try {
      if (info.url.isEmpty) throw StateError('Plugin "${info.id}" tidak punya URL kode');
      final response = await _dio.get<String>(
        info.url,
        options: Options(headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'}),
      );
      final code = response.data ?? '';
      if (code.trim().isEmpty) throw const FormatException('Kode plugin kosong');
      await file.parent.create(recursive: true);
      await file.writeAsString(code, flush: true);
      await versionFile.writeAsString(info.version, flush: true);
      await _infoFile(info.id).writeAsString(jsonEncode(info.toJson()), flush: true);
      return code;
    } catch (_) {
      if (hasLocal) return file.readAsString();
      rethrow;
    }
  }

  /// Plugin yang kodenya sudah tersimpan di perangkat (id aman).
  Future<Set<String>> installedIds() async {
    final dir = _pluginsDir;
    if (!await dir.exists()) return {};
    return {
      await for (final f in dir.list())
        if (f.path.endsWith('.js')) f.uri.pathSegments.last.replaceAll(RegExp(r'\.js$'), ''),
    };
  }

  /// Hapus kode & info satu plugin dari perangkat.
  Future<void> uninstall(String id) async {
    for (final f in [_codeFile(id), _versionFile(id), _infoFile(id)]) {
      try {
        if (await f.exists()) await f.delete();
      } catch (_) {
        // abaikan
      }
    }
  }

  static List<NovelPluginInfo> _parseManifest(String body, String? repo) => asList(jsonDecode(body))
      .map((e) => NovelPluginInfo.tryParse(asMap(e), base: repo))
      .whereType<NovelPluginInfo>()
      .toList();
}
