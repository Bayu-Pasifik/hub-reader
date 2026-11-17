// Port Dart dari extension West Manga milik keiyoushi/extensions-source
// (Apache-2.0): src/id/westmanga.

import '../../core/i18n/strings.dart';
import '../../core/utils/json.dart';
import '../filters.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class WestMangaSource extends HttpSource {
  WestMangaSource({super.dio});

  @override
  String get id => 'id.westmanga';
  @override
  String get name => 'West Manga';
  @override
  String get lang => 'id';
  @override
  String get defaultBaseUrl => 'https://v1.westmanga.my';
  @override
  ContentWarning get contentWarning => ContentWarning.safe;

  String? _visitToken;
  DateTime _visitExpires = DateTime.fromMillisecondsSinceEpoch(0);

  Future<String?> _visit({bool force = false}) async {
    if (!force && _visitToken != null && DateTime.now().isBefore(_visitExpires.subtract(const Duration(minutes: 5)))) {
      return _visitToken;
    }
    try {
      final json = asMap(await fetchJson(Uri.parse('$baseUrl/api/visit-token')));
      final token = asString(json['token']);
      if (json['status'] == true && token != null) {
        _visitToken = token;
        final exp = asInt(json['expires_at']);
        _visitExpires = exp == null
            ? DateTime.now().add(const Duration(hours: 1))
            : DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      }
    } on SourceException {
      if (force) _visitToken = null;
    }
    return _visitToken;
  }

  Future<JsonMap> _api(Uri url) async {
    Future<JsonMap> go() async {
      final token = await _visit();
      return asMap(await fetchJson(url, headers: {if (token != null) 'X-WM-Visit': token}));
    }

    try {
      return await go();
    } on SourceException {
      await _visit(force: true);
      return go();
    }
  }

  String? _abs(String? v) => v == null ? null : (v.startsWith('http') ? v : '$baseUrl$v');

  Future<MangaPage> _list(int page, String query, String order) async {
    final json = await _api(Uri.parse('$baseUrl/api/contents').replace(queryParameters: {
      if (query.isNotEmpty) 'q': query,
      'page': '$page',
      'per_page': '20',
      'type': 'Comic',
      if (order.isNotEmpty) 'orderBy': order,
    }));
    final pag = asMap(json['paginator']);
    return MangaPage(
      [
        for (final m in asList(json['data']))
          SourceManga(
            url: '$baseUrl/comic/${asMap(m)['slug']}',
            title: clean(asString(asMap(m)['title'])),
            thumbnailUrl: _abs(asString(asMap(m)['cover'])),
          ),
      ],
      hasNextPage: (asInt(pag['current_page']) ?? 1) < (asInt(pag['last_page']) ?? 1),
    );
  }

  @override
  Future<MangaPage> popular(int page) => _list(page, '', 'Popular');

  @override
  Future<MangaPage> latest(int page) => _list(page, '', 'Update');

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) =>
      _list(page, query.trim(), 'Update');

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final slug = Uri.parse(mangaUrl).pathSegments.where((s) => s.isNotEmpty).toList()[1];
    final m = asMap((await _api(Uri.parse('$baseUrl/api/comic/$slug')))['data']);
    final title = clean(asString(m['title']));
    if (title.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Judul seri tidak ditemukan.'));
    }
    final alt = asString(m['alternative_name']);
    final syn = clean(asString(m['sinopsis'])?.replaceAll(RegExp(r'<[^>]*>'), ' '));
    final chapters = <SourceChapter>[];
    for (final c in asList(m['chapters'])) {
      final cm = asMap(c);
      final number = asString(cm['number']) ?? '';
      final t = asInt(asMap(cm['updated_at'])['time']);
      chapters.add(SourceChapter(
        url: '$baseUrl/view/${cm['slug']}',
        name: '${tr('Bab')} $number',
        number: double.tryParse(number),
        uploadedAt: t == null ? null : DateTime.fromMillisecondsSinceEpoch(t * 1000),
      ));
    }
    return SourceMangaDetails(
      url: mangaUrl,
      title: title,
      thumbnailUrl: _abs(asString(m['cover'])),
      author: asString(m['author']),
      description: [
        if (syn.isNotEmpty) syn,
        if (alt != null) trp('Judul alternatif:\n- {alt}', {'alt': alt.trim()}),
      ].join('\n\n'),
      genres: [
        switch (asString(m['country_id'])) { 'JP' => 'Manga', 'CN' => 'Manhua', 'KR' => 'Manhwa', _ => '' },
        if (m['color'] == true) 'Colored',
        for (final g in asList(m['genres'])) clean(asString(asMap(g)['name'])),
      ].where((e) => e.isNotEmpty).toList(),
      status: switch ((asString(m['status']) ?? '').toLowerCase()) {
        'ongoing' => SourceMangaStatus.ongoing,
        'completed' => SourceMangaStatus.completed,
        'hiatus' => SourceMangaStatus.hiatus,
        _ => SourceMangaStatus.unknown,
      },
      chapters: chapters,
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final slug = Uri.parse(chapter.url).pathSegments.where((s) => s.isNotEmpty).last;
    final json = asMap((await _api(Uri.parse('$baseUrl/api/v/$slug')))['data']);
    final pages = [for (final i in asStringList(json['images'])) _abs(i)!];
    if (pages.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    }
    return pages;
  }
}
