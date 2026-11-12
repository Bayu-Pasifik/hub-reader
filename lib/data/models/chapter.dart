import '../../core/utils/formatters.dart';
import '../../core/utils/json.dart';

/// Representasi `App\Http\Resources\ChapterResource`.
///
/// ```json
/// {"number": 12.0, "title": "Chapter 12", "url": "https://sumber/.../12",
///  "is_locked": false, "published_at": "2026-11-01T10:00:00+00:00"}
/// ```
///
/// Catatan: scraper-hub hanya menyimpan METADATA bab + URL halaman sumber,
/// bukan isi bab (teks novel / gambar komik). Lihat ChapterContent.
class Chapter {
  const Chapter({
    required this.number,
    required this.url,
    this.title,
    this.isLocked = false,
    this.publishedAt,
  });

  final double number;
  final String? title;
  final String url;
  final bool isLocked;
  final DateTime? publishedAt;

  String get label => 'Bab ${formatChapterNumber(number)}';

  /// null bila data bab tidak lengkap (tanpa nomor/URL), supaya satu baris
  /// rusak tidak menggagalkan seluruh daftar.
  static Chapter? tryParse(JsonMap json) {
    final number = asDouble(json['number']);
    final url = asString(json['url']);
    if (number == null || url == null) return null;
    return Chapter(
      number: number,
      url: url,
      title: asString(json['title']),
      isLocked: asBool(json['is_locked']),
      publishedAt: asDate(json['published_at']),
    );
  }

  bool isNumber(double other) => (number - other).abs() < 0.0001;
}
