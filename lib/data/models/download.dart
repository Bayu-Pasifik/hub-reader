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

  /// Disimpan agar antrean bertahan saat aplikasi ditutup. Tugas yang
  /// sedang berjalan disimpan sebagai "antre" dan diulang dari awal bab
  /// (halaman yang sudah ada di disk dilewati).
  JsonMap toJson() => {
        'source_id': sourceId,
        'manga_url': mangaUrl,
        'manga_title': mangaTitle,
        'thumbnail_url': thumbnailUrl,
        'chapter_url': chapter.url,
        'chapter_name': chapter.name,
        'chapter_number': chapter.number,
        'uploaded_at': chapter.uploadedAt?.toIso8601String(),
        'failed': status == DownloadStatus.failed,
        'error': error,
      };

  static DownloadTask? tryParse(JsonMap json) {
    final sourceId = asString(json['source_id']);
    final chapterUrl = asString(json['chapter_url']);
    if (sourceId == null || chapterUrl == null) return null;
    final failed = json['failed'] == true;
    return DownloadTask(
      sourceId: sourceId,
      mangaUrl: asString(json['manga_url']) ?? '',
      mangaTitle: asString(json['manga_title']) ?? 'Tanpa judul',
      thumbnailUrl: asString(json['thumbnail_url']),
      chapter: SourceChapter(
        url: chapterUrl,
        name: asString(json['chapter_name']) ?? 'Bab',
        number: asDouble(json['chapter_number']),
        uploadedAt: asDate(json['uploaded_at']),
      ),
      status: failed ? DownloadStatus.failed : DownloadStatus.queued,
      error: failed ? asString(json['error']) : null,
    );
  }

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
