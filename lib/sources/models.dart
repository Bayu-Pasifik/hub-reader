/// Model data untuk extension sumber on-device.
///
/// Padanan model Mihon: SManga → [SourceManga]/[SourceMangaDetails],
/// SChapter → [SourceChapter], MangasPage → [MangaPage].
/// Semua URL disimpan ABSOLUT (berbeda dengan Mihon yang menyimpan path).
library;

enum ContentWarning {
  safe('Aman'),
  mixed('Campuran'),
  nsfw('18+');

  const ContentWarning(this.label);

  final String label;
}

enum SourceMangaStatus {
  unknown('Tidak diketahui'),
  ongoing('Berjalan'),
  completed('Tamat'),
  hiatus('Hiatus'),
  cancelled('Dihentikan');

  const SourceMangaStatus(this.label);

  final String label;
}

/// Item ringkas di daftar populer / terbaru / pencarian.
class SourceManga {
  const SourceManga({required this.url, required this.title, this.thumbnailUrl});

  final String url;
  final String title;
  final String? thumbnailUrl;

  @override
  bool operator ==(Object other) => other is SourceManga && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

class MangaPage {
  const MangaPage(this.items, {required this.hasNextPage});

  final List<SourceManga> items;
  final bool hasNextPage;
}

class SourceChapter {
  const SourceChapter({
    required this.url,
    required this.name,
    this.number,
    this.uploadedAt,
  });

  final String url;
  final String name;

  /// Nomor bab hasil parsing (bisa null bila judul tidak mengandung angka).
  final double? number;
  final DateTime? uploadedAt;

  @override
  bool operator ==(Object other) => other is SourceChapter && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

/// Detail seri + daftar bab (diambil dari satu halaman, seperti Mihon).
///
/// [chapters] berurutan TERBARU → TERLAMA, sesuai urutan situs.
class SourceMangaDetails {
  const SourceMangaDetails({
    required this.url,
    required this.title,
    this.thumbnailUrl,
    this.author,
    this.artist,
    this.description,
    this.genres = const [],
    this.status = SourceMangaStatus.unknown,
    this.chapters = const [],
  });

  final String url;
  final String title;
  final String? thumbnailUrl;
  final String? author;
  final String? artist;
  final String? description;
  final List<String> genres;
  final SourceMangaStatus status;
  final List<SourceChapter> chapters;
}
