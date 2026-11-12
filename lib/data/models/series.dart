import '../../core/utils/json.dart';
import 'chapter.dart';

/// Jenis konten yang dikenal scraper-hub. Nilai `type` di JSON berasal dari
/// morph map Laravel: "novel" / "comic". [path] = segmen URL endpoint.
enum SeriesType {
  novel('novels', 'Novel'),
  comic('comics', 'Komik');

  const SeriesType(this.path, this.label);

  final String path;
  final String label;

  static SeriesType fromApi(String? value) => switch (value) {
        'comic' || 'comics' => SeriesType.comic,
        _ => SeriesType.novel,
      };
}

/// Representasi `App\Http\Resources\SeriesResource`.
///
/// Contoh (GET /api/v1/novels/{id}):
/// ```json
/// {"data": {"id": 1, "type": "novel", "source": "wtr-lab", "external_id": "123",
///   "title": "...", "slug": "...", "author": "...", "genres": ["Action"],
///   "tags": [], "status": "ongoing", "description": "... (hanya di detail)",
///   "cover": {"thumbnail": "http://.../storage/covers/1.webp", "original": "https://..."},
///   "source_url": "https://...", "chapter_count": 120, "scraped_at": "2026-11-10T...",
///   "latest_chapters": [ChapterResource x5, hanya di detail],
///   "links": {"self": "...", "chapters": "..."}}}
/// ```
class Series {
  const Series({
    required this.id,
    required this.type,
    required this.title,
    this.source,
    this.externalId,
    this.slug,
    this.author,
    this.genres = const [],
    this.tags = const [],
    this.status,
    this.description,
    this.coverThumbnail,
    this.coverOriginal,
    this.sourceUrl,
    this.chapterCount = 0,
    this.scrapedAt,
    this.latestChapters = const [],
  });

  final int id;
  final SeriesType type;
  final String title;
  final String? source;
  final String? externalId;
  final String? slug;
  final String? author;
  final List<String> genres;
  final List<String> tags;
  final String? status;

  /// Hanya terisi dari endpoint detail (`show`), null di daftar.
  final String? description;
  final String? coverThumbnail;
  final String? coverOriginal;
  final String? sourceUrl;
  final int chapterCount;
  final DateTime? scrapedAt;
  final List<Chapter> latestChapters;

  /// Thumbnail WebP lokal lebih ringan; fallback ke URL sampul asli.
  String? get coverUrl => coverThumbnail ?? coverOriginal;

  /// Versi aman untuk daftar: item rusak dilewati, bukan menggagalkan semua.
  static Series? tryParse(JsonMap json) {
    try {
      return Series.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  factory Series.fromJson(JsonMap json) {
    final id = asInt(json['id']);
    if (id == null) {
      throw const FormatException('Series tanpa id');
    }
    final cover = asMap(json['cover']);
    return Series(
      id: id,
      type: SeriesType.fromApi(asString(json['type'])),
      title: asString(json['title']) ?? 'Tanpa judul',
      source: asString(json['source']),
      externalId: asString(json['external_id']),
      slug: asString(json['slug']),
      author: asString(json['author']),
      genres: asStringList(json['genres']),
      tags: asStringList(json['tags']),
      status: asString(json['status']),
      description: asString(json['description']),
      coverThumbnail: asString(cover['thumbnail']),
      coverOriginal: asString(cover['original']),
      sourceUrl: asString(json['source_url']),
      chapterCount: asInt(json['chapter_count']) ?? 0,
      scrapedAt: asDate(json['scraped_at']),
      latestChapters: asList(json['latest_chapters'])
          .map((e) => Chapter.tryParse(asMap(e)))
          .whereType<Chapter>()
          .toList(growable: false),
    );
  }
}
