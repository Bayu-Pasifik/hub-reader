// Port Dart dari extension Asura Scans milik keiyoushi/extensions-source
// (Apache-2.0): src/en/asurascans. Seluruh data lewat API JSON
// (api.asurascans.com), jadi tidak bergantung pada halaman situs yang dijaga
// Cloudflare. Bab berbayar/akses awal disembunyikan.

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';
import '../../core/i18n/strings.dart';

class AsuraScansSource extends HttpSource {
  AsuraScansSource({super.dio});

  @override
  String get id => 'en.asurascans';
  @override
  String get name => 'Asura Scans';
  @override
  String get lang => 'en';
  @override
  String get defaultBaseUrl => 'https://asurascans.com';
  @override
  ContentWarning get contentWarning => ContentWarning.mixed;

  static const apiUrl = 'https://api.asurascans.com/api';
  static const perPage = 20;

  /// Akhiran acak pada slug situs (`overgeared-7ba78ec7`), tak ada di API.
  static final _randomPart = RegExp(r'-[0-9a-f]{8}$');

  static const _apiHeaders = {'Accept': 'application/json'};

  Future<Map<String, Object?>> _get(String path, [Map<String, String> query = const {}]) async {
    final json = await fetchJson(
      Uri.parse('$apiUrl/$path').replace(queryParameters: query.isEmpty ? null : query),
      headers: _apiHeaders,
    );
    if (json is Map<String, Object?>) return json;
    throw SourceException(SourceErrorKind.parse, detail: tr('Respons API bukan JSON.'));
  }

  @override
  Future<MangaPage> popular(int page) => _list(page, '', {'sort': 'popular', 'order': 'desc'});

