import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/json.dart';
import '../models/source_library.dart';
import 'source_library_store.dart';
import 'webdav_backup.dart';

/// Snapshot favorit, riwayat, dan progres baca yang disinkronkan antar perangkat.
class SyncSnapshot {
  const SyncSnapshot({this.favorites = const [], this.history = const [], this.progress = const {}});

  final List<SourceFavorite> favorites;
  final List<SourceHistoryEntry> history;
  final Map<String, Map<String, SourceChapterProgress>> progress;

  JsonMap toJson() => {
        'format': ProgressSync.format,
        'favorites': favorites.map((e) => e.toJson()).toList(),
        'history': history.map((e) => e.toJson()).toList(),
        'progress': {
          for (final s in progress.entries) s.key: {for (final c in s.value.entries) c.key: c.value.toJson()},
        },
      };

  static SyncSnapshot parse(Object? decoded) {
    final json = asMap(decoded);
    return SyncSnapshot(
      favorites: asList(json['favorites']).map((e) => SourceFavorite.tryParse(asMap(e))).whereType<SourceFavorite>().toList(),
      history:
          asList(json['history']).map((e) => SourceHistoryEntry.tryParse(asMap(e))).whereType<SourceHistoryEntry>().toList(),
      progress: {
        for (final s in asMap(json['progress']).entries)
          s.key: {
            for (final c in asMap(s.value).entries)
              if (SourceChapterProgress.tryParse(asMap(c.value)) case final p?) c.key: p,
          },
      },
    );
  }
}

/// Sinkron ringan lewat satu berkas `hub_reader_sync.json` di folder WebDAV.
///
/// Penggabungan bersifat per item: entri dengan cap waktu terbaru menang.
/// Favorit hanya digabung (union); penghapusan favorit tidak ikut tersinkron.
abstract final class ProgressSync {
  static const format = 'hub_reader-sync';
  static const fileName = 'hub_reader_sync.json';
  static const maxHistory = 300;

  static SyncSnapshot merge(SyncSnapshot local, SyncSnapshot remote) {
    final favorites = <String, SourceFavorite>{
      for (final f in remote.favorites) f.item.key: f,
      for (final f in local.favorites) f.item.key: f,
    };
    final history = <String, SourceHistoryEntry>{};
    for (final h in [...remote.history, ...local.history]) {
      final old = history[h.item.key];
      if (old == null || h.readAt.isAfter(old.readAt)) history[h.item.key] = h;
    }
    final progress = <String, Map<String, SourceChapterProgress>>{};
    for (final source in [remote.progress, local.progress]) {
      for (final series in source.entries) {
        final into = progress.putIfAbsent(series.key, () => {});
        for (final ch in series.value.entries) {
          final old = into[ch.key];
          if (old == null || ch.value.updatedAt.isAfter(old.updatedAt)) into[ch.key] = ch.value;
        }
      }
    }
    return SyncSnapshot(
      favorites: favorites.values.toList()..sort((a, b) => b.addedAt.compareTo(a.addedAt)),
      history: (history.values.toList()..sort((a, b) => b.readAt.compareTo(a.readAt))).take(maxHistory).toList(),
      progress: progress,
    );
  }

  /// Tarik berkas sinkron, gabungkan dengan data lokal, tulis hasilnya ke
  /// penyimpanan lokal lalu unggah. Mengembalikan hasil gabungan.
  static Future<SyncSnapshot> run(SharedPreferences prefs, {WebDavClient? client}) async {
    final cfg = await WebDavConfig.read(prefs);
    if (!cfg.configured) throw const WebDavException('Alamat WebDAV belum diisi');
    final dav = client ?? WebDavClient(cfg);
    final store = SourceLibraryStore(prefs);
    final local = SyncSnapshot(
      favorites: store.readFavorites(),
      history: store.readHistory(),
      progress: store.readProgress(),
    );
    var remote = const SyncSnapshot();
    final exists = (await dav.list()).any((f) => f.name == fileName);
    if (exists) {
      try {
        remote = SyncSnapshot.parse(jsonDecode(await dav.download(fileName)));
      } on FormatException {
        throw const WebDavException('Berkas sinkron di server rusak');
      }
    }
    final merged = merge(local, remote);
    await store.writeFavorites(merged.favorites);
    await store.writeHistory(merged.history);
    await store.writeProgress(merged.progress);
    await dav.upload(fileName, utf8.encode(jsonEncode(merged.toJson())));
    return merged;
  }
}
