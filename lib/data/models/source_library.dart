import '../../core/utils/json.dart';
import '../../sources/models.dart';

/// Ringkasan seri dari sumber on-device, disimpan lokal untuk favorit & riwayat.
class SourceLibraryItem {
  const SourceLibraryItem({
    required this.sourceId,
    required this.url,
    required this.title,
    this.thumbnailUrl,
  });

  final String sourceId;

  /// URL absolut halaman seri di situs sumber.
  final String url;
  final String title;
  final String? thumbnailUrl;

  String get key => '$sourceId|$url';

  /// [url] = URL rute (bukan `details.url` yang bisa berbeda setelah redirect),
  /// supaya kunci favorit/riwayat konsisten dengan yang dibuka pengguna.
  factory SourceLibraryItem.fromDetails(String sourceId, String url, SourceMangaDetails details) =>
      SourceLibraryItem(
        sourceId: sourceId,
        url: url,
        title: details.title,
        thumbnailUrl: details.thumbnailUrl,
      );

  static SourceLibraryItem? tryParse(JsonMap json) {
    final sourceId = asString(json['source_id']);
    final url = asString(json['url']);
    if (sourceId == null || url == null) return null;
    return SourceLibraryItem(
      sourceId: sourceId,
      url: url,
      title: asString(json['title']) ?? 'Tanpa judul',
      thumbnailUrl: asString(json['thumbnail_url']),
    );
  }

  JsonMap toJson() => {
        'source_id': sourceId,
        'url': url,
        'title': title,
        'thumbnail_url': thumbnailUrl,
      };
}

class SourceFavorite {
  const SourceFavorite({required this.item, required this.addedAt});

  final SourceLibraryItem item;
  final DateTime addedAt;

  static SourceFavorite? tryParse(JsonMap json) {
    final item = SourceLibraryItem.tryParse(asMap(json['item']));
    if (item == null) return null;
    return SourceFavorite(item: item, addedAt: asDate(json['added_at']) ?? DateTime.now());
  }

  JsonMap toJson() => {'item': item.toJson(), 'added_at': addedAt.toIso8601String()};
}

/// Posisi baca satu bab.
class SourceChapterProgress {
  const SourceChapterProgress({
    required this.page,
    required this.total,
    required this.done,
    required this.updatedAt,
  });

  /// Indeks halaman terakhir yang terlihat (0-based).
  final int page;
  final int total;

  /// true bila halaman terakhir sudah tercapai.
  final bool done;
  final DateTime updatedAt;

  static SourceChapterProgress? tryParse(JsonMap json) {
    final page = asInt(json['page']);
    if (page == null) return null;
    return SourceChapterProgress(
      page: page,
      total: asInt(json['total']) ?? 0,
      done: json['done'] == true,
      updatedAt: asDate(json['updated_at']) ?? DateTime.now(),
    );
  }

  JsonMap toJson() => {
        'page': page,
        'total': total,
        'done': done,
        'updated_at': updatedAt.toIso8601String(),
      };
}

/// Satu entri per seri: bab terakhir yang dibuka.
class SourceHistoryEntry {
  const SourceHistoryEntry({
    required this.item,
    required this.chapterUrl,
    required this.chapterName,
    required this.readAt,
  });

  final SourceLibraryItem item;
  final String chapterUrl;
  final String chapterName;
  final DateTime readAt;

  static SourceHistoryEntry? tryParse(JsonMap json) {
    final item = SourceLibraryItem.tryParse(asMap(json['item']));
    final chapterUrl = asString(json['chapter_url']);
    if (item == null || chapterUrl == null) return null;
    return SourceHistoryEntry(
      item: item,
      chapterUrl: chapterUrl,
      chapterName: asString(json['chapter_name']) ?? 'Bab',
      readAt: asDate(json['read_at']) ?? DateTime.now(),
    );
  }

  JsonMap toJson() => {
        'item': item.toJson(),
        'chapter_url': chapterUrl,
        'chapter_name': chapterName,
        'read_at': readAt.toIso8601String(),
      };
}
