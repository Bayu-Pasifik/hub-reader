// Port Dart dari extension KomikRealm milik keiyoushi/extensions-source
// (Apache-2.0): src/id/komikrealm.
//
// Situsnya dibuat dengan Qwik. Data tiap halaman ada di `<path>/q-data.json`
// dalam format serialisasi Qwik (`_entry` + `_objs`), di-decode di sini.

import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class KomikRealmSource extends HttpSource {
  KomikRealmSource({super.dio});

  @override
  String get id => 'id.komikrealm';
  @override
  String get name => 'KomikRealm';
  @override
  String get lang => 'id';
  @override
  String get defaultBaseUrl => 'https://komikrealm.org';
  @override
  ContentWarning get contentWarning => ContentWarning.mixed;

  static const _popularFn = 'BFnMU0fpdeM';
  static const _latestFn = 'aBKj8Qeh2MM';
  static const _searchFn = 'HbSA6nELNQs';
  static const _pageSize = 24;
  static const _ownPaths = {'manhwa', 'manhua', 'doujinshi'};

  /// Decode serialisasi Qwik: `_objs[i]` direferensikan dengan indeks base-36.
  static Object? qwikDecode(JsonMap data) {
    final objs = asList(data['_objs']);
    Object? resolve(String index) {
      final value = objs[int.parse(index, radix: 36)];
      if (value is Map) return {for (final e in value.entries) '${e.key}': resolve('${e.value}')};
      if (value is List) return [for (final v in value) resolve('$v')];
      if (value is String && value.isNotEmpty && value.codeUnitAt(0) < 0x20) {
        return value.codeUnitAt(0) == 1 ? null : value.substring(1);
      }
      return value;
    }

    return resolve('${data['_entry']}');
  }

  Future<Object?> _routeData(String pageUrl, bool Function(Object?) predicate) async {
    final decoded = asMap(qwikDecode(asMap(await fetchJson(Uri.parse('${pageUrl}q-data.json')))));
    for (final loader in asMap(decoded['loaders']).values) {
      if (predicate(loader)) return loader;
    }
    throw const SourceException(SourceErrorKind.parse, detail: 'Data halaman tidak ditemukan.');
  }

  static String imageUrl(String url) {
    final secure = url.replaceFirst('http://', 'https://');
    return secure.contains('imgkomik.xyz') || secure.contains('manhwature.com')
        ? secure
        : secure.replaceFirst('https://', 'https://cdn.imgkomik.xyz/');
  }

  String _path(JsonMap s) {
    final type = (asString(s['type']) ?? '').toLowerCase();
    return '/${_ownPaths.contains(type) ? type : 'manga'}/${s['slug']}/';
  }

  SourceManga _manga(JsonMap s) => SourceManga(
        url: '$baseUrl${_path(s)}',
        title: clean(asString(s['title'])),
        thumbnailUrl: asString(s['poster']) == null ? null : imageUrl(asString(s['poster'])!),
      );

  Future<MangaPage> _listing(String url, String fn, int page) async {
    final List<Object?> series;
    if (page == 1) {
      series = asList(await _routeData(url, (l) => l is List && l.every((i) => i is Map && i.containsKey('slug'))));
    } else {
      // Halaman berikutnya dari fungsi server Qwik tombol "Load More".
      final body = '{"_entry":"2","_objs":["\\u0002_#s_$fn",$page,["0","1"]]}';
      final res = await dio.postUri<String>(
        Uri.parse(url).replace(queryParameters: {'qfunc': fn}),
        data: body,
        options: Options(contentType: 'application/qwik-json', headers: {'X-QRL': fn, 'Referer': url}),
      );
      series = asList(qwikDecode(asMap(jsonDecodeSafe(res.data))));
    }
    final items = [for (final s in series) _manga(asMap(s))];
    return MangaPage(items, hasNextPage: items.length >= _pageSize);
  }

  static Object? jsonDecodeSafe(String? raw) {
    try {
      return raw == null ? null : jsonDecode(raw);
    } on FormatException {
      throw const SourceException(SourceErrorKind.parse, detail: 'Respons tidak dikenali.');
    }
  }

  @override
  Future<MangaPage> popular(int page) => _listing('$baseUrl/popular/', _popularFn, page);

  @override
  Future<MangaPage> latest(int page) => _listing('$baseUrl/', _latestFn, page);

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) => query.trim().isEmpty
      ? popular(page)
      : _listing('$baseUrl/search/${Uri.encodeComponent(query.trim())}/', _searchFn, page);

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final url = mangaUrl.endsWith('/') ? mangaUrl : '$mangaUrl/';
    final s = asMap(await _routeData(url, (l) => l is Map && l.containsKey('chapters')));
    final names = <String, List<String>>{};
    for (final rel in asList(s['taxonomy_relation'])) {
      final t = asMap(asMap(rel)['taxonomy']);
      final name = asString(t['name']);
      if (name == null || name.toLowerCase() == 'unknown') continue;
      final list = names.putIfAbsent(asString(t['type']) ?? '', () => []);
      if (!list.any((n) => n.toLowerCase() == name.toLowerCase())) list.add(name);
    }
    final alter = asString(s['alter'])?.trim();
    final synopsis = asString(s['synopsis'])?.trim();
    final path = _path(s);
    return SourceMangaDetails(
      url: '$baseUrl$path',
      title: clean(asString(s['title'])),
      thumbnailUrl: asString(s['poster']) == null ? null : imageUrl(asString(s['poster'])!),
      author: names['author']?.join(', '),
      artist: names['artist']?.join(', '),
      description: [
        if (synopsis != null && synopsis.isNotEmpty) synopsis,
        if (alter != null && alter.isNotEmpty) 'Judul alternatif: $alter',
      ].join('\n\n'),
      genres: [if (asString(s['type']) case final t?) t, ...?names['genre']],
      status: switch (asString(s['status'])) {
        'on-going' => SourceMangaStatus.ongoing,
        'end' => SourceMangaStatus.completed,
        _ => SourceMangaStatus.unknown,
      },
      chapters: [
        for (final c in asList(s['chapters'])) _chapter(asMap(c), path),
      ],
    );
  }

  SourceChapter _chapter(JsonMap c, String seriesPath) {
    final n = asDouble(c['chapter']) ?? 0;
    final text = n == n.roundToDouble() ? '${n.toInt()}' : '$n';
    return SourceChapter(
      url: '$baseUrl${seriesPath}chapter-$text/',
      name: 'Chapter $text',
      number: n,
      uploadedAt: DateTime.tryParse(asString(c['created_at']) ?? '')?.toLocal(),
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final route = asMap(await _routeData(chapter.url, (l) => l is Map && l.containsKey('data')));
    final chapters = asList(asMap(route['data'])['chapters']);
    if (chapters.isEmpty) throw const SourceException(SourceErrorKind.parse, detail: 'Gambar tidak ditemukan.');
    final images = asMap(asMap(chapters.first)['images']);
    final keys = images.keys.toList()..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
    return [
      for (final k in keys)
        if (asString(asMap(images[k])['src']) case final src?) imageUrl(src),
    ];
  }
}
