// Port Dart dari dua template pembaca berbasis JSON milik
// keiyoushi/extensions-source (Apache-2.0): lib-multisrc/monochrome (Monochrome
// CMS, API di `api.<domain>`) dan lib-multisrc/bakkin (BakkinReaderX, satu JSON
// `main.php` berisi semua seri). Instalasi self-hosted (alamat diisi pengguna)
// tidak dibawa.

import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';
import '../../core/i18n/strings.dart';

// ============================ Monochrome CMS ============================

class MonochromeSource extends HttpSource {
  MonochromeSource({
    required this.id,
    required this.name,
    required String baseUrl,
    required this.lang,
    this.contentWarning = ContentWarning.safe,
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

  String get apiUrl => baseUrl.replaceFirst('://', '://api.');

  @override
  Future<MangaPage> popular(int page) => search(page, '');

  @override
  Future<MangaPage> latest(int page) => search(page, '');

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    final json = asMap(await fetchJson(Uri.parse('$apiUrl/manga').replace(queryParameters: {
      'limit': '10',
      'offset': '${10 * (page - 1)}',
      'title': query.trim(),
    })));
    return parseList(json);
  }

  MangaPage parseList(JsonMap json) {
    final results = asList(json['results']);
    final offset = asInt(json['offset']) ?? 0;
    final limit = asInt(json['limit']) ?? 10;
    final total = asInt(json['total']) ?? 0;
    return MangaPage([
      for (final r in results)
        if (_manga(asMap(r)) case final m?) m,
    ], hasNextPage: total > results.length + offset * limit);
  }

  SourceManga? _manga(JsonMap m) {
    final id = asString(m['id']);
    final title = clean(asString(m['title']));
    if (id == null || title.isEmpty) return null;
    return SourceManga(url: '$baseUrl/manga/$id', title: title, thumbnailUrl: _cover(m));
  }

  String _cover(JsonMap m) => '$apiUrl/media/${asString(m['id'])}/cover.jpg?version=${asInt(m['version']) ?? 0}';

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final segments = Uri.parse(mangaUrl).pathSegments.where((s) => s.isNotEmpty).toList();
    final id = segments.length >= 2 ? segments[1] : '';
    if (id.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('URL seri tidak dikenali.'));
    final manga = asMap(await fetchJson(Uri.parse('$apiUrl/manga/$id')));
    final chapters = asList(await fetchJson(Uri.parse('$apiUrl/manga/$id/chapters')));
    return parseDetails(manga, chapters);
  }

  static String _number(double n) =>
      n == n.truncateToDouble() ? n.toInt().toString() : n.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');

