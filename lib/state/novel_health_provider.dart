import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/json.dart';
import '../novels/novel_models.dart';
import '../novels/novel_source.dart';
import 'core_providers.dart';
import 'novel_providers.dart';
import 'source_health_provider.dart';

/// Status plugin novel per id: hasil cek di HP (tombol "Cek semua", atau
/// saat daftar populer dibuka), ditambah data awal dari cek di PC
/// (`assets/lnreader/health.json`, dibuat `tool/lnreader_runtime/check.mjs`).
final novelHealthProvider = NotifierProvider<NovelHealthNotifier, Map<String, SourceHealth>>(NovelHealthNotifier.new);

final novelHealthRunProvider = StateProvider<HealthRun>((ref) => const HealthRun());

/// Sembunyikan plugin yang rusak/mati di tab Novel.
final novelHideBrokenProvider = NotifierProvider<NovelHideBrokenNotifier, bool>(NovelHideBrokenNotifier.new);

class NovelHideBrokenNotifier extends Notifier<bool> {
  static const _key = 'novels.hide_broken.v1';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

/// Plugin dianggap bisa dipakai bila belum pernah dicek, jalan, atau hanya
/// perlu verifikasi Cloudflare.
bool novelUsable(SourceHealth? h) => h == null || h.status == HealthStatus.ok || h.status == HealthStatus.cloudflare;

class NovelHealthNotifier extends Notifier<Map<String, SourceHealth>> {
  static const _key = 'novels.health.v1';
  static const _parallel = 4;
  static const _timeout = Duration(seconds: 40);

  bool _cancel = false;
  Timer? _saveTimer;

  /// Hasil cek PC (dipakai bila plugin belum pernah dicek di HP).
  Map<String, SourceHealth> _baseline = const {};

  @override
  Map<String, SourceHealth> build() {
    ref.onDispose(() => _saveTimer?.cancel());
    Future.microtask(_loadBaseline);
    return _readSaved();
  }

  Map<String, SourceHealth> _readSaved() {
    final raw = ref.read(sharedPreferencesProvider).getString(_key);
    if (raw == null) return {};
    try {
      return {
        for (final e in asMap(jsonDecode(raw)).entries)
          if (SourceHealth.tryParse(e.value) case final h?) e.key: h,
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _loadBaseline() async {
    try {
      _baseline = parseNovelHealthBaseline(await rootBundle.loadString('assets/lnreader/health.json'));
    } catch (_) {
      return;
    }
    state = {..._baseline, ...state};
  }

  void record(String pluginId, SourceHealth health) {
    state = {...state, pluginId: health};
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), _save);
  }

  /// Dari pemakaian biasa: daftar populer berhasil/gagal dimuat.
  void recordResult(String pluginId, {Object? error, bool empty = false}) {
    if (error == null && !empty) {
      record(pluginId, SourceHealth(HealthStatus.ok, DateTime.now()));
    } else if (error != null) {
      record(pluginId, SourceHealth.fromError(novelError(error)));
    } else {
      record(pluginId, SourceHealth(HealthStatus.broken, DateTime.now(), detail: 'Daftar kosong'));
    }
  }

  /// Hanya hasil cek di HP yang disimpan; data awal PC tetap dari aset.
  Future<void> _save() => ref.read(sharedPreferencesProvider).setString(
        _key,
        jsonEncode({
          for (final e in state.entries)
            if (!identical(_baseline[e.key], e.value)) e.key: e.value.toJson(),
        }),
      );

  Future<SourceHealth> check(NovelPluginInfo info) async {
    SourceHealth health;
    try {
      final source = await ref.read(novelSourceProvider(info.id).future).timeout(_timeout);
      final items = await source.popular(1).timeout(_timeout);
      health = items.isEmpty
          ? SourceHealth(HealthStatus.broken, DateTime.now(), detail: 'Daftar kosong')
          : SourceHealth(HealthStatus.ok, DateTime.now());
    } on TimeoutException {
      health = SourceHealth(HealthStatus.dead, DateTime.now(), detail: 'Timeout');
    } catch (error) {
      health = SourceHealth.fromError(novelError(error, site: info.site));
    }
    record(info.id, health);
    return health;
  }

  Future<void> checkAll(List<NovelPluginInfo> plugins) async {
    final run = ref.read(novelHealthRunProvider.notifier);
    if (run.state.running) return;
    _cancel = false;
    final queue = [...plugins];
    var done = 0;
    run.state = HealthRun(running: true, total: queue.length);
    Future<void> worker() async {
      while (queue.isNotEmpty && !_cancel) {
        await check(queue.removeAt(0));
        done++;
        run.state = HealthRun(running: true, done: done, total: plugins.length);
      }
    }

    await Future.wait(List.generate(_parallel, (_) => worker()));
    run.state = HealthRun(done: done, total: plugins.length);
    _saveTimer?.cancel();
    await _save();
  }

  void stop() => _cancel = true;
}

/// `{"checked_at": ISO, "plugins": {id: {"s": status, "d": detail}}}`.
Map<String, SourceHealth> parseNovelHealthBaseline(String raw) {
  final json = asMap(jsonDecode(raw));
  final at = asDate(json['checked_at']) ?? DateTime(2000);
  return {
    for (final e in asMap(json['plugins']).entries)
      if (HealthStatus.values.where((s) => s.name == asString(asMap(e.value)['s'])).firstOrNull case final s?)
        e.key: SourceHealth(s, at, detail: asString(asMap(e.value)['d'])),
  };
}
