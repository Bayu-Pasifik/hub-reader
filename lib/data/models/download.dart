import '../../core/utils/json.dart';
import '../../sources/models.dart';

/// Kunci unik satu bab dari satu sumber.
String chapterKey(String sourceId, String chapterUrl) => '$sourceId|$chapterUrl';

/// Bab yang sudah selesai diunduh (entri indeks).
class DownloadedChapter {
  const DownloadedChapter({
    required this.sourceId,
    required this.mangaUrl,
    required this.mangaTitle,
    required this.chapterUrl,
    required this.chapterName,
    required this.relativeDir,
    required this.files,
    required this.downloadedAt,
    this.thumbnailUrl,
  });

  final String sourceId;
  final String mangaUrl;
  final String mangaTitle;
  final String? thumbnailUrl;
  final String chapterUrl;
  final String chapterName;

  /// Folder relatif terhadap folder unduhan aplikasi.
  final String relativeDir;

  /// Nama file halaman, berurutan.
  final List<String> files;
  final DateTime downloadedAt;

  String get key => chapterKey(sourceId, chapterUrl);
  String get mangaKey => '$sourceId|$mangaUrl';

  static DownloadedChapter? tryParse(JsonMap json) {
    final sourceId = asString(json['source_id']);
    final chapterUrl = asString(json['chapter_url']);
    final dir = asString(json['dir']);
    if (sourceId == null || chapterUrl == null || dir == null) return null;
    return DownloadedChapter(
      sourceId: sourceId,
      mangaUrl: asString(json['manga_url']) ?? '',
      mangaTitle: asString(json['manga_title']) ?? 'Tanpa judul',
      thumbnailUrl: asString(json['thumbnail_url']),
      chapterUrl: chapterUrl,
      chapterName: asString(json['chapter_name']) ?? 'Bab',
      relativeDir: dir,
      files: asStringList(json['files']),
      downloadedAt: asDate(json['downloaded_at']) ?? DateTime.now(),
    );
  }

  JsonMap toJson() => {
        'source_id': sourceId,
        'manga_url': mangaUrl,
        'manga_title': mangaTitle,
        'thumbnail_url': thumbnailUrl,
        'chapter_url': chapterUrl,
        'chapter_name': chapterName,
        'dir': relativeDir,
        'files': files,
        'downloaded_at': downloadedAt.toIso8601String(),
      };
}

enum DownloadStatus { queued, downloading, failed }

/// Satu bab di antrean unduhan (belum selesai).
class DownloadTask {
  const DownloadTask({
    required this.sourceId,
    required this.mangaUrl,
    required this.mangaTitle,
    required this.chapter,
    this.thumbnailUrl,
    this.status = DownloadStatus.queued,
    this.done = 0,
    this.total = 0,
    this.error,
  });

  final String sourceId;
  final String mangaUrl;
  final String mangaTitle;
  final String? thumbnailUrl;
  final SourceChapter chapter;
  final DownloadStatus status;
  final int done;
  final int total;
  final String? error;

  String get key => chapterKey(sourceId, chapter.url);

  double? get progress => total == 0 ? null : done / total;

  DownloadTask copyWith({DownloadStatus? status, int? done, int? total, String? error}) => DownloadTask(
        sourceId: sourceId,
        mangaUrl: mangaUrl,
        mangaTitle: mangaTitle,
        thumbnailUrl: thumbnailUrl,
        chapter: chapter,
        status: status ?? this.status,
        done: done ?? this.done,
        total: total ?? this.total,
        error: error,
      );
}