  SourceMangaDetails parseDetails(JsonMap m, List<Object?> rawChapters) {
    final id = asString(m['id']) ?? '';
    final chapters = <SourceChapter>[];
    for (final raw in rawChapters) {
      final c = asMap(raw);
      final chapterId = asString(c['id']);
      final number = asDouble(c['number']);
      if (chapterId == null || number == null) continue;
      final volume = asInt(c['volume']);
      final name = asString(c['name']) ?? '';
      final title = [
        if (volume != null) 'Vol $volume ',
        'Chapter ${_number(number)}',
        if (name.isNotEmpty) ' - $name',
      ].join();
      chapters.add(SourceChapter(
        // Jumlah halaman dan versi di fragmen: dibutuhkan untuk membentuk URL gambar.
        url: '$baseUrl/chapters/$chapterId#$chapterId,${asInt(c['version']) ?? 0},${asInt(c['length']) ?? 0}',
        name: title,
        number: number,
        scanlator: asString(c['scanGroup']),
        uploadedAt: DateTime.tryParse(asString(c['uploadTime']) ?? '')?.toLocal(),
      ));
    }
    return SourceMangaDetails(
      url: '$baseUrl/manga/$id',
      title: clean(asString(m['title'])),
      thumbnailUrl: _cover(m),
      author: nonPlaceholder(asString(m['author'])),
      artist: nonPlaceholder(asString(m['artist'])),
      description: asString(m['description']),
      status: switch (asString(m['status'])) {
        'ongoing' || 'hiatus' => SourceMangaStatus.ongoing,
        'completed' || 'cancelled' => SourceMangaStatus.completed,
        _ => SourceMangaStatus.unknown,
      },
      chapters: chapters,
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final parts = Uri.decodeFull(Uri.parse(chapter.url).fragment).split(',');
    if (parts.length < 3) throw SourceException(SourceErrorKind.parse, detail: tr('Muat ulang daftar bab.'));
    final length = int.tryParse(parts[2]) ?? 0;
    return [for (var i = 1; i <= length; i++) '$apiUrl/media/${parts[0]}/$i.jpg?version=${parts[1]}'];
  }
}

// ============================== Bakkin ==============================

class BakkinSource extends HttpSource {
  BakkinSource({
    required this.id,
    required this.name,
    required String baseUrl,
    required this.lang,
    this.contentWarning = ContentWarning.safe,
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

  /// Kotlin memakai baseUrl berakhiran `/`; katalog membuang garis miring akhir.
  String get root => baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';

  Map<String, JsonMap>? _cache;

  Future<Map<String, JsonMap>> _all() async {
    final cached = _cache;
    if (cached != null && cached.isNotEmpty) return cached;
    final json = asMap(await fetchJson(Uri.parse('${root}main.php')));
    return _cache = {for (final e in json.entries) e.key: asMap(e.value)};
  }

  /// Nama seri; `name` kosong → pakai `dir`.
  static String seriesName(JsonMap s) => asString(s['name'])?.isNotEmpty == true ? asString(s['name'])! : (asString(s['dir']) ?? '');

  @override
  Future<MangaPage> popular(int page) => search(page, '');

  @override
  Future<MangaPage> latest(int page) => search(page, '');

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    final q = query.trim().toLowerCase();
    final all = await _all();
    return MangaPage([
      for (final s in all.values)
        if (q.isEmpty || seriesName(s).toLowerCase().contains(q))
          SourceManga(url: '$root#m=${asString(s['dir'])}', title: seriesName(s), thumbnailUrl: _thumb(s)),
    ], hasNextPage: false);
  }

  String _thumb(JsonMap s) => root + (asString(s['thumb']) ?? 'static/nocover.png');

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final dir = _fragmentValue(Uri.parse(mangaUrl).fragment, 'm');
    final series = (await _all()).values.where((s) => asString(s['dir']) == dir).firstOrNull;
    if (series == null) throw SourceException(SourceErrorKind.notFound, detail: tr('Seri tidak ditemukan.'));
    return parseDetails(series);
  }

  static String? _fragmentValue(String fragment, String key) {
    for (final part in fragment.split('&')) {
      if (part.startsWith('$key=')) return part.substring(key.length + 1);
    }
    return null;
  }

  SourceMangaDetails parseDetails(JsonMap s) {
    final dir = asString(s['dir']) ?? '';
    final chapters = <SourceChapter>[];
    for (final v in asList(s['volumes'])) {
      final vol = asMap(v);
      final volName = seriesName(vol);
      for (final c in asList(vol['chapters'])) {
        final ch = asMap(c);
        final chDir = asString(ch['dir']) ?? '';
        chapters.add(SourceChapter(
          url: '$root#m=$dir&v=${asString(vol['dir'])}&c=$chDir',
          name: '$volName - ${seriesName(ch)}',
          number: double.tryParse(chDir.substring(chDir.lastIndexOf('c') + 1)),
        ));
      }
    }
    return SourceMangaDetails(
      url: '$root#m=$dir',
      title: seriesName(s),
      thumbnailUrl: _thumb(s),
      author: asString(s['author']),
      status: switch (asString(s['status'])) {
        'Ongoing' => SourceMangaStatus.ongoing,
        'Completed' => SourceMangaStatus.completed,
        _ => SourceMangaStatus.unknown,
      },
      // JSON urut lama → baru; app memakai terbaru → terlama.
      chapters: chapters.reversed.toList(),
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final fragment = Uri.parse(chapter.url).fragment;
    final m = _fragmentValue(fragment, 'm');
    final v = _fragmentValue(fragment, 'v');
    final c = _fragmentValue(fragment, 'c');
    final series = (await _all()).values.where((s) => asString(s['dir']) == m).firstOrNull;
    if (series == null) throw SourceException(SourceErrorKind.notFound, detail: tr('Seri tidak ditemukan.'));
    for (final vol in asList(series['volumes'])) {
      if (asString(asMap(vol)['dir']) != v) continue;
      for (final ch in asList(asMap(vol)['chapters'])) {
        if (asString(asMap(ch)['dir']) == c) {
          return [for (final p in asList(asMap(ch)['pages'])) root + (asString(p) ?? '')];
        }
      }
    }
    throw SourceException(SourceErrorKind.notFound, detail: tr('Bab tidak ditemukan.'));
  }
}