  @override
  Future<MangaPage> latest(int page) => _list(page, '', {'sort': 'latest', 'order': 'desc'});

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) => _list(page, query, {
        'sort': filters.single('sort') ?? 'latest',
        'order': filters.single('order') ?? 'desc',
        if (filters.single('status') case final v?) 'status': v,
        if (filters.single('type') case final v?) 'type': v,
        if (filters.multi('genres').isNotEmpty) 'genres': filters.multi('genres').join(','),
      });

  Future<MangaPage> _list(int page, String query, Map<String, String> params) async {
    final json = await _get('series', {
      'offset': '${(page - 1) * perPage}',
      'limit': '$perPage',
      if (query.trim().isNotEmpty) 'search': query.trim(),
      ...params,
    });
    return parseList(json);
  }

  MangaPage parseList(Map<String, Object?> json) {
    final items = <SourceManga>[];
    for (final e in (json['data'] as List? ?? const [])) {
      if (e is! Map) continue;
      final publicUrl = e['public_url'];
      final title = e['title'];
      if (publicUrl is! String || title is! String) continue;
      items.add(SourceManga(
        url: '$baseUrl$publicUrl',
        title: title,
        thumbnailUrl: (e['cover'] ?? e['cover_url'] ?? e['coverUrl']) as String?,
      ));
    }
    final more = (json['meta'] as Map?)?['has_more'];
    return MangaPage(items, hasNextPage: more == true);
  }

  List<FilterOption>? _genreCache;

  @override
  Future<List<FilterDef>> filters() async {
    if (_genreCache == null) {
      try {
        final json = await _get('genres');
        _genreCache = [
          for (final g in (json['data'] as List? ?? const []))
            if (g is Map && g['name'] != null && g['slug'] != null) FilterOption('${g['name']}', '${g['slug']}'),
        ];
      } on SourceException {
        _genreCache = const [];
      }
    }
    return [
      const SelectFilterDef('sort', 'Sort By', [
        FilterOption('Latest Update', 'latest'),
        FilterOption('Popular', 'popular'),
        FilterOption('Rating', 'rating'),
        FilterOption('A-Z', 'title'),
        FilterOption('Newest', 'update'),
      ]),
      const SelectFilterDef('order', 'Order', [
        FilterOption('Descending', 'desc'),
        FilterOption('Ascending', 'asc'),
      ]),
      const SelectFilterDef('status', 'Status', [
        FilterOption('All', ''),
        FilterOption('Ongoing', 'ongoing'),
        FilterOption('Completed', 'completed'),
        FilterOption('Hiatus', 'hiatus'),
        FilterOption('Dropped', 'dropped'),
        FilterOption('Axed', 'axed'),
      ]),
      const SelectFilterDef('type', 'Type', [
        FilterOption('All', ''),
        FilterOption('Manhwa', 'manhwa'),
        FilterOption('Manhua', 'manhua'),
        FilterOption('Mangatoon', 'manga'),
      ]),
      if (_genreCache!.isNotEmpty) MultiSelectFilterDef('genres', 'Genres', _genreCache!),
    ];
  }

  /// `https://asurascans.com/comics/<slug>-<acak>` -> `<slug>`.
  static String _apiSlug(String mangaUrl) {
    final segs = Uri.parse(mangaUrl).pathSegments.where((s) => s.isNotEmpty).toList();
    final last = segs.isEmpty ? '' : segs[segs.length > 1 && segs[0] == 'comics' ? 1 : segs.length - 1];
    return last.replaceFirst(_randomPart, '');
  }

  static String _numberLabel(num n) => '$n'.replaceFirst(RegExp(r'\.0$'), '');

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final slug = _apiSlug(mangaUrl);
    final seriesJson = await _get('series/$slug');
    final chaptersJson = await _get('series/$slug/chapters');
    return parseDetails(seriesJson, chaptersJson, mangaUrl);
  }

  SourceMangaDetails parseDetails(Map<String, Object?> seriesJson, Map<String, Object?> chaptersJson, String mangaUrl) {
    final s = (seriesJson['series'] as Map?)?.cast<String, Object?>();
    if (s == null || s['title'] == null) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Judul tidak ditemukan.'));
    }
    final publicUrl = s['public_url'] as String? ?? Uri.parse(mangaUrl).path;
    final publicSlug = Uri.parse(publicUrl).pathSegments.where((p) => p.isNotEmpty).last;

    final meta = <String>[
      if (s['popularity_rank'] is num) 'Rank: #${s['popularity_rank']}',
      if (s['rating'] is num) 'Rating: ${(s['rating'] as num).toStringAsFixed(2)}',
      if (s['bookmark_count'] is num) 'Bookmarks: ${_compact((s['bookmark_count'] as num).toInt())}',
    ];
    final body = clean(_stripTags('${s['description'] ?? ''}'));
    final altRaw = '${s['alternative_titles'] ?? ''}';
    final alts = [
      for (final a in (altRaw.contains('•') ? altRaw.split('•') : altRaw.split(','))) clean(a),
    ]..removeWhere((a) => a.isEmpty);
    final description = [
      if (meta.isNotEmpty) meta.join(' • '),
      if (body.isNotEmpty) body,
      if (alts.isNotEmpty) 'Alternative Titles:\n${alts.map((a) => '- $a').join('\n')}',
    ].join('\n\n');

    final type = '${s['type'] ?? ''}';
    final now = DateTime.now();
    final chapters = <SourceChapter>[];
    for (final c in (chaptersJson['data'] as List? ?? const [])) {
      if (c is! Map || c['number'] is! num) continue;
      final until = DateTime.tryParse('${c['early_access_until'] ?? ''}');
      final locked = c['is_premium'] == true || (until != null && until.isAfter(now));
      if (locked) continue;
      final n = c['number'] as num;
      final title = clean('${c['title'] ?? ''}');
      chapters.add(SourceChapter(
        url: '$baseUrl/comics/$publicSlug/chapter/${_numberLabel(n)}',
        name: 'Chapter ${_numberLabel(n)}${title.isEmpty || title == 'null' ? '' : ' - $title'}',
        number: n.toDouble(),
        uploadedAt: DateTime.tryParse('${c['published_at'] ?? c['created_at'] ?? ''}')?.toLocal(),
      ));
    }

    return SourceMangaDetails(
      url: '$baseUrl$publicUrl',
      title: '${s['title']}',
      author: nonPlaceholder('${s['author'] ?? ''}'),
      artist: nonPlaceholder('${s['artist'] ?? ''}'),
      description: description.isEmpty ? null : description,
      thumbnailUrl: (s['cover'] ?? s['cover_url']) as String?,
      status: switch ('${s['status']}'.toLowerCase()) {
        'ongoing' => SourceMangaStatus.ongoing,
        'completed' => SourceMangaStatus.completed,
        'hiatus' => SourceMangaStatus.hiatus,
        'dropped' || 'axed' => SourceMangaStatus.cancelled,
        _ => SourceMangaStatus.unknown,
      },
      genres: [
        if (type.isNotEmpty) type[0].toUpperCase() + type.substring(1),
        for (final g in (s['genres'] as List? ?? const []))
          if (g is Map && g['name'] != null) '${g['name']}',
      ],
      chapters: chapters,
    );
  }

  static String _compact(int n) => n >= 1000000
      ? '${(n / 1000000).toStringAsFixed(1)}M'
      : n >= 1000
          ? '${(n / 1000).toStringAsFixed(1)}K'
          : '$n';

  static String _stripTags(String html) => html.replaceAll(RegExp(r'<[^>]*>'), ' ');

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final segs = Uri.parse(chapter.url).pathSegments.where((s) => s.isNotEmpty).toList();
    final i = segs.indexOf('chapter');
    if (i < 1 || i + 1 >= segs.length) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    }
    final slug = segs[i - 1].replaceFirst(_randomPart, '');
    final json = await _get('series/$slug/chapters/${segs[i + 1]}');
    return parsePages(json);
  }

  List<String> parsePages(Map<String, Object?> json) {
    final pages = (((json['data'] as Map?)?['chapter'] as Map?)?['pages'] as List?) ?? const [];
    final urls = <String>[];
    for (final p in pages) {
      if (p is! Map || p['url'] is! String) continue;
      // Ubin acak (anti-salin) belum didukung; bab itu tak bisa dibaca benar.
      if (p['tiles'] is List && (p['tiles'] as List).isNotEmpty) {
        throw SourceException(SourceErrorKind.parse, detail: tr('Bab ini memakai gambar teracak yang belum didukung.'));
      }
      urls.add(p['url'] as String);
    }
    if (urls.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    return urls;
  }
}
