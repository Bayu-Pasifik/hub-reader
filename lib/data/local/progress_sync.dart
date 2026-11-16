import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/json.dart';
import '../models/source_library.dart';
import 'source_library_store.dart';
import 'webdav_backup.dart';

/// Snapshot favorit, riwayat, dan progres baca yang disinkronkan antar perangkat.
class SyncSnapshot {
  const SyncSnapshot({
    this.favorites = const [],
    this.history = const [],
    this.progress = const {},
    this.removed = const {},
  });

  final List<SourceFavorite> favorites;
  final List<SourceHistoryEntry> history;
  final Map<String, Map<String, SourceChapterProgress>> progress;

  /// Tombstone favorit: `{kunci seri: waktu dihapus}`.
  final Map<String, DateTime> removed;

  JsonMap toJson() => {
        'format': ProgressSync.format,
        'removed': {for (final e in removed.entries) e.key: e.value.toIso8601String()},
        'favorites': favorites.map((e) => e.toJson()).toList(),
        'history': history.map((e) => e.toJson()).toList(),
        'progress': {
          for (final s in progress.entries) s.key: {for (final c in s.value.entries) c.key: c.value.toJson()},
        },
      };

  static SyncSnapshot parse(Object? decoded) {
    final json = asMap(decoded);
    return SyncSnapshot(
      removed: {
        for (final e in asMap(json['removed']).entries)
          if (asDate(e.value) case final d?) e.key: d,
      },
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
/// Favorit digabung (union); penghapusan ikut tersinkron lewat tombstone:
/// favorit hilang bila waktu hapusnya lebih baru dari saat difavoritkan.
abstract final class ProgressSync {
  static const format = 'hub_reader-sync';
  static const fileName = 'hub_reader_sync.json';
  static const maxHistory = 300;

  /// Tombstone lebih tua dari ini dibuang agar berkas tidak membengkak.
  static const tombstoneTtl = Duration(days: 90);

  static SyncSnapshot merge(SyncSnapshot local, SyncSnapshot remote, {DateTime? now}) {
    final removed = <String, DateTime>{};
    for (final src in [remote.removed, local.removed]) {
      for (final e in src.entries) {
        final old = removed[e.key];
        if (old == null || e.value.isAfter(old)) removed[e.key] = e.value;
      }
    }
    final favorites = <String, SourceFavorite>{
      for (final f in remote.favorites) f.item.key: f,
      for (final f in local.favorites) f.item.key: f,
    };
    for (final key in favorites.keys.toList()) {
      final tomb = removed[key];
      if (tomb == null) continue;
      if (tomb.isAfter(favorites[key]!.aliveSince)) {
        favorites.remove(key);
      } else {
        removed.remove(key); // difavoritkan ulang setelah dihapus
      }
    }
    final cutoff = (now ?? DateTime.now()).subtract(tombstoneTtl);
    removed.removeWhere((_, at) => at.isBefore(cutoff));
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
      removed: removed,
    );
  }

  /// Tarik berkas sinkron, gabungkan dengan data lokal, tulis hasilnya ke
  /// penyimpanan lokal lalu unggah. Mengembalikan hasil gabungan.
  static Future<SyncSnapshot> run(SharedPreferences prefs, {WebDavClient? client, SourceLibraryStore? library}) async {
    final cfg = await WebDavConfig.read(prefs);
    if (!cfg.configured) throw const WebDavException('Alamat WebDAV belum diisi');
    final dav = client ?? WebDavClient(cfg);
    final store = library ?? SourceLibraryStore(prefs);
    final local = SyncSnapshot(
      favorites: store.readFavorites(),
      history: store.readHistory(),
      progress: store.readProgress(),
      removed: store.readRemoved(),
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
    await store.writeRemoved(merged.removed);
    await store.writeFavorites(merged.favorites);
    await store.writeHistory(merged.history);
    await store.writeProgress(merged.progress);
    await dav.upload(fileName, utf8.encode(jsonEncode(merged.toJson())));
    return merged;
  }
}
