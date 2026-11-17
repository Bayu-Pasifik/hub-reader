// Basis untuk situs webcomic satu-seri (satu situs = satu judul), dipakai
// beberapa sumber dewasa/webcomic keiyoushi/extensions-source (Apache-2.0).

import '../filters.dart';
import '../models.dart';
import '../source.dart';

class SingleSeriesSource extends HttpSource {
  SingleSeriesSource({
    required this.id,
    required this.name,
    required String baseUrl,
    required this.seriesTitle,
    required this.loadChapters,
    required this.loadPages,
    this.author,
    this.description,
    this.cover,
    this.genres = const [],
    this.status = SourceMangaStatus.ongoing,
    this.contentWarning = ContentWarning.nsfw,
    this.lang = 'en',
    super.dio,
  }) : defaultBaseUrl = baseUrl;

  @override
  final String id;
  @override
  final String name;
  @override
  final String defaultBaseUrl;
  @override
  final String lang;
  @override
  final ContentWarning contentWarning;
  @override
  bool get supportsLatest => false;

  final String seriesTitle;
  final String? author;
  final String? description;
  final String? cover;
  final List<String> genres;
  final SourceMangaStatus status;

  /// Daftar bab (terbaru dulu) dan URL gambar satu bab.
  final Future<List<SourceChapter>> Function(SingleSeriesSource s) loadChapters;
  final Future<List<String>> Function(SingleSeriesSource s, SourceChapter chapter) loadPages;

  SourceManga get _item => SourceManga(url: '$baseUrl/#series', title: seriesTitle, thumbnailUrl: cover);

  @override
  Future<MangaPage> popular(int page) async =>
      page > 1 ? const MangaPage([], hasNextPage: false) : MangaPage([_item], hasNextPage: false);

  @override
  Future<MangaPage> latest(int page) => popular(page);

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    final q = query.trim().toLowerCase();
    if (page > 1 || (q.isNotEmpty && !seriesTitle.toLowerCase().contains(q))) {
      return const MangaPage([], hasNextPage: false);
    }
    return MangaPage([_item], hasNextPage: false);
  }

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async => SourceMangaDetails(
        url: mangaUrl,
        title: seriesTitle,
        thumbnailUrl: cover,
        author: author,
        artist: author,
        description: description,
        genres: genres,
        status: status,
        chapters: await loadChapters(this),
      );

  @override
  Future<List<String>> pages(SourceChapter chapter) => loadPages(this, chapter);
}
