import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/json.dart';
import '../sources/html_utils.dart';
import '../trackers/kitsu.dart';
import '../trackers/mangaupdates.dart';
import '../trackers/tracker.dart';
import 'app_settings_provider.dart';
import 'core_providers.dart';

final trackersProvider = Provider<List<Tracker>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return [AniListTracker(prefs), MalTracker(prefs), KitsuTracker(prefs), MangaUpdatesTracker(prefs)];
});

Tracker? trackerById(List<Tracker> trackers, String id) => trackers.where((t) => t.id == id).firstOrNull;

/// Satu seri lokal yang ditautkan ke entri tracker.
class TrackLink {
  const TrackLink({
    required this.tracker,
    required this.mediaId,
    required this.title,
    this.progress = 0,
    this.total,
    this.status = TrackStatus.reading,
    this.url,
  });

  final String tracker;
  final int mediaId;
  final String title;
  final int progress;
  final int? total;
  final TrackStatus status;
  final String? url;

  TrackLink copyWith({int? progress, int? total, TrackStatus? status}) => TrackLink(
        tracker: tracker,
        mediaId: mediaId,
        title: title,
        progress: progress ?? this.progress,
        total: total ?? this.total,
        status: status ?? this.status,
        url: url,
      );

  static TrackLink? tryParse(Object? raw) {
    final j = asMap(raw);
    final tracker = asString(j['tracker']);
    final id = asInt(j['media_id']);
    if (tracker == null || id == null) return null;
    return TrackLink(
      tracker: tracker,
      mediaId: id,
      title: asString(j['title']) ?? '?',
      progress: asInt(j['progress']) ?? 0,
      total: asInt(j['total']),
      status: TrackStatus.values.where((s) => s.name == j['status']).firstOrNull ?? TrackStatus.reading,
      url: asString(j['url']),
    );
  }

  JsonMap toJson() => {
        'tracker': tracker,
        'media_id': mediaId,
        'title': title,
        'progress': progress,
        if (total != null) 'total': total,
        'status': status.name,
        if (url != null) 'url': url,
      };
}

/// Tautan tracker per seri (`sourceId|url`).
final trackLinksProvider = NotifierProvider<TrackLinksNotifier, Map<String, List<TrackLink>>>(TrackLinksNotifier.new);

class TrackLinksNotifier extends Notifier<Map<String, List<TrackLink>>> {
  static const _key = 'tracker.links.v1';

  @override
  Map<String, List<TrackLink>> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    if (raw == null) return {};
    try {
      return {
        for (final e in asMap(jsonDecode(raw)).entries)
          e.key: asList(e.value).map(TrackLink.tryParse).whereType<TrackLink>().toList(),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _save() => ref.read(sharedPreferencesProvider).setString(
        _key,
        jsonEncode({
          for (final e in state.entries) e.key: [for (final l in e.value) l.toJson()]
        }),
      );

  Future<void> put(String seriesKey, TrackLink link) async {
    state = {
      ...state,
      seriesKey: [...?state[seriesKey]?.where((l) => l.tracker != link.tracker), link],
    };
    await _save();
  }

  Future<void> remove(String seriesKey, String tracker) async {
    final rest = [...?state[seriesKey]?.where((l) => l.tracker != tracker)];
    state = {...state}..[seriesKey] = rest;
    if (rest.isEmpty) state = {...state}..remove(seriesKey);
    await _save();
  }

  /// Kirim progres & status ke tracker lalu simpan lokal.
  Future<void> push(String seriesKey, TrackLink link) async {
    final tracker = trackerById(ref.read(trackersProvider), link.tracker);
    if (tracker == null || !tracker.loggedIn) throw TrackerException('Belum login ke ${tracker?.name ?? link.tracker}');
    await tracker.update(link.mediaId, progress: link.progress, status: link.status);
    await put(seriesKey, link);
  }

  /// Bab [chapterName] selesai dibaca: naikkan progres di semua tracker yang
  /// tertaut bila nomor bab lebih tinggi (tidak pernah menurunkan progres).
  /// Gagal kirim diabaikan (dicoba lagi saat bab berikutnya selesai).
  Future<void> chapterRead(String seriesKey, String chapterName, {double? number}) async {
    if (ref.read(appSettingsProvider).incognito) return;
    final n = (number != null && number >= 0) ? number : parseChapterNumber(chapterName);
    if (n == null) return;
    final chapter = n.floor();
    for (final link in [...?state[seriesKey]]) {
      if (chapter <= link.progress) continue;
      final total = link.total;
      final status = total != null && chapter >= total
          ? TrackStatus.completed
          : (link.status == TrackStatus.planning || link.status == TrackStatus.onHold
              ? TrackStatus.reading
              : link.status);
      try {
        await push(seriesKey, link.copyWith(progress: chapter, status: status));
      } catch (_) {
        // offline / belum login: coba lagi nanti
      }
    }
  }
}
