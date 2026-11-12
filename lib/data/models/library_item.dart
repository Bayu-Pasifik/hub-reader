import '../../core/utils/json.dart';
import 'chapter.dart';
import 'series.dart';

/// Ringkasan seri yang disimpan lokal (favorit & riwayat), supaya kedua daftar
/// tetap tampil walau API mati.
class LibraryItem {
  const LibraryItem({
    required this.type,
    required this.id,
    required this.title,
    this.coverUrl,
    this.author,
    this.status,
  });

  final SeriesType type;
  final int id;
  final String title;

  /// URL mentah dari API; di-resolve saat ditampilkan (lihat resolveMediaUrl).
  final String? coverUrl;
  final String? author;
  final String? status;

  String get key => '${type.name}:$id';

  factory LibraryItem.fromSeries(Series series) => LibraryItem(
        type: series.type,
        id: series.id,
        title: series.title,
        coverUrl: series.coverUrl,
        author: series.author,
        status: series.status,
      );

  static LibraryItem? tryParse(JsonMap json) {
    final id = asInt(json['id']);
    if (id == null) return null;
    return LibraryItem(
      type: SeriesType.fromApi(asString(json['type'])),
      id: id,
      title: asString(json['title']) ?? 'Tanpa judul',
      coverUrl: asString(json['cover_url']),
      author: asString(json['author']),
      status: asString(json['status']),
    );
  }

  JsonMap toJson() => {
        'type': type.name,
        'id': id,
        'title': title,
        'cover_url': coverUrl,
        'author': author,
        'status': status,
      };
}

class FavoriteEntry {
  const FavoriteEntry({required this.item, required this.addedAt});

  final LibraryItem item;
  final DateTime addedAt;

  static FavoriteEntry? tryParse(JsonMap json) {
    final item = LibraryItem.tryParse(asMap(json['item']));
    if (item == null) return null;
    return FavoriteEntry(item: item, addedAt: asDate(json['added_at']) ?? DateTime.now());
  }

  JsonMap toJson() => {'item': item.toJson(), 'added_at': addedAt.toIso8601String()};
}

/// Satu entri per seri: bab terakhir yang dibuka.
class HistoryEntry {
  const HistoryEntry({
    required this.item,
    required this.chapterNumber,
    required this.readAt,
    this.chapterTitle,
  });

  final LibraryItem item;
  final double chapterNumber;
  final String? chapterTitle;
  final DateTime readAt;

  factory HistoryEntry.create(LibraryItem item, Chapter chapter) => HistoryEntry(
        item: item,
        chapterNumber: chapter.number,
        chapterTitle: chapter.title,
        readAt: DateTime.now(),
      );

  static HistoryEntry? tryParse(JsonMap json) {
    final item = LibraryItem.tryParse(asMap(json['item']));
    final number = asDouble(json['chapter_number']);
    if (item == null || number == null) return null;
    return HistoryEntry(
      item: item,
      chapterNumber: number,
      chapterTitle: asString(json['chapter_title']),
      readAt: asDate(json['read_at']) ?? DateTime.now(),
    );
  }

  JsonMap toJson() => {
        'item': item.toJson(),
        'chapter_number': chapterNumber,
        'chapter_title': chapterTitle,
        'read_at': readAt.toIso8601String(),
      };
}
