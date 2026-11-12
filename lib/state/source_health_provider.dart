import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/json.dart';
import '../sources/source.dart';
import '../sources/source_exception.dart';
import 'core_providers.dart';

/// Hasil cek satu sumber, diurutkan dari paling bisa dipakai.
enum HealthStatus {
  ok('Jalan'),
  cloudflare('Perlu verifikasi'),
  broken('Rusak'),
  dead('Mati');

  const HealthStatus(this.label);

  final String label;
}

class SourceHealth {
  const SourceHealth(this.status, this.checkedAt, {this.detail});

  final HealthStatus status;
  final DateTime checkedAt;

  /// Ringkasan error untuk ditampilkan (mis. "HTTP 522").
  final String? detail;

  /// Petakan error sumber ke status kesehatan.
  factory SourceHealth.fromError(Object error) {
    final e = toSourceException(error);
    final status = switch (e.kind) {
      SourceErrorKind.cloudflare => HealthStatus.cloudflare,
      SourceErrorKind.noConnection ||
      SourceErrorKind.timeout ||
      SourceErrorKind.notFound ||
      SourceErrorKind.server =>
        HealthStatus.dead,
      SourceErrorKind.rateLimited => HealthStatus.ok, // situs hidup, hanya membatasi
      SourceErrorKind.parse || SourceErrorKind.unknown => HealthStatus.broken,
    };
    return SourceHealth(status, DateTime.now(), detail: e.statusCode != null ? 'HTTP ${e.statusCode}' : e.title);
  }

  JsonMap toJson() => {'s': status.name, 't': checkedAt.toIso8601String(), if (detail != null) 'd': detail};

  static SourceHealth? tryParse(Object? raw) {
    final m = asMap(raw);
    final status = HealthStatus.values.where((s) => s.name == asString(m['s'])).firstOrNull;
    final at = asDate(m['t']);
    if (status == null || at == null) return null;
    return SourceHealth(status, at, detail: asString(m['d']));
  }
}

/// Progres "Cek semua sumber".
class HealthRun {
  const HealthRun({this.running = false, this.done = 0, this.total = 0});

  final bool running;
  final int done;
  final int total;
}

final sourceHealthProvider =
    NotifierProvider<SourceHealthNotifier, Map<String, SourceHealth>>(SourceHealthNotifier.new);

final healthRunProvider = StateProvider<HealthRun>((ref) => const HealthRun());

class SourceHealthNotifier extends Notifier<Map<String, SourceHealth>> {
  static const _key = 'sources.health.v1';
  static const _parallel = 6;
  static const _timeout = Duration(seconds: 20);

  bool _cancel = false;
  Timer? _saveTimer;

  @override
  Map<String, SourceHealth> build() {
    ref.onDispose(() => _saveTimer?.cancel());
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
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

  /// Catat hasil (dipakai juga saat pengguna membuka sumber).
  void record(String sourceId, SourceHealth health) {
    state = {...state, sourceId: health};
    // Disimpan berkelompok supaya cek massal tidak menulis ratusan kali.
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), _save);
  }

  void recordOk(String sourceId) => record(sourceId, SourceHealth(HealthStatus.ok, DateTime.now()));

  Future<void> _save() => ref
      .read(sharedPreferencesProvider)
      .setString(_key, jsonEncode({for (final e in state.entries) e.key: e.value.toJson()}));

  /// Cek satu sumber: halaman populer pertama harus berisi judul.
  Future<SourceHealth> check(MangaSource source) async {
    SourceHealth health;
    try {
      final page = await source.popular(1).timeout(_timeout);
      health = page.items.isEmpty
          ? SourceHealth(HealthStatus.broken, DateTime.now(), detail: 'Daftar kosong')
          : SourceHealth(HealthStatus.ok, DateTime.now());
    } on TimeoutException {
      health = SourceHealth(HealthStatus.dead, DateTime.now(), detail: 'Timeout');
    } catch (error) {
      health = SourceHealth.fromError(error);
    }
    record(source.id, health);
    return health;
  }

  /// Cek banyak sumber paralel. Bisa dihentikan dengan [stop].
  Future<void> checkAll(List<MangaSource> sources) async {
    final run = ref.read(healthRunProvider.notifier);
    if (run.state.running) return;
    _cancel = false;
    final queue = [...sources];
    var done = 0;
    run.state = HealthRun(running: true, total: queue.length);
    Future<void> worker() async {
      while (queue.isNotEmpty && !_cancel) {
        final source = queue.removeAt(0);
        await check(source);
        done++;
        run.state = HealthRun(running: true, done: done, total: sources.length);
      }
    }

    await Future.wait(List.generate(_parallel, (_) => worker()));
    run.state = HealthRun(done: done, total: sources.length);
    _saveTimer?.cancel();
    await _save();
  }

  void stop() => _cancel = true;
}

/// Status kesehatan satu sumber (null = belum pernah dicek).
final sourceHealthOfProvider = Provider.family<SourceHealth?, String>(
  (ref, id) => ref.watch(sourceHealthProvider.select((m) => m[id])),
);

/// Sembunyikan sumber berstatus "Mati" dari daftar.
final hideDeadSourcesProvider = NotifierProvider<HideDeadNotifier, bool>(HideDeadNotifier.new);

class HideDeadNotifier extends Notifier<bool> {
  static const _key = 'sources.hide_dead.v1';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

/// Dipakai daftar sumber untuk mengurutkan: jalan → belum dicek → … → mati.
int healthRank(SourceHealth? h) => switch (h?.status) {
      HealthStatus.ok => 0,
      null => 1,
      HealthStatus.cloudflare => 2,
      HealthStatus.broken => 3,
      HealthStatus.dead => 4,
    };
