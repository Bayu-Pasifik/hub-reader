import '../../core/utils/json.dart';

/// Isi satu bab yang siap ditampilkan secara native.
///
/// TODO(scraper-hub): Endpoint isi bab BELUM ADA. Saat ini scraper-hub hanya
/// menyimpan metadata bab (nomor, judul, URL sumber, is_locked) — tabel
/// novel_chapters / comic_chapters tidak punya kolom konten, dan scraper
/// (ComixScraper, WtrLabScraper) hanya mem-parsing halaman seri.
///
/// Usulan kontrak agar reader native di aplikasi langsung aktif:
///   GET /api/v1/{novels|comics}/{id}/chapters/{number}
///   novel → {"data": {"number": 12, "title": "...", "kind": "text",
///                      "paragraphs": ["...", "..."]}}
///   komik → {"data": {"number": 12, "title": "...", "kind": "images",
///                      "pages": ["https://.../001.jpg", "..."]}}
///
/// Sampai endpoint itu ada, ReaderScreen membuka `Chapter.url` di WebView.
sealed class ChapterContent {
  const ChapterContent();

  static ChapterContent? fromJson(JsonMap json) {
    final data = asMap(json['data']);
    return switch (asString(data['kind'])) {
      'text' => TextChapterContent(asStringList(data['paragraphs'])),
      'images' => ImageChapterContent(asStringList(data['pages'])),
      _ => null,
    };
  }
}

class TextChapterContent extends ChapterContent {
  const TextChapterContent(this.paragraphs);

  final List<String> paragraphs;
}

class ImageChapterContent extends ChapterContent {
  const ImageChapterContent(this.pages);

  final List<String> pages;
}
