// Port Dart dari template Iken milik keiyoushi/extensions-source
// (Apache-2.0): lib-multisrc/iken.
//
// Semua data dari API JSON di `https://api.<domain>/api/...`: query (daftar &
// pencarian), post (detail), chapters (daftar bab), chapter (gambar).
// Laporan jumlah tayangan (`analytics/updateViews`) sengaja tidak dikirim.

import 'package:html/parser.dart' as html_parser;

import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class IkenSource extends HttpSource {
  IkenSource({
    required this.id,
    required this.name,
    required String baseUrl,
    required this.lang,
    this.contentWarning = ContentWarning.safe,
    this.perPage = 18,
    this.sortPagesByFilename = false,
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

  final int perPage;

  /// Urutkan gambar dari angka di nama file, bukan dari field `order`.
  final bool sortPagesByFilename;

  String get apiUrl => baseUrl.replaceFirst('https://', 'https://api.');

  // =========================== Daftar ===========================

  @override
  Future<MangaPage> popular(int page) => search(page, '', filters: FilterValues.empty.withSingle('orderBy', 'totalViews'));

  @override
  Future<MangaPage> latest(int page) =>
      search(page, '', filters: FilterValues.empty.withSingle('orderBy', 'lastChapterAddedAt'));

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    final json = asMap(await fetchJson(Uri.parse('$apiUrl/api/query').replace(queryParameters: {
      'perPage': '$perPage',
      'searchTerm': query.trim(),
      for (final key in const ['seriesStatus', 'seriesType', 'orderBy', 'orderDirection'])
        if (filters.single(key) case final value?) key: value,
      if (filters.multi('genreIds').isNotEmpty) 'genreIds': filters.multi('genreIds').join(','),
      'page': '$page',
    })));
    return parseList(json, page);
  }

  static bool _isNovel(JsonMap post) =>
      post['isNovel'] == true || (asString(post['seriesType']) ?? '').toLowerCase() == 'novel';

  MangaPage parseList(JsonMap json, int page) => MangaPage(
        [
          for (final p in asList(json['posts']))
            if (_isNovel(asMap(p)) ? null : toManga(asMap(p)) case final manga?) manga,
        ],
        hasNextPage: (asInt(json['totalCount']) ?? 0) > page * perPage,
      );

  SourceManga? toManga(JsonMap post) {
    final slug = asString(post['slug']);
    final title = clean(asString(post['postTitle']));
    if (slug == null || title.isEmpty) return null;
    return SourceManga(url: '$baseUrl/series/$slug', title: title, thumbnailUrl: asString(post['featuredImage']));
  }

  // =========================== Filter ===========================

  @override
  Future<List<FilterDef>> filters() async {
    final genres = await fetchJson(Uri.parse('$apiUrl/api/genres'))
        .then((json) => [
              for (final g in asList(json))
                if (asInt(asMap(g)['id']) case final id?) FilterOption(clean(asString(asMap(g)['name'])), '$id'),
            ])
        .catchError((Object _) => const <FilterOption>[]);
    return [
      const SelectFilterDef('seriesStatus', 'Status', [
        FilterOption('All', ''),
        FilterOption('Ongoing', 'ONGOING'),
        FilterOption('Completed', 'COMPLETED'),
        FilterOption('Canceled', 'CANCELLED'),
        FilterOption('Dropped', 'DROPPED'),
        FilterOption('Coming Soon', 'COMING_SOON'),
        FilterOption('Mass Released', 'MASS_RELEASED'),
      ]),
      const SelectFilterDef('seriesType', 'Type', [
        FilterOption('All', ''),
        FilterOption('Manga', 'MANGA'),
        FilterOption('Manhua', 'MANHUA'),
        FilterOption('Manhwa', 'MANHWA'),
        FilterOption('Russian', 'RUSSIAN'),
        FilterOption('Spanish', 'SPANISH'),
      ]),
      const SelectFilterDef('orderBy', 'Sort by', [
        FilterOption('Last chapter', 'lastChapterAddedAt'),
        FilterOption('Views', 'totalViews'),
        FilterOption('Added date', 'createdAt'),
        FilterOption('Chapter count', 'chaptersCount'),
        FilterOption('Alphabetical', 'postTitle'),
      ]),
      const SelectFilterDef('orderDirection', 'Direction', [
        FilterOption('Descending', 'desc'),
        FilterOption('Ascending', 'asc'),
      ]),
      if (genres.isNotEmpty) MultiSelectFilterDef('genreIds', 'Genres', genres),
    ];
  }

  // =========================== Detail ===========================

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final segments = Uri.parse(mangaUrl).pathSegments.where((s) => s.isNotEmpty).toList();
    final slug = segments.length >= 2 ? segments[1] : segments.lastOrNull;
    if (slug == null) throw const SourceException(SourceErrorKind.parse, detail: 'URL seri tidak dikenali.');
    final json = asMap(await fetchJson(Uri.parse('$apiUrl/api/post').replace(queryParameters: {'postSlug': slug})));
    final post = asMap(json['post']);
    if (_isNovel(post)) throw const SourceException(SourceErrorKind.parse, detail: 'Novel tidak didukung.');

    // Daftar bab di `post` sering kosong; endpoint chapters berisi semuanya.
    var chapters = asList(post['chapters']);
    final postId = asInt(post['id']);
    if (postId != null && (asInt(json['totalChapterCount']) ?? 0) > chapters.length) {
      try {
        final all = asList(asMap(asMap(await fetchJson(
                Uri.parse('$apiUrl/api/chapters').replace(queryParameters: {'postId': '$postId'})))['post'])['chapters']);
        if (all.length > chapters.length) chapters = all;
      } catch (_) {
        // Pakai daftar dari post.
      }
    }
    return parseDetails(post, chapters);
  }

  static SourceMangaStatus _status(String? raw) => switch (raw) {
        'ONGOING' || 'COMING_SOON' || 'MASS_RELEASED' => SourceMangaStatus.ongoing,
        'COMPLETED' => SourceMangaStatus.completed,
        'CANCELLED' || 'DROPPED' => SourceMangaStatus.cancelled,
        _ => SourceMangaStatus.unknown,
      };

  static bool isLocked(JsonMap c) =>
      c['isLocked'] == true ||
      c['isTimeLocked'] == true ||
      c['isPermanentlyLocked'] == true ||
      (c['chapterPurchased'] != true && (asInt(c['price']) ?? 0) != 0);

  SourceMangaDetails parseDetails(JsonMap post, List<Object?> rawChapters) {
    final slug = asString(post['slug']) ?? '';
    final type = switch (asString(post['seriesType'])) {
      'MANGA' => 'Manga',
      'MANHUA' => 'Manhua',
      'MANHWA' => 'Manhwa',
      _ => null,
    };
    final content = asString(post['postContent']);
    final synopsis = content == null || content.isEmpty
        ? ''
        : clean(html_parser.parse(content.replaceAll('\n', '<br>')).body?.text);
    final alt = clean(asString(post['alternativeTitles']));
    final description = [if (synopsis.isNotEmpty) synopsis, if (alt.isNotEmpty) 'Alternative Names: $alt'].join('\n\n');

    final chapters = <SourceChapter>[];
    for (final raw in rawChapters) {
      final c = asMap(raw);
      if (isLocked(c)) continue;
      final chapterId = asInt(c['id']);
      final chapterSlug = asString(c['slug']);
      final seriesSlug = slug.isNotEmpty ? slug : asString(asMap(c['mangaPost'])['slug']);
      if (chapterId == null || chapterSlug == null || seriesSlug == null) continue;
      final number = c['number'];
      final title = clean(asString(c['title']));
      final name = 'Chapter $number${title.isEmpty ? '' : ' - $title'}';
      chapters.add(SourceChapter(
        // ID bab di fragmen: dibutuhkan API gambar, diabaikan WebView.
        url: '$baseUrl/series/$seriesSlug/$chapterSlug#$chapterId',
        name: name,
        number: asDouble(number),
        uploadedAt: DateTime.tryParse(asString(c['createdAt']) ?? '')?.toLocal(),
      ));
    }

    // API tidak menjamin urutan (bab yang diunggah ulang bisa di depan):
    // urutkan terbaru → terlama, bab tanpa nomor tetap di posisinya relatif.
    final indexed = chapters.indexed.toList()
      ..sort((a, b) {
        final byNumber = (b.$2.number ?? -1).compareTo(a.$2.number ?? -1);
        return byNumber != 0 ? byNumber : a.$1.compareTo(b.$1);
      });
    chapters
      ..clear()
      ..addAll(indexed.map((e) => e.$2));

    return SourceMangaDetails(
      url: '$baseUrl/series/$slug',
      title: clean(asString(post['postTitle'])),
      thumbnailUrl: asString(post['featuredImage']),
      author: nonPlaceholder(asString(post['author'])),
      artist: nonPlaceholder(asString(post['artist'])),
      description: description.isEmpty ? null : description,
      genres: {
        if (type != null) type,
        for (final g in asList(post['genres']))
          if (clean(asString(asMap(g)['name'])).isNotEmpty) clean(asString(asMap(g)['name'])),
      }.toList(),
      status: _status(asString(post['seriesStatus'])),
      chapters: chapters,
    );
  }

  // =========================== Halaman ===========================

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final chapterId = int.tryParse(Uri.parse(chapter.url).fragment);
    if (chapterId == null) {
      throw const SourceException(SourceErrorKind.parse, detail: 'Muat ulang daftar bab.');
    }
    final json = asMap(await fetchJson(
        Uri.parse('$apiUrl/api/chapter').replace(queryParameters: {'chapterId': '$chapterId'})));
    return parsePages(asMap(json['chapter']));
  }

  static final _number = RegExp(r'\d+');

  List<String> parsePages(JsonMap chapter) {
    if (chapter['isShortLinkLocked'] == true) {
      throw const SourceException(SourceErrorKind.parse, detail: 'Bab terkunci (short link).');
    }
    if (chapter['isLockedByCoins'] == true) {
      throw const SourceException(SourceErrorKind.parse, detail: 'Bab terkunci (butuh koin).');
    }
    if (chapter['isPermanentlyLocked'] == true) {
      throw const SourceException(SourceErrorKind.parse, detail: 'Bab terkunci permanen.');
    }
    final images = [
      for (final img in asList(chapter['images']))
        if (asString(asMap(img)['url']) case final url?) (url, asInt(asMap(img)['order'])),
    ];
    int fileNumber(String url) => int.tryParse(_number.firstMatch(url.split('/').last)?.group(0) ?? '') ?? 1 << 30;
    images.sort((a, b) => sortPagesByFilename
        ? fileNumber(a.$1).compareTo(fileNumber(b.$1))
        : (a.$2 ?? 1 << 30).compareTo(b.$2 ?? 1 << 30));
    return [for (final (url, _) in images) url.replaceAll(' ', '%20')];
  }
}
