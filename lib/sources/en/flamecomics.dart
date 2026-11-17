// Port Dart dari extension Flame Comics milik keiyoushi/extensions-source
// (Apache-2.0): src/en/flamecomics. Situs Next.js: data diambil dari rute
// `/_next/data/<buildId>/...json`; buildId berubah tiap deploy.

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';
import '../../core/i18n/strings.dart';

class FlameComicsSource extends HttpSource {
  FlameComicsSource({super.dio});

  @override
  String get id => 'en.flamecomics';
  @override
  String get name => 'Flame Comics';
  @override
  String get lang => 'en';
  @override
  String get defaultBaseUrl => 'https://flamecomics.xyz';
  @override
  ContentWarning get contentWarning => ContentWarning.mixed;

  static const _imagesBase = 'https://cdn.flamecomics.xyz/uploads/images/series';
  static final _buildIdRegex = RegExp(r'"buildId"\s*:\s*"([^"]+)"');

  String? _buildId;

  Future<String> _loadBuildId({bool refresh = false}) async {
    if (!refresh && _buildId != null) return _buildId!;
    final res = await fetchHtml(Uri.parse('$baseUrl/'));
    final id = _buildIdRegex.firstMatch(res.body)?.group(1);
    if (id == null) throw SourceException(SourceErrorKind.parse, detail: tr('Gagal membaca versi data situs.'));
    return _buildId = id;
  }

  /// GET data Next.js; bila buildId usang (404) ambil yang baru sekali lagi.
  Future<Map<String, Object?>> _data(List<String> path, [Map<String, String> query = const {}]) async {
    for (var attempt = 0;; attempt++) {
      final buildId = await _loadBuildId(refresh: attempt > 0);
      final url = Uri.parse('$baseUrl/_next/data/$buildId/${path.join('/')}')
          .replace(queryParameters: query.isEmpty ? null : query);
      try {
        final json = await fetchJson(url);
        if (json is Map<String, Object?>) {
          return (json['pageProps'] as Map?)?.cast<String, Object?>() ?? const {};
        }
        throw SourceException(SourceErrorKind.parse, detail: tr('Respons API bukan JSON.'));
      } on SourceException catch (e) {
        if (attempt == 0 && e.kind == SourceErrorKind.notFound) continue;
        rethrow;
      }
    }
  }

  List<Map<String, Object?>> _list(Object? v) =>
      [for (final e in (v as List? ?? const [])) if (e is Map) e.cast<String, Object?>()];

  SourceManga? _toManga(Map<String, Object?> s) {
    final seriesId = s['series_id'];
    final title = s['title'];
    if (seriesId == null || title is! String) return null;
    return SourceManga(
      url: '$baseUrl/series/$seriesId',
      title: title,
      thumbnailUrl: '$_imagesBase/$seriesId/${s['cover']}?${s['last_edit']}',
    );
  }

  List<SourceManga> _mangas(Iterable<Map<String, Object?>> series) =>
      [for (final s in series) if (_toManga(s) case final m?) m];

  @override
  Future<MangaPage> popular(int page) async {
    final series = _list((await _data(['browse.json']))['series'])
      ..sort((a, b) => ((a['popularityRank'] as num?) ?? 1 << 30).compareTo((b['popularityRank'] as num?) ?? 1 << 30));
    return MangaPage(_mangas(series), hasNextPage: false);
  }

  @override
  Future<MangaPage> latest(int page) async {
    final series = _list((await _data(['latest.json']))['allSeries']);
    return MangaPage(_mangas(series), hasNextPage: false);
  }

  static String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '');

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    final q = _norm(query);
    final series = _list((await _data(['browse.json']))['series'])
        .where((s) => _norm('${s['title']}').contains(q));
    return MangaPage(_mangas(series), hasNextPage: false);
  }

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final seriesId = Uri.parse(mangaUrl).pathSegments.last;
    final props = await _data(['series', '$seriesId.json'], {'id': seriesId});
    return parseDetails(props, mangaUrl);
  }

  SourceMangaDetails parseDetails(Map<String, Object?> props, String mangaUrl) {
    final s = (props['series'] as Map?)?.cast<String, Object?>();
    if (s == null) throw SourceException(SourceErrorKind.parse, detail: tr('Judul tidak ditemukan.'));
    final manga = _toManga(s);
    final synopsis = clean(RegExp(r'<[^>]*>').allMatches('${s['description'] ?? ''}').fold<String>(
        '${s['description'] ?? ''}', (acc, m) => acc.replaceAll(m.group(0)!, ' ')));
    final alts = [for (final a in (s['altTitles'] as List? ?? const [])) clean('$a')]..removeWhere((a) => a.isEmpty);
    final description = [
      if (synopsis.isNotEmpty) synopsis,
      if (alts.isNotEmpty) 'Alternative Names:\n${alts.map((a) => '- $a').join('\n')}',
    ].join('\n\n');
    String? join(Object? v) {
      final items = [for (final e in (v as List? ?? const [])) '$e'];
      return items.isEmpty ? null : items.join(', ');
    }

    final status = '${s['status']}'.toLowerCase();
    return SourceMangaDetails(
      url: mangaUrl,
      title: manga?.title ?? '${s['title']}',
      author: join(s['author']),
      artist: join(s['artist']),
      description: description.isEmpty ? null : description,
      thumbnailUrl: manga?.thumbnailUrl,
      status: switch (status) {
        'ongoing' => SourceMangaStatus.ongoing,
        'dropped' => SourceMangaStatus.cancelled,
        'hiatus' => SourceMangaStatus.hiatus,
        'completed' => SourceMangaStatus.completed,
        _ => SourceMangaStatus.unknown,
      },
      genres: {
        if (s['type'] is String) s['type'] as String,
        for (final t in (s['tags'] as List? ?? const [])) '$t',
      }.toList(),
      chapters: [
        for (final c in _list(props['chapters']))
          () {
            final number = double.tryParse('${c['chapter']}');
            final label = number == null ? '' : '$number'.replaceFirst(RegExp(r'\.0$'), '');
            final title = clean('${c['title'] ?? ''}');
            final release = c['release_date'];
            return SourceChapter(
              url: '$baseUrl/series/${c['series_id']}/${c['token']}',
              name: 'Chapter $label${title.isEmpty || title == 'null' ? '' : ' - $title'}',
              number: number,
              uploadedAt: release is num ? DateTime.fromMillisecondsSinceEpoch(release.toInt() * 1000) : null,
            );
          }(),
      ],
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final segs = Uri.parse(chapter.url).pathSegments;
    final seriesId = segs[segs.length - 2];
    final token = segs.last;
    final props = await _data(['series', seriesId, '$token.json'], {'id': seriesId, 'token': token});
    return parsePages(props);
  }

  List<String> parsePages(Map<String, Object?> props) {
    final ch = (props['chapter'] as Map?)?.cast<String, Object?>();
    final images = (ch?['images'] as Map?) ?? const {};
    final out = [
      for (final e in images.values)
        if (e is Map && e['name'] != null)
          '$_imagesBase/${ch!['series_id']}/${ch['token']}/${e['name']}?${ch['release_date']}',
    ];
    if (out.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    return out;
  }
}
