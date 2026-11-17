// Port Dart dari template Hiper milik keiyoushi/extensions-source
// (Apache-2.0): lib-multisrc/hiper.
//
// Situs dengan API tRPC `<situs>/api/trpc/<prosedur>?batch=1&input=<json>`: pencarian
// (`search.query`), detail (`series.bySlugWithGenres`), bab (`series.chapters`) dan gambar
// (`reader.chapterPages`). Tiap situs punya header kunci sendiri (mis. `x-cfg-auth`).
// Bila API menolak (401) cookie diambil dari beranda dulu. Pembersihan judul versi
// dan pengambilan header lewat WebView tidak dipakai.

import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/i18n/strings.dart';
import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class HiperSource extends HttpSource {
  HiperSource({
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
  final List<String> genreList;

  String get mangaPath => asString(vals['mangaPath']) ?? 'manga';

  @override
  int get requestsPerSecond => 3;

  @override
  Map<String, String> get extraHeaders => {
        'Accept': 'application/json',
        if (asString(vals['authHeader']) case final h? when h.isNotEmpty) h: asString(vals['authValue']) ?? '',
      };

  String _cookie = '';

  // =========================== tRPC ===========================

  Future<List<Object?>> _trpc(String procedures, Map<String, Object?> input) async {
    final url = Uri.parse('$baseUrl/api/trpc/$procedures')
        .replace(queryParameters: {'batch': '1', 'input': jsonEncode(input)});
    Future<Response<String>> get() => dio.getUri<String>(
          url,
          options: Options(headers: {if (_cookie.isNotEmpty) 'Cookie': _cookie}, validateStatus: (_) => true),
        );
    try {
      var res = await get();
      if (res.statusCode == 401) {
        // Beranda memberi cookie yang dibutuhkan API.
        final home = await dio.getUri<String>(
          Uri.parse('$baseUrl/'),
          options: Options(
              headers: {'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'},
              validateStatus: (_) => true),
        );
        final cookies = home.headers['set-cookie'] ?? const [];
        _cookie = cookies.map((c) => c.split(';').first).join('; ');
        res = await get();
      }
      final code = res.statusCode ?? 0;
      if (code < 200 || code >= 300) {
        throw DioException.badResponse(statusCode: code, requestOptions: res.requestOptions, response: res);
      }
      return asList(jsonDecode(res.data ?? '[]'));
    } on SourceException {
      rethrow;
    } on FormatException {
      throw SourceException(SourceErrorKind.parse, detail: tr('Respons API bukan JSON.'));
    } catch (error) {
      throw toSourceException(error);
    }
  }

  static Object? _json(Object? element) => asMap(asMap(asMap(element)['result'])['data'])['json'];

  static Map<String, Object?> _undefinedMeta(List<String> keys) => {
        'values': {for (final k in keys) k: ['undefined']},
      };

  // =========================== Daftar ===========================

  @override
  Future<MangaPage> popular(int page) => _search(page, '', sort: 'popular');

  @override
  Future<MangaPage> latest(int page) => _search(page, '', sort: 'recent');

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) => _search(
        page,
        query.trim(),
        sort: filters.single('sort') ?? 'relevance',
        type: filters.single('type'),
        status: filters.single('status'),
        rating: filters.single('rating'),
        genres: filters.multi('genres'),
      );

  Future<MangaPage> _search(
    int page,
    String query, {
    required String sort,
    String? type,
    String? status,
    String? rating,
    List<String> genres = const [],
  }) async {
    const limit = 30;
    final undefined = [
      if (genres.isEmpty) 'filters.genres',
      if (type == null) 'filters.type',
      if (status == null) 'filters.status',
      if (rating == null) 'filters.contentRating',
      'filters.author',
      'filters.artist',
      'filters.year',
    ];
    final result = await _trpc('search.query', {
      '0': {
        'json': {
          'q': query,
          'sort': sort,
          'filters': {
            'genres': genres.isEmpty ? null : genres,
            'type': type,
            'status': status,
            'contentRating': rating,
            'author': null,
            'artist': null,
            'year': null,
          },
          'limit': limit,
          'offset': (page - 1) * limit,
          'maxRating': asString(vals['maxRating']) ?? 'pornographic',
        },
        'meta': _undefinedMeta(undefined),
      },
    });
    return parseSearch(result.isEmpty ? null : _json(result.first));
  }

  MangaPage parseSearch(Object? json) {
    final hits = asList(asMap(json)['hits']);
    final items = <SourceManga>[];
    for (final raw in hits) {
      final m = asMap(raw);
      final slug = asString(m['slug']);
      final id = asInt(m['id']);
      final title = clean(asString(m['title']));
      if (slug == null || id == null || title.isEmpty) continue;
      items.add(SourceManga(url: '$baseUrl/$mangaPath/$slug#$id', title: title, thumbnailUrl: asString(m['coverUrl'])));
    }
    return MangaPage(items, hasNextPage: hits.isNotEmpty);
  }

  // =========================== Filter ===========================

  @override
  Future<List<FilterDef>> filters() async => [
        const SelectFilterDef('sort', 'Sort', [
          FilterOption('Relevance', 'relevance'),
          FilterOption('Popular', 'popular'),
          FilterOption('Score', 'score'),
          FilterOption('Recent', 'recent'),
          FilterOption('Newest', 'newest'),
          FilterOption('Oldest', 'oldest'),
          FilterOption('A-Z', 'alphabetical'),
        ]),
        const SelectFilterDef('rating', 'Content rating', [
          FilterOption('All', ''),
          FilterOption('Pornographic', 'pornographic'),
          FilterOption('Erotica', 'erotica'),
          FilterOption('Suggestive', 'suggestive'),
          FilterOption('Safe', 'safe'),
        ]),
        const SelectFilterDef('type', 'Type', [
          FilterOption('All', ''),
          FilterOption('Manga', 'manga'),
          FilterOption('Manhwa', 'manhwa'),
          FilterOption('Manhua', 'manhua'),
          FilterOption('Webtoon', 'webtoon'),
          FilterOption('One Shot', 'one_shot'),
        ]),
        const SelectFilterDef('status', 'Status', [
          FilterOption('All', ''),
          FilterOption('Ongoing', 'ongoing'),
          FilterOption('Completed', 'completed'),
          FilterOption('On hiatus', 'hiatus'),
          FilterOption('Cancelled', 'cancelled'),
        ]),
        if (genreList.isNotEmpty)
          MultiSelectFilterDef('genres', 'Genres', [for (final g in genreList) FilterOption(g, g)]),
      ];

  // =========================== Detail ===========================

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final uri = Uri.parse(mangaUrl);
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final slug = segs.length >= 2 && segs.first == mangaPath ? segs[1] : null;
    if (slug == null) throw SourceException(SourceErrorKind.parse, detail: tr('URL seri tidak dikenali.'));

    final detail = await _trpc('auth.me,series.bySlugWithGenres', {
      '0': {'json': null, 'meta': {'values': ['undefined']}},
      '1': {'json': {'slug': slug}},
    });
    final manga = asMap(_json(detail.last));
    final seriesId = asInt(manga['id']);
    if (seriesId == null) throw SourceException(SourceErrorKind.parse, detail: tr('Detail seri tidak ditemukan.'));

    final chapterResult = await _trpc('auth.me,series.chapters', {
      '0': {'json': {'values': ['undefined']}},
      '1': {
        'json': {'seriesId': seriesId, 'chapterId': null, 'sort': 'best', 'page': 1, 'limit': 20},
        'meta': {'values': {'chapterId': ['undefined']}},
      },
      '2': {'json': {'seriesId': seriesId}},
    });
    return parseDetails(manga, asList(_json(chapterResult.last)), slug);
  }

  static String _join(Object? list) => [
        for (final e in asList(list))
          if (asString(e) case final s? when s.trim().isNotEmpty) s,
      ].join(', ');

  SourceMangaDetails parseDetails(JsonMap m, List<Object?> rawChapters, String slug) {
    final id = asInt(m['id']);
    final genres = [
      for (final g in asList(m['genres']))
        if (asString(g) case final s? when s.isNotEmpty) s,
      if (asString(m['type']) case final t? when t.isNotEmpty) t,
      if (asString(m['contentRating']) case final r? when r.isNotEmpty) r,
    ];
    final chapters = <SourceChapter>[];
    for (final raw in rawChapters) {
      final c = asMap(raw);
      final cid = asInt(c['id']);
      final number = asDouble(c['number']);
      if (cid == null || number == null) continue;
      final numText = number == number.truncateToDouble() ? '${number.toInt()}' : '$number';
      final title = asString(c['title']);
      final hasNumber = title != null &&
          RegExp(r'\d+(?:\.\d+)?').allMatches(title).any((x) => double.tryParse(x.group(0)!) == number);
      chapters.add(SourceChapter(
        url: '$baseUrl/$mangaPath/$slug/$numText#$cid',
        name: title == null || title.trim().isEmpty ? 'Chapter $numText' : (hasNumber ? title : 'Chapter $numText $title'),
        number: number,
        uploadedAt: DateTime.tryParse(asString(c['createdAt']) ?? '')?.toLocal(),
      ));
    }
    final author = _join(m['authors']);
    final artist = _join(m['artists']);
    return SourceMangaDetails(
      url: '$baseUrl/$mangaPath/$slug#$id',
      title: clean(asString(m['title'])),
      thumbnailUrl: asString(m['coverUrl']),
      author: author.isEmpty ? null : author,
      artist: artist.isEmpty ? null : artist,
      description: asString(m['synopsis']),
      genres: genres,
      status: switch ((asString(m['status']) ?? '').toLowerCase()) {
        'ongoing' => SourceMangaStatus.ongoing,
        'hiatus' => SourceMangaStatus.hiatus,
        'cancelled' => SourceMangaStatus.cancelled,
        'completed' => SourceMangaStatus.completed,
        _ => SourceMangaStatus.unknown,
      },
      chapters: chapters,
    );
  }

  // =========================== Halaman ===========================

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final uri = Uri.parse(chapter.url);
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.length < 3) throw SourceException(SourceErrorKind.parse, detail: tr('Muat ulang daftar bab.'));
    final chapterId = int.tryParse(uri.fragment);
    final result = await _trpc('auth.me,series.bySlug,reader.chapterPages', {
      '0': {'json': null, 'meta': {'values': ['undefined']}},
      '1': {'json': {'slug': segs[1]}},
      '2': {
        'json': {'seriesSlug': segs[1], 'chapterNumber': double.tryParse(segs[2]) ?? segs[2], if (chapterId != null) 'chapterId': chapterId},
      },
      '3': {'json': {'position': 'footer_bottom'}},
    });
    return parsePages(result);
  }

  List<String> parsePages(List<Object?> result) {
    for (final e in result) {
      if (asMap(e).containsKey('error')) {
        throw SourceException(SourceErrorKind.parse, detail: tr('Situs menolak permintaan; buka bab di WebView.'));
      }
    }
    final pages = [
      for (final p in asList(_json(result.last)))
        if ((asString(asMap(p)['avifUrl']) ?? asString(asMap(p)['webpUrl'])) case final url?) (asInt(asMap(p)['pageOrder']) ?? 0, url),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    if (pages.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    return [for (final (_, url) in pages) url];
  }
}
