import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../core/utils/json.dart';
import 'catalog.dart';

/// Hasil memuat katalog: katalog gabungan, umur salinan tertua, dan error
/// pembaruan (sebagian repo gagal; salinan lama tetap dipakai).
typedef CatalogLoad = ({SourceCatalog catalog, DateTime savedAt, Object? error});

/// Katalog sumber komik dari satu atau beberapa repo (`catalog.json`, format
/// sama dengan `assets/sources/catalog.json`), di atas katalog bawaan.
///
/// Urutan prioritas bila id sama: repo (sesuai urutan daftar) → katalog
/// bawaan → entri yatim. Semua disimpan di disk supaya tahan bila repo hilang:
/// - salinan tiap repo (dipakai bila repo tidak bisa dihubungi);
/// - `known.json`: semua entri yang pernah didapat dari repo. Entri yang sudah
///   hilang dari semua repo (dihapus/di-takedown) tetap jadi sumber "yatim"
///   dan tetap jalan.
///
/// Repo hanya berisi data (domain, template, opsi); logika template ada di
/// aplikasi, jadi entri dengan template yang belum dikenal dilewati.
class SourceCatalogRepository {
  SourceCatalogRepository(this._dir, {required this.bundled, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 40),
              responseType: ResponseType.plain,
            ));

  static const defaultRepoUrl =
      'https://raw.githubusercontent.com/Bayu-Pasifik/hub-reader/main/assets/sources/catalog.json';

  /// Katalog dianggap segar selama ini; setelahnya diperbarui di latar.
  static const maxAge = Duration(hours: 12);

  final Directory _dir;
  final Dio _dio;

  /// Katalog yang ikut terpasang di aplikasi (`assets/sources/catalog.json`).
  final SourceCatalog bundled;

  File _repoFile(String repo) => File('${_dir.path}/repos/${_hash(repo)}.json');
  File get _knownFile => File('${_dir.path}/known.json');
  File get _hostsFile => File('${_dir.path}/hosts.json');

  /// FNV-1a 32-bit, untuk nama file per URL.
  static String _hash(String s) {
    var h = 0x811c9dc5;
    for (final b in utf8.encode(s)) {
      h = ((h ^ b) * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  /// Katalog dari salinan lokal saja (cepat, offline).
  /// `savedAt` = salinan tertua; epoch bila ada repo yang belum pernah diunduh.
  Future<CatalogLoad> cached(List<String> repos) async {
    final lists = <List<CatalogEntry>>[];
    DateTime? oldest;
    var missing = false;
    for (final repo in repos) {
      final copy = await _readCache(repo);
      if (copy == null) {
        missing = true;
        continue;
      }
      lists.add(copy.$1);
      if (oldest == null || copy.$2.isBefore(oldest)) oldest = copy.$2;
    }
    final savedAt = missing || oldest == null ? DateTime.fromMillisecondsSinceEpoch(0) : oldest;
    return (catalog: await _combine(lists), savedAt: savedAt, error: null);
  }

  /// Unduh semua repo. Repo yang gagal memakai salinan lokalnya; gagal total
  /// (semua repo) melempar error.
  Future<CatalogLoad> fetch(List<String> repos) async {
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
    final lists = results.whereType<List<CatalogEntry>>().toList();
    await _remember(lists);
    return (catalog: await _combine(lists), savedAt: DateTime.now(), error: firstError);
  }

  /// Lupakan entri yatim (sumber yang sudah tidak ada di repo mana pun).
  Future<void> forgetOrphans(List<String> repos) async {
    final current = <String>{
      for (final e in bundled.entries) e.id,
      for (final repo in repos) ...?(await _readCache(repo))?.$1.map((e) => e.id),
    };
    final known = await _readKnown();
    known.removeWhere((id, _) => !current.contains(id));
    await _writeJson(_knownFile, known);
  }

  Future<List<CatalogEntry>> _download(String repo) async {
    final response = await _dio.get<String>(
      repo,
      options: Options(headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'}),
    );
    final body = response.data ?? '';
    final list = _parse(body, repo);
    if (list.isEmpty) throw const FormatException('Katalog sumber kosong');
    final file = _repoFile(repo);
    await file.parent.create(recursive: true);
    await file.writeAsString(body, flush: true);
    return list;
  }

  Future<(List<CatalogEntry>, DateTime)?> _readCache(String repo) async {
    try {
      final file = _repoFile(repo);
      if (!await file.exists()) return null;
      return (_parse(await file.readAsString(), repo), await file.lastModified());
    } catch (_) {
      return null;
    }
  }

  /// Repo → bawaan → yatim; yang lebih dulu menang bila id sama.
  Future<SourceCatalog> _combine(List<List<CatalogEntry>> repoLists) async {
    final seen = <String>{};
    final entries = <CatalogEntry>[
      for (final list in repoLists)
        for (final e in list)
          if (seen.add(e.id)) e,
      for (final e in bundled.entries)
        if (seen.add(e.id)) e,
    ];
    final known = await _readKnown();
    final orphans = <CatalogEntry>[
      for (final raw in known.values)
        if (CatalogEntry.tryParse(asMap(raw)) case final e? when seen.add(e.id)) e.withOrigin(orphaned: true),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final all = [...entries, ...orphans];

    // Host lama: riwayat tersimpan + katalog bawaan + semua salinan repo.
    final history = <String, Set<String>>{
      for (final MapEntry(:key, :value) in (await _readJson(_hostsFile)).entries) key: asStringList(value).toSet(),
    };
    void addHost(CatalogEntry e) {
      final host = Uri.tryParse(e.baseUrl)?.host ?? '';
      if (host.isNotEmpty) (history[e.id] ??= {}).add(host);
    }

    bundled.entries.forEach(addHost);
    for (final list in repoLists) {
      list.forEach(addHost);
    }
    all.forEach(addHost);
    return SourceCatalog(all, hostHistory: history);
  }

  /// Catat semua entri repo ke `known.json` (versi terbaru menimpa) dan
  /// host-nya ke `hosts.json` (bertambah terus).
  Future<void> _remember(List<List<CatalogEntry>> lists) async {
    final known = await _readKnown();
    final hosts = {
      for (final MapEntry(:key, :value) in (await _readJson(_hostsFile)).entries) key: asStringList(value).toSet(),
    };
    var changed = false;
    var hostsChanged = false;
    // Urutan terbalik: repo prioritas tertinggi ditulis terakhir (menang).
    for (final list in lists.reversed) {
      for (final e in list) {
        final host = Uri.tryParse(e.baseUrl)?.host ?? '';
        if (host.isNotEmpty && (hosts[e.id] ??= {}).add(host)) hostsChanged = true;
        final encoded = jsonEncode(e.raw);
        if (known[e.id] != null && jsonEncode(known[e.id]) == encoded) continue;
        known[e.id] = e.raw;
        changed = true;
      }
    }
    if (changed) await _writeJson(_knownFile, known);
    if (hostsChanged) {
      await _writeJson(_hostsFile, {for (final MapEntry(:key, :value) in hosts.entries) key: value.toList()});
    }
  }

  Future<Map<String, Object?>> _readKnown() => _readJson(_knownFile);

  Future<Map<String, Object?>> _readJson(File file) async {
    try {
      if (!await file.exists()) return {};
      return asMap(jsonDecode(await file.readAsString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeJson(File file, Map<String, Object?> data) async {
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {
      // tidak fatal
    }
  }

  static List<CatalogEntry> _parse(String body, String repo) => [
        for (final e in SourceCatalog.fromJsonString(body).entries) e.withOrigin(repo: repo),
      ];
}
