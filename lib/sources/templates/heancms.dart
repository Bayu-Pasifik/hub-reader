// Port Dart dari template HeanCms milik keiyoushi/extensions-source
// (Apache-2.0): lib-multisrc/heancms.
//
// API JSON di `https://api.<domain>`: `/query` (daftar & pencarian), `/series/<slug>`
// (detail), `/chapter/query` (bab per series_id), `/chapter/<seri>/<bab>` (gambar).
// Bab berbayar dan login tidak didukung: hanya bab gratis yang ditampilkan.

import 'package:html/parser.dart' as html_parser;

import '../../core/i18n/strings.dart';
import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class HeanCmsSource extends HttpSource {
  HeanCmsSource({
    required this.id,
    required this.name,
    required String baseUrl,
    required this.lang,
    this.contentWarning = ContentWarning.safe,
    this.vals = const {},
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

  final JsonMap vals;

  String get apiUrl => baseUrl.replaceFirst('://', '://api.');
  String get coverPath => asString(vals['coverPath']) ?? '';
  String get cdnUrl => apiUrl;
  String get mangaSubDirectory => asString(vals['mangaSubDirectory']) ?? 'series';
  String get latestSortBy => asString(vals['latestSortBy']) ?? 'desc';
  bool get fetchBadge => vals['fetchBadge'] == true;

  /// Satu request per detik ke API (situs ini membatasi laju).
  @override
  int get requestsPerSecond => 1;

  // =========================== Daftar ===========================

  @override
  Future<MangaPage> popular(int page) =>
      _query(page: page, query: '', status: 'All', order: 'desc', orderBy: 'total_views', tagIds: '[]');

  @override
  Future<MangaPage> latest(int page) =>
      _query(page: page, query: '', status: 'All', order: latestSortBy, orderBy: 'latest', tagIds: '[]');

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) {
    final genres = filters.multi('genres');
    return _query(
      page: page,
      query: query.trim(),
      status: filters.single('status') ?? 'All',
      order: filters.single('order') ?? 'desc',
      orderBy: filters.single('orderBy') ?? 'total_views',
      tagIds: '[${genres.join(',')}]',
    );
  }

  Uri _queryUrl({
    required int page,
    required String query,
    required String status,
    required String order,
    required String orderBy,
    required String tagIds,
  }) =>
      Uri.parse('$apiUrl/query').replace(queryParameters: {
        'query_string': query,
        'status': status,
        'order': order,
        'orderBy': orderBy,
        'series_type': 'Comic',
        'page': '$page',
        'perPage': '12',
        'tags_ids': tagIds,
        'adult': 'true',
      });

  Future<MangaPage> _query({
    required int page,
    required String query,
    required String status,
    required String order,
    required String orderBy,
    required String tagIds,
  }) async {
    final json = asMap(await fetchJson(
        _queryUrl(page: page, query: query, status: status, order: order, orderBy: orderBy, tagIds: tagIds)));
    return parseList(json);
  }

  MangaPage parseList(JsonMap json) {
    final items = <SourceManga>[];
    for (final raw in asList(json['data'])) {
      final s = asMap(raw);
      final slug = asString(s['series_slug']);
      final title = clean(asString(s['title']));
      if (slug == null || title.isEmpty) continue;
      items.add(SourceManga(
        url: '$baseUrl/$mangaSubDirectory/$slug',
        title: title,
        thumbnailUrl: _thumb(asString(s['thumbnail'])),
      ));
    }
    return MangaPage(items, hasNextPage: _hasNext(asMap(json['meta'])));
  }

  static bool _hasNext(JsonMap meta) => (asInt(meta['current_page']) ?? 1) < (asInt(meta['last_page']) ?? 1);

  String? _thumb(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return raw.startsWith('http://') || raw.startsWith('https://') ? raw : '$cdnUrl/$coverPath$raw';
  }

  // =========================== Filter ===========================

  @override
  Future<List<FilterDef>> filters() async {
    final genres = await fetchJson(Uri.parse('$apiUrl/tags'))
        .then((json) => [
              for (final g in asList(json))
                if (asInt(asMap(g)['id']) case final id?) FilterOption(clean(asString(asMap(g)['name'])), '$id'),
            ])
        .catchError((Object _) => const <FilterOption>[]);
    return [
      const SelectFilterDef('status', 'Status', [
        FilterOption('All', 'All'),
        FilterOption('Ongoing', 'Ongoing'),
        FilterOption('On hiatus', 'Hiatus'),
        FilterOption('Dropped', 'Dropped'),
        FilterOption('Completed', 'Completed'),
      ]),
      const SelectFilterDef('orderBy', 'Sort By', [
        FilterOption('Views', 'total_views'),
        FilterOption('Latest', 'latest'),
        FilterOption('Created at', 'created_at'),
        FilterOption('Title', 'title'),
      ]),
      const SelectFilterDef('order', 'Direction', [
        FilterOption('Descending', 'desc'),
        FilterOption('Ascending', 'asc'),
      ]),
      if (genres.isNotEmpty) MultiSelectFilterDef('genres', 'Genres', genres),
    ];
  }

  // =========================== Detail ===========================

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final slug = Uri.parse(mangaUrl).pathSegments.where((s) => s.isNotEmpty).lastOrNull;
    if (slug == null) throw SourceException(SourceErrorKind.parse, detail: tr('URL seri tidak dikenali.'));
    final series = asMap(await fetchJson(Uri.parse('$apiUrl/series/$slug')));
    final seriesId = asInt(series['id']);
    if (seriesId == null) throw SourceException(SourceErrorKind.parse, detail: tr('Detail seri tidak ditemukan.'));

    var format = _format(series);
    if (fetchBadge) {
      // Endpoint series tidak punya badge: cari di daftar.
      try {
        final found = parseBadge(
          asMap(await fetchJson(_queryUrl(
              page: 1,
              query: clean(asString(series['title'])),
              status: 'All',
              order: 'desc',
              orderBy: 'total_views',
              tagIds: '[]'))),
          seriesId,
        );
        if (found != null) format = found;
      } catch (_) {
        // Pakai format bawaan.
      }
    }

    final chapters = <SourceChapter>[];
    var page = 1;
    var more = true;
    while (more) {
      final json = asMap(await fetchJson(Uri.parse('$apiUrl/chapter/query').replace(queryParameters: {
        'page': '$page',
        'perPage': '1000',
        'series_id': '$seriesId',
      })));
      chapters.addAll(parseChapters(asList(json['data']), slug));
      more = _hasNext(asMap(json['meta']));
      page++;
    }
    return parseDetails(series, chapters, format, mangaUrl);
  }

  /// Teks badge bebas ("DOUJINSHI", "Doujinhsi"): petakan ke format.
  static String _format(JsonMap series) {
    final badge = (asString(series['badge']) ?? '').trim().toLowerCase();
    if (badge.startsWith('douj')) return 'Doujinshi';
    if (badge == 'manga') return 'Manga';
    return 'Manhwa';
  }

  static String? parseBadge(JsonMap result, int seriesId) {
    for (final raw in asList(result['data'])) {
      final s = asMap(raw);
      if (asInt(s['id']) == seriesId) return _format(s);
    }
    return null;
  }

  static SourceMangaStatus _status(String? raw) => switch (raw) {
        'Ongoing' => SourceMangaStatus.ongoing,
        'Hiatus' => SourceMangaStatus.hiatus,
        'Dropped' => SourceMangaStatus.cancelled,
        'Completed' || 'Finished' => SourceMangaStatus.completed,
        _ => SourceMangaStatus.unknown,
      };

  static String? _credit(String? raw) {
    final v = (raw ?? '').trim();
    return v.isEmpty || v == '-' ? null : v;
  }

  SourceMangaDetails parseDetails(JsonMap s, List<SourceChapter> chapters, String format, String mangaUrl) {
    final title = clean(asString(s['title']));
    final body = html_parser.parseFragment(asString(s['description']) ?? '');
    var text = body.querySelectorAll('p').map((p) => p.text.trim()).where((t) => t.isNotEmpty).join('\n\n');
    if (text.isEmpty) text = body.text?.trim().replaceAll('\n', '\n\n') ?? '';
    if (text == '-') text = '';

    final rating = asDouble(s['rating']);
    final ratingsCount = asInt(s['ratings_count']);
    final year = asString(s['release_year'])?.trim();
    final info = [
      if (rating != null) 'Rating: ${rating.toStringAsFixed(2)}${ratingsCount == null ? '' : ' ($ratingsCount ratings)'}',
      if (year != null && year.isNotEmpty) 'Released: $year',
    ];
    final alt = [
      for (final n in (asString(s['alternative_names']) ?? '').split('|'))
        if (n.trim().isNotEmpty && n.trim() != title) n.trim(),
    ];
    final description = [
      if (text.isNotEmpty) text,
      if (info.isNotEmpty) info.join('\n'),
      if (alt.isNotEmpty) 'Alternative names:\n${alt.map((a) => '- $a').join('\n')}',
    ].join('\n\n');

    final tags = [
      for (final t in asList(s['tags']))
        if (clean(asString(asMap(t)['name'])) case final n when n.isNotEmpty) n,
    ]..sort();

    return SourceMangaDetails(
      url: mangaUrl,
      title: title,
      thumbnailUrl: _thumb(asString(s['thumbnail'])),
      author: _credit(asString(s['author'])),
      artist: _credit(asString(s['studio'])),
      description: description.isEmpty ? null : description,
      genres: [...tags, format],
      status: _status(asString(s['status'])),
      chapters: chapters,
    );
  }

  List<SourceChapter> parseChapters(List<Object?> raw, String seriesSlug, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final out = <SourceChapter>[];
    for (final r in raw) {
      final c = asMap(r);
      if ((asInt(c['price']) ?? 0) != 0) continue; // berbayar
      final chapterSlug = asString(c['chapter_slug']);
      final chapterId = asInt(c['id']);
      final base = clean(asString(c['chapter_name']));
      if (chapterSlug == null || chapterId == null || base.isEmpty) continue;
      final title = clean(asString(c['chapter_title']));
      final date = DateTime.tryParse(asString(c['created_at']) ?? '')?.toLocal();
      if (date != null && date.isAfter(current)) continue; // belum tayang
      final name = title.isEmpty ? base : '$base - $title';
      out.add(SourceChapter(
        url: '$baseUrl/$mangaSubDirectory/$seriesSlug/$chapterSlug#$chapterId',
        name: name,
        number: parseChapterNumber(base),
        uploadedAt: date,
      ));
    }
    return out;
  }

  // =========================== Halaman ===========================

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final url = Uri.parse(chapter.url);
    final segs = url.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.length < 3) throw SourceException(SourceErrorKind.parse, detail: tr('Muat ulang daftar bab.'));
    final json = asMap(await fetchJson(Uri.parse('$apiUrl/chapter/${segs[1]}/${segs[2]}')));
    return parsePages(json);
  }

  List<String> parsePages(JsonMap json) {
    final data = asMap(asMap(json['chapter'])['chapter_data']);
    final images = asList(data['images']);
    if (images.isEmpty) {
      throw SourceException(SourceErrorKind.parse,
          detail: json['paywall'] == true ? tr('Bab berbayar.') : tr('Gambar bab tidak ditemukan.'));
    }
    return [
      for (final i in images)
        if (asString(i) case final img?)
          img.startsWith('http://') || img.startsWith('https://') ? img : '$cdnUrl/$coverPath$img',
    ];
  }
}
