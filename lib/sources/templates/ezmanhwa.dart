// Port Dart dari template EZManhwa milik keiyoushi/extensions-source
// (Apache-2.0): lib-multisrc/ezmanhwa.
//
// API JSON `<apiUrl>/series` (daftar), `/series/search?q=` (pencarian),
// `/series/<slug>` (detail), `/series/<slug>/chapters` (bab, berhalaman) dan
// `/series/<slug>/chapters/<bab>` (gambar). Bab yang butuh koin disembunyikan.

import 'package:html/parser.dart' as html_parser;

import '../../core/i18n/strings.dart';
import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class EZManhwaSource extends HttpSource {
  EZManhwaSource({
    required this.id,
    required this.name,
    required String baseUrl,
    required this.lang,
    this.contentWarning = ContentWarning.safe,
    this.vals = const {},
    this.genreList = const [],
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

  /// Genre per situs: (label, nilai).
  final List<(String, String)> genreList;

  String get apiUrl => (asString(vals['apiUrl']) ?? 'https://api.${baseUri.host}/api/v1').replaceAll(RegExp(r'/+$'), '');

  @override
  Map<String, String> get extraHeaders => const {'Accept': 'application/json, text/plain, */*'};

  // =========================== Daftar ===========================

  @override
  Future<MangaPage> popular(int page) => _list('$apiUrl/series', {'page': '$page', 'perPage': '20', 'sort': 'popular'});

  @override
  Future<MangaPage> latest(int page) => _list('$apiUrl/series', {'page': '$page', 'perPage': '20', 'sort': 'latest'});

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) {
    final q = query.trim();
    if (q.isNotEmpty) return _list('$apiUrl/series/search', {'page': '$page', 'perPage': '20', 'q': q});
    return _list('$apiUrl/series', {
      'page': '$page',
      'perPage': '20',
      'sort': filters.single('sort') ?? 'latest',
      for (final key in const ['status', 'type', 'genre'])
        if (filters.single(key) case final v? when v.isNotEmpty) key: v,
    });
  }

  Future<MangaPage> _list(String url, Map<String, String> params) async {
    final json = asMap(await fetchJson(Uri.parse(url).replace(queryParameters: params)));
    return parseList(json);
  }

  MangaPage parseList(JsonMap json) {
    final items = <SourceManga>[];
    for (final raw in asList(json['data'])) {
      final s = asMap(raw);
      if (asString(s['type']) == 'NOVEL') continue;
      final slug = asString(s['slug']);
      final title = clean(asString(s['title']));
      if (slug == null || title.isEmpty) continue;
      items.add(SourceManga(url: '$baseUrl/series/$slug', title: title, thumbnailUrl: asString(s['cover'])));
    }
    return MangaPage(items, hasNextPage: (asInt(json['current']) ?? 1) < (asInt(json['totalPages']) ?? 1));
  }

  // =========================== Filter ===========================

  @override
  Future<List<FilterDef>> filters() async => [
        const SelectFilterDef('sort', 'Sort', [
          FilterOption('Latest', 'latest'),
          FilterOption('Popular', 'popular'),
          FilterOption('Newest', 'newest'),
          FilterOption('Alphabetical', 'alphabetical'),
        ]),
        const SelectFilterDef('status', 'Status', [
          FilterOption('All', ''),
          FilterOption('Ongoing', 'ONGOING'),
          FilterOption('Completed', 'COMPLETED'),
          FilterOption('Hiatus', 'HIATUS'),
          FilterOption('Dropped', 'DROPPED'),
        ]),
        const SelectFilterDef('type', 'Type', [
          FilterOption('All', ''),
          FilterOption('Manga', 'MANGA'),
          FilterOption('Manhwa', 'MANHWA'),
          FilterOption('Manhua', 'MANHUA'),
        ]),
        if (genreList.isNotEmpty)
          SelectFilterDef('genre', 'Genre', [
            const FilterOption('All', ''),
            for (final (label, value) in genreList) FilterOption(label, value),
          ]),
      ];

  // =========================== Detail ===========================

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final slug = Uri.parse(mangaUrl).pathSegments.where((s) => s.isNotEmpty).lastOrNull;
    if (slug == null) throw SourceException(SourceErrorKind.parse, detail: tr('URL seri tidak dikenali.'));
    final series = asMap(await fetchJson(Uri.parse('$apiUrl/series/$slug')));

    final chapters = <SourceChapter>[];
    var page = 1;
    var total = 1;
    do {
      final json = asMap(await fetchJson(Uri.parse('$apiUrl/series/$slug/chapters')
          .replace(queryParameters: {'page': '$page', 'perPage': '100', 'sort': 'desc'})));
      total = asInt(json['totalPages']) ?? 1;
      chapters.addAll(parseChapters(asList(json['data']), slug));
      page++;
    } while (page <= total);
    return parseDetails(series, chapters, mangaUrl);
  }

  static SourceMangaStatus _status(String? raw) => switch (raw) {
        'ONGOING' || 'MASS_RELEASED' => SourceMangaStatus.ongoing,
        'COMPLETED' => SourceMangaStatus.completed,
        'DROPPED' => SourceMangaStatus.cancelled,
        'HIATUS' => SourceMangaStatus.hiatus,
        _ => SourceMangaStatus.unknown,
      };

  static String? _trimmed(String? raw) {
    final v = (raw ?? '').trim();
    return v.isEmpty ? null : v;
  }

  SourceMangaDetails parseDetails(JsonMap s, List<SourceChapter> chapters, String mangaUrl) {
    final desc = html_parser.parseFragment(asString(s['description']) ?? '').text?.trim() ?? '';
    final alt = _trimmed(asString(s['alternativeTitles']));
    final description = [if (desc.isNotEmpty) desc, if (alt != null) 'Alternative Titles: $alt'].join('\n\n');
    return SourceMangaDetails(
      url: mangaUrl,
      title: clean(asString(s['title'])),
      thumbnailUrl: asString(s['cover']),
      author: _trimmed(asString(s['author'])),
      artist: _trimmed(asString(s['artist'])),
      description: description.isEmpty ? null : description,
      genres: [
        for (final g in asList(s['genres']))
          if (clean(asString(asMap(g)['name'])) case final n when n.isNotEmpty) n,
      ],
      status: _status(asString(s['status'])),
      chapters: chapters,
    );
  }

  static final _prefix = RegExp(r'^(chapter|ch\.?|episode|ep\.?)\s*.*', caseSensitive: false);

  static String _numText(double n) => n == n.truncateToDouble() ? '${n.toInt()}' : '$n';

  List<SourceChapter> parseChapters(List<Object?> raw, String seriesSlug) {
    final out = <SourceChapter>[];
    for (final r in raw) {
      final c = asMap(r);
      if (c['requiresPurchase'] == true) continue;
      final slug = asString(c['slug']);
      if (slug == null) continue;
      final number = asDouble(c['number']);
      final numStr = number == null ? '' : _numText(number);
      final title = _trimmed(asString(c['title']));
      final name = numStr.isEmpty
          ? (title ?? 'Chapter')
          : title == null || title == numStr
              ? 'Chapter $numStr'
              : title.contains(numStr) && _prefix.hasMatch(title)
                  ? title
                  : title.startsWith('-') || title.startsWith(':')
                      ? 'Chapter $numStr $title'
                      : 'Chapter $numStr - $title';
      out.add(SourceChapter(
        url: '$baseUrl/series/$seriesSlug/$slug',
        name: name,
        number: number,
        uploadedAt: DateTime.tryParse(asString(c['becameFreeAt']) ?? asString(c['createdAt']) ?? '')?.toLocal(),
      ));
    }
    return out;
  }

  // =========================== Halaman ===========================

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final segs = Uri.parse(chapter.url).pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.length < 3) throw SourceException(SourceErrorKind.parse, detail: tr('Muat ulang daftar bab.'));
    final json = asMap(await fetchJson(Uri.parse('$apiUrl/series/${segs[1]}/chapters/${segs[2]}')));
    return parsePages(json);
  }

  List<String> parsePages(JsonMap json) {
    if (json['requiresPurchase'] == true) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Bab berbayar.'));
    }
    final images = [
      for (final i in asList(json['images']))
        if (asString(asMap(i)['url']) case final url?) url,
    ];
    if (images.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    return images;
  }
}
