// Basis untuk situs webcomic dengan satu atau beberapa seri tetap, dipakai
// banyak sumber keiyoushi/extensions-source (Apache-2.0). Tiap seri punya
// pemuat bab dan pemuat halaman sendiri.

import '../filters.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';

typedef ChapterLoader = Future<List<SourceChapter>> Function(HttpSource s);
typedef PageLoader = Future<List<String>> Function(
    HttpSource s, SourceChapter chapter);

class SeriesDef {
  const SeriesDef({
    required this.key,
    required this.title,
    required this.loadChapters,
    required this.loadPages,
    this.author,
    this.description,
    this.cover,
    this.loadCover,
    this.genres = const [],
    this.status = SourceMangaStatus.ongoing,
  });

  final String key;
  final String title;
  final String? author;
  final String? description;
  final String? cover;

  /// Cover dinamis (mis. og:image) bila [cover] tidak diketahui.
  final Future<String?> Function(HttpSource s)? loadCover;
  final List<String> genres;
  final SourceMangaStatus status;
  final ChapterLoader loadChapters;
  final PageLoader loadPages;
}

class MultiSeriesSource extends HttpSource {
  MultiSeriesSource({
    required this.id,
    required this.name,
    required String baseUrl,
    required this.series,
    this.contentWarning = ContentWarning.safe,
    this.lang = 'en',
    this.referer = false,
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

  final List<SeriesDef> series;
  final bool referer;

  SourceManga _item(SeriesDef d, [String? cover]) => SourceManga(
      url: '$baseUrl/#${d.key}',
      title: d.title,
      thumbnailUrl: d.cover ?? cover);

  SeriesDef _def(String url) {
    final key = url.contains('#') ? url.substring(url.indexOf('#') + 1) : '';
    return series.firstWhere((d) => d.key == key, orElse: () => series.first);
  }

  Future<String?> _cover(SeriesDef d) async {
    if (d.cover != null || d.loadCover == null) return d.cover;
    try {
      return await d.loadCover!(this);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<MangaPage> popular(int page) async => page > 1
      ? const MangaPage([], hasNextPage: false)
      : MangaPage([
          for (final d in series)
            _item(d, d == series.first ? await _cover(d) : null)
        ], hasNextPage: false);

  @override
  Future<MangaPage> latest(int page) => popular(page);

  @override
  Future<MangaPage> search(int page, String query,
      {FilterValues filters = FilterValues.empty}) async {
    final q = query.trim().toLowerCase();
    if (page > 1) return const MangaPage([], hasNextPage: false);
    return MangaPage([
      for (final d in series)
        if (q.isEmpty || d.title.toLowerCase().contains(q)) _item(d),
    ], hasNextPage: false);
  }

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final d = _def(mangaUrl);
    return SourceMangaDetails(
      url: mangaUrl,
      title: d.title,
      thumbnailUrl: await _cover(d),
      author: d.author,
      artist: d.author,
      description: d.description,
      genres: d.genres,
      status: d.status,
      chapters: [
        for (final c in await d.loadChapters(this))
          SourceChapter(
            url: series.length > 1 ? '${d.key}|${c.url}' : c.url,
            name: c.name,
            number: c.number,
            uploadedAt: c.uploadedAt,
            scanlator: c.scanlator,
          ),
      ],
    );
  }

  /// Pada multi-seri, URL bab diawali `key|` agar pemuat halaman tahu seri-nya.
  @override
  Future<List<String>> pages(SourceChapter chapter) {
    final bar = chapter.url.indexOf('|');
    final d = bar > 0 && series.length > 1
        ? series.firstWhere((e) => e.key == chapter.url.substring(0, bar),
            orElse: () => series.first)
        : series.first;
    final real = bar > 0 && series.length > 1
        ? chapter.url.substring(bar + 1)
        : chapter.url;
    return d.loadPages(
        this,
        SourceChapter(
            url: real,
            name: chapter.name,
            number: chapter.number,
            uploadedAt: chapter.uploadedAt));
  }
}

Uri wcUri(HttpSource s, String path) =>
    Uri.parse(path.startsWith('http') ? path : '${s.baseUrl}$path');

Future<HtmlResponse> wcGet(HttpSource s, String path) =>
    s.fetchHtml(wcUri(s, path));

/// Semua gambar yang cocok dengan [selector] pada halaman bab.
PageLoader wcImgs(String selector) => (s, ch) async {
      final res = await wcGet(s, ch.url);
      return [
        for (final img in res.document.querySelectorAll(selector))
          if (imgAttr(img, res.url) case final u?) u,
      ];
    };

/// Cover dari meta og:image beranda.
Future<String?> wcOgImage(HttpSource s) async {
  final res = await wcGet(s, '/');
  final meta = res.document.querySelector("meta[property='og:image']");
  return absUrl(res.url, meta?.attributes['content']);
}
