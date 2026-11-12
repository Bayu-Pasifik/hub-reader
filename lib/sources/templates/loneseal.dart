// Port Dart dari template LoneSeal milik keiyoushi/extensions-source
// (Apache-2.0): lib-multisrc/loneseal.
//
// Situs LoneSeal punya API JSON di `https://api.<domain>/api` (atau
// `<baseUrl>/api`). Semua data (daftar, detail, bab, halaman) dari API.

import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class LoneSealSource extends HttpSource {
  LoneSealSource({
    required this.id,
    required this.name,
    required String baseUrl,
    required this.lang,
    this.contentWarning = ContentWarning.safe,
    this.urlLayout = 'SLUG',
    this.includeChapterTitle = false,
    this.apiOnBase = false,
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

  /// SLUG, LEGACY_COMIC, LEGACY_ROOT, LEGACY_SERIES (sama dengan enum Kotlin).
  final String urlLayout;
  final bool includeChapterTitle;

  /// API di `<baseUrl>/api` alih-alih subdomain `api.`.
  final bool apiOnBase;

  /// Domain level dua yang umum (mis. `my.id`), untuk menebak domain utama.
  static const _secondLevel = {
    'my.id',
    'co.id',
    'web.id',
    'or.id',
    'ac.id',
    'biz.id',
    'co.uk',
    'com.br',
    'com.tr',
    'com.vn'
  };

  String get apiUrl {
    if (apiOnBase) return '$baseUrl/api';
    final labels = baseUri.host.split('.');
    final lastTwo = labels.length >= 2 ? labels.sublist(labels.length - 2).join('.') : baseUri.host;
    final domain =
        _secondLevel.contains(lastTwo) && labels.length >= 3 ? labels.sublist(labels.length - 3).join('.') : lastTwo;
    return 'https://api.$domain/api';
  }

  String get _mangaPrefix => switch (urlLayout) {
        'LEGACY_COMIC' => '/comic/',
        'LEGACY_SERIES' => '/series/',
        _ => '/',
      };
  String get _chapterPrefix => urlLayout == 'LEGACY_SERIES' ? '/series/' : '/comic/';

  String mangaUrl(String slug) => '$baseUrl$_mangaPrefix$slug';
  String chapterUrl(String series, String chapter) => '$baseUrl$_chapterPrefix$series/chapter/$chapter';

  // ---------------------------------------------------------------- daftar

  Uri searchUrl(int page, Map<String, String> extra) => Uri.parse('$apiUrl/search').replace(queryParameters: {
        'type': 'COMIC',
        'limit': '20',
        'page': '$page',
        ...extra,
      });

  @override
  Future<MangaPage> popular(int page) => _search(page, {'sort': 'views', 'order': 'desc'});

  @override
  Future<MangaPage> latest(int page) async {
    final json = asMap(await fetchJson(Uri.parse('$apiUrl/comic/home-sections')
        .replace(queryParameters: {'sections': 'latest_comic_updates', 'updateLimit': '240'})));
    return MangaPage([
      for (final m in asList(json['latest_comic_updates']))
        if (asString(asMap(m)['series_slug']) case final slug?)
          SourceManga(
            url: mangaUrl(slug),
            title: clean(asString(asMap(m)['series_title'])),
            thumbnailUrl: asString(asMap(m)['poster_image_url']),
          ),
    ], hasNextPage: false);
  }

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) => _search(page, {
        if (query.trim().isNotEmpty) 'q': query.trim(),
        for (final key in const ['sort', 'order', 'status', 'genre', 'comic_type'])
          if (filters.single(key) case final v?) key: v,
      });

  Future<MangaPage> _search(int page, Map<String, String> extra) async =>
      parseSearch(asMap(await fetchJson(searchUrl(page, extra))), page);

  MangaPage parseSearch(JsonMap json, int page) => MangaPage([
        for (final m in asList(json['data']))
          if (asString(asMap(m)['slug']) case final slug?)
            SourceManga(
              url: mangaUrl(slug),
              title: clean(asString(asMap(m)['title'])),
              thumbnailUrl: asString(asMap(m)['poster_image_url']),
            ),
      ], hasNextPage: page < (asInt(json['total_pages']) ?? 0));

  @override
  Future<List<FilterDef>> filters() async => const [
        SelectFilterDef('sort', 'Urutkan', [
          FilterOption('Terbaru', 'latest'),
          FilterOption('Baru', 'new'),
          FilterOption('Paling dilihat', 'views'),
          FilterOption('Rating', 'rate'),
          FilterOption('Bookmark', 'bookmark'),
        ]),
        SelectFilterDef('status', 'Status', [
          FilterOption('Semua', ''),
          FilterOption('Berjalan', 'ONGOING'),
          FilterOption('Tamat', 'COMPLETED'),
          FilterOption('Hiatus', 'HIATUS'),
        ]),
        SelectFilterDef('comic_type', 'Tipe', [
          FilterOption('Semua', ''),
          FilterOption('Manga', 'MANGA'),
          FilterOption('Manhwa', 'MANHWA'),
          FilterOption('Manhua', 'MANHUA'),
        ]),
      ];

  // ---------------------------------------------------------------- detail

  static String _slug(String url) => Uri.parse(url).pathSegments.where((s) => s.isNotEmpty).last;

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final slug = _slug(mangaUrl);
    return parseDetails(asMap(await fetchJson(Uri.parse('$apiUrl/series/comic/$slug'))), mangaUrl);
  }

  SourceMangaDetails parseDetails(JsonMap d, String url) {
    final series = asString(d['slug']) ?? _slug(url);
    final synopsis = asString(d['synopsis']);
    return SourceMangaDetails(
      url: url,
      title: clean(asString(d['title'])).isEmpty ? 'Tanpa judul' : clean(asString(d['title'])),
      thumbnailUrl: asString(d['poster_image_url']),
      author: nonPlaceholder(asString(d['author_name'])),
      artist: nonPlaceholder(asString(d['artist_name'])),
      description: synopsis == null || stripTags(synopsis).isEmpty ? null : stripTags(synopsis),
      genres: <String>{
        if (asString(d['primary_genre']) case final g?) g,
        for (final g in asList(d['genres']))
          if (asString(asMap(g)['name']) case final n?) n,
      }.toList(),
      status: switch (asString(d['comic_status'])?.toLowerCase()) {
        'ongoing' => SourceMangaStatus.ongoing,
        'completed' => SourceMangaStatus.completed,
        'hiatus' => SourceMangaStatus.hiatus,
        _ => SourceMangaStatus.unknown,
      },
      chapters: [
        for (final u in asList(d['units']))
          if (asString(asMap(u)['slug']) case final cs?) _chapter(asMap(u), series, cs),
      ],
    );
  }

  SourceChapter _chapter(JsonMap u, String series, String chapterSlug) {
    final number = asString(u['number']) ?? '${u['number'] ?? ''}';
    final title = asString(u['title']);
    final shown = number.replaceFirst(RegExp(r'\.0+$'), '');
    return SourceChapter(
      url: chapterUrl(series, chapterSlug),
      name: 'Chapter $shown${includeChapterTitle && title != null && title.isNotEmpty ? ' - $title' : ''}',
      number: double.tryParse(number),
      uploadedAt: DateTime.tryParse(asString(u['created_at']) ?? '')?.toLocal(),
    );
  }

  /// HTML sinopsis → teks dengan paragraf.
  static String stripTags(String html) => html
      .replaceAll(RegExp(r'<br\s*/?>|</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp('<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .join('\n\n');

  // ------------------------------------------------------------- halaman

  static final _bloggerQuery = RegExp(r'=[swh]\d+[^/?#]*(\?|$)');
  static final _bloggerPath = RegExp(r'/[swh]\d+(-[a-z0-9-]+)?/');

  /// Gambar Blogger dalam resolusi penuh (`=s0`).
  static String fullResolution(String url) {
    if (!url.contains('googleusercontent.com') && !url.contains('bp.blogspot.com')) return url;
    return url.replaceFirstMapped(_bloggerQuery, (m) => '=s0${m[1]}').replaceFirst(_bloggerPath, '/s0/');
  }

  /// Gambar iklan/promo AinzScans (nama file 999.jpg, 997.jpg, 00.0.jpg, …).
  static final _adFile = RegExp(r'^(999|997|995)(-\d+)?\.jpe?g$|^00\.[01]\.jpg$');

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final segs = Uri.parse(chapter.url).pathSegments.where((s) => s.isNotEmpty).toList();
    final i = segs.indexOf('chapter');
    if (i < 1 || i + 1 >= segs.length) {
      throw const SourceException(SourceErrorKind.parse, detail: 'URL bab tidak valid.');
    }
    final json = asMap(await fetchJson(Uri.parse('$apiUrl/series/comic/${segs[i - 1]}/chapter/${segs[i + 1]}')));
    final ch = asMap(json['chapter']);
    final pages = [
      for (final p in asList(ch['pages']))
        if (asString(asMap(p)['image_url']) case final raw?)
          fullResolution(raw.startsWith('http') ? raw : '${Uri.parse(apiUrl).origin}$raw'),
    ].where((u) => !_adFile.hasMatch(Uri.tryParse(u)?.pathSegments.lastOrNull ?? '')).toList();
    if (pages.isEmpty) {
      if (ch['password_required'] == true) {
        throw const SourceException(SourceErrorKind.parse, detail: 'Bab ini dikunci password di situsnya.');
      }
      if (ch['login_required'] == true) {
        throw const SourceException(SourceErrorKind.parse, detail: 'Bab ini perlu login di situsnya.');
      }
      throw const SourceException(SourceErrorKind.parse, detail: 'Gambar bab tidak ditemukan.');
    }
    return pages;
  }
}
