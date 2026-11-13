import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/json.dart';
import 'app_settings_provider.dart';
import 'core_providers.dart';

/// Statistik baca per hari: lama membaca dan bab yang selesai.
///
/// Disimpan di SharedPreferences (`stats.reading.v1`) sehingga ikut cadangan.
/// Kunci hari berformat `yyyy-mm-dd` waktu lokal.
class ReadingStats {
  const ReadingStats({this.seconds = const {}, this.comicChapters = const {}, this.novelChapters = const {}});

  final Map<String, int> seconds;
  final Map<String, int> comicChapters;
  final Map<String, int> novelChapters;

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int get totalSeconds => seconds.values.fold(0, (a, b) => a + b);
  int get totalComicChapters => comicChapters.values.fold(0, (a, b) => a + b);
  int get totalNovelChapters => novelChapters.values.fold(0, (a, b) => a + b);

  int secondsOn(DateTime day) => seconds[dayKey(day)] ?? 0;
  int chaptersOn(DateTime day) => (comicChapters[dayKey(day)] ?? 0) + (novelChapters[dayKey(day)] ?? 0);

  /// Jumlah detik dalam [days] hari terakhir (termasuk hari ini).
  int secondsLast(int days, {DateTime? now}) {
    final today = _today(now);
    return [for (var i = 0; i < days; i++) secondsOn(today.subtract(Duration(days: i)))].fold(0, (a, b) => a + b);
  }

  bool _active(DateTime day) => secondsOn(day) > 0 || chaptersOn(day) > 0;

  /// Hari berturut-turut ada aktivitas baca, dihitung mundur dari hari ini
  /// (atau kemarin, bila hari ini belum membaca).
  int streak({DateTime? now}) {
    var day = _today(now);
    if (!_active(day)) day = day.subtract(const Duration(days: 1));
    var n = 0;
    while (_active(day)) {
      n++;
      day = day.subtract(const Duration(days: 1));
    }
    return n;
  }

  int get activeDays => {...seconds.keys, ...comicChapters.keys, ...novelChapters.keys}.length;

  static DateTime _today(DateTime? now) {
    final n = now ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static ReadingStats parse(String? raw) {
    if (raw == null) return const ReadingStats();
    try {
      final json = asMap(jsonDecode(raw));
      Map<String, int> ints(Object? v) => {
            for (final e in asMap(v).entries)
              if (e.value is num) e.key: (e.value as num).toInt(),
          };
      return ReadingStats(
        seconds: ints(json['seconds']),
        comicChapters: ints(json['comic']),
        novelChapters: ints(json['novel']),
      );
    } catch (_) {
      return const ReadingStats();
    }
  }

  String encode() => jsonEncode({'seconds': seconds, 'comic': comicChapters, 'novel': novelChapters});

  /// Buang hari yang lebih lama dari [keepDays].
  ReadingStats pruned({int keepDays = 730, DateTime? now}) {
    final cutoff = dayKey(_today(now).subtract(Duration(days: keepDays)));
    Map<String, int> keep(Map<String, int> m) => {
          for (final e in m.entries)
            if (e.key.compareTo(cutoff) >= 0) e.key: e.value,
        };
    return ReadingStats(seconds: keep(seconds), comicChapters: keep(comicChapters), novelChapters: keep(novelChapters));
  }

  ReadingStats addSeconds(DateTime at, int value) =>
      ReadingStats(seconds: _inc(seconds, dayKey(at), value), comicChapters: comicChapters, novelChapters: novelChapters);

  ReadingStats addChapter(DateTime at, {required bool novel}) => ReadingStats(
        seconds: seconds,
        comicChapters: novel ? comicChapters : _inc(comicChapters, dayKey(at), 1),
        novelChapters: novel ? _inc(novelChapters, dayKey(at), 1) : novelChapters,
      );

  static Map<String, int> _inc(Map<String, int> m, String key, int by) => {...m, key: (m[key] ?? 0) + by};
}

final readingStatsProvider = NotifierProvider<ReadingStatsNotifier, ReadingStats>(ReadingStatsNotifier.new);

class ReadingStatsNotifier extends Notifier<ReadingStats> {
  static const key = 'stats.reading.v1';

  @override
  ReadingStats build() => ReadingStats.parse(ref.watch(sharedPreferencesProvider).getString(key));

  bool get _incognito => ref.read(appSettingsProvider).incognito;

  Future<void> _save(ReadingStats next) async {
    state = next;
    await ref.read(sharedPreferencesProvider).setString(key, next.pruned().encode());
  }

  Future<void> addReadingTime(Duration d) async {
    if (_incognito || d.inSeconds <= 0) return;
    await _save(state.addSeconds(DateTime.now(), d.inSeconds));
  }

  /// Dipanggil saat sebuah bab pertama kali selesai dibaca di reader.
  Future<void> chapterFinished({required bool novel}) async {
    if (_incognito) return;
    await _save(state.addChapter(DateTime.now(), novel: novel));
  }

  Future<void> reset() => _save(const ReadingStats());
}

/// Menghitung lama membaca dari aktivitas di reader (gulir, ganti halaman,
/// TTS). Jeda antar-aktivitas dihitung paling lama [maxGap], jadi reader
/// yang dibiarkan terbuka tidak menambah waktu tanpa batas.
class ReadingSession {
  ReadingSession(this._onFlush, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final void Function(Duration) _onFlush;
  final DateTime Function() _clock;

  static const maxGap = Duration(minutes: 3);
  static const _flushEvery = Duration(seconds: 30);

  DateTime? _last;
  Duration _pending = Duration.zero;

  void activity() {
    final now = _clock();
    final last = _last;
    if (last != null) {
      final gap = now.difference(last);
      if (!gap.isNegative) _pending += gap > maxGap ? maxGap : gap;
    }
    _last = now;
    if (_pending >= _flushEvery) flush();
  }

  /// Aplikasi ke latar / reader ditutup: catat sampai sekarang lalu berhenti.
  void pause() {
    if (_last != null) activity();
    _last = null;
    flush();
  }

  void flush() {
    if (_pending <= Duration.zero) return;
    final d = _pending;
    _pending = Duration.zero;
    _onFlush(d);
  }
}
