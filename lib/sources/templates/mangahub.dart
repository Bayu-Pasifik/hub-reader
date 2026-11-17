// Port Dart dari template MangaHub milik keiyoushi/extensions-source
// (Apache-2.0): lib-multisrc/mangahub.
//
// Semua data dari GraphQL `<baseUrl>/graphql`. Akses dibuka oleh kunci API di
// cookie `mhub_access` + header `x-mhub-access`: kunci acak 16 byte, ditukar
// dengan yang dikirim situs (Set-Cookie halaman bab) bila API menolak. Daftar
// gambar bisa terenkripsi (`enc:v1:...`, AES-GCM, kunci dari /api/chapter-crypto).

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pointycastle/export.dart';

import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';
import '../../core/i18n/strings.dart';

class MangaHubSource extends HttpSource {
  MangaHubSource({
    required this.id,
    required this.name,
    required String baseUrl,
    required this.lang,
    required this.mangaSource,
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

  /// Kode situs di API (`m01`, `mf01`, ...).
  final String mangaSource;

  static const cdnUrl = 'https://imgx.mghcdn.com';
  static const thumbUrl = 'https://thumb.mghcdn.com';
  static const pageSize = 30;

  String _apiKey = _randomKey();

  static String _randomKey() {
    final rnd = Random.secure();
    return [for (var i = 0; i < 16; i++) rnd.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
  }

  static final _apiError = RegExp(r'rate\s*limit|api\s*key\s*(?:invalid)?|encryption(?:\s*error)?', caseSensitive: false);

  Map<String, String> get _apiHeaders => {
        'x-mhub-access': _apiKey,
        'Cookie': 'mhub_access=$_apiKey',
        'Accept-Language': 'en-US,en;q=0.5',
        'DNT': '1',
      };

  // =========================== GraphQL ===========================

  /// Jalankan query; bila API menolak kunci, coba kunci baru dari situs, lalu kunci acak.
  Future<JsonMap> graphQL(String query, {String? refreshUrl}) async {
    try {
      return await _post(query);
    } on _GraphQlError catch (e) {
      if (!_apiError.hasMatch(e.message)) throw SourceException(SourceErrorKind.server, detail: e.message);
      final old = _apiKey;
      await _refreshKey(refreshUrl, old);
      if (_apiKey != old) {
        try {
          return await _post(query);
        } on _GraphQlError catch (e2) {
          if (!_apiError.hasMatch(e2.message)) throw SourceException(SourceErrorKind.server, detail: e2.message);
        }
      }
      _apiKey = _randomKey();
      try {
        return await _post(query);
      } on _GraphQlError catch (e3) {
        throw SourceException(SourceErrorKind.server, detail: e3.message);
      }
    }
  }

  Future<JsonMap> _post(String query) async {
    final json = asMap(await postJson(Uri.parse('$baseUrl/graphql'), {'query': query}, headers: _apiHeaders));
    final errors = asList(json['errors']);
    if (errors.isNotEmpty) {
      throw _GraphQlError(errors.map((e) => asString(asMap(e)['message']) ?? '').join('\n'));
    }
    final data = json['data'];
    if (data == null) throw SourceException(SourceErrorKind.parse, detail: tr('Respons API tidak berisi data.'));
    return asMap(data);
  }

  static final _setCookieKey = RegExp(r'mhub_access=([^;]+)');

  Future<void> _refreshKey(String? refreshUrl, String oldKey) async {
    final url = refreshUrl ?? '$baseUrl/chapter/martial-peak/chapter-${1000 + Random().nextInt(2000)}';
    final slug = Uri.parse(url).pathSegments.length > 1 ? Uri.parse(url).pathSegments[1] : '';
    for (var i = 1; i <= 2; i++) {
      try {
        final response = await dio.getUri<String>(
          Uri.parse('$url${i == 1 ? '?reloadKey=1' : ''}'),
          options: Options(
            followRedirects: false,
            validateStatus: (_) => true,
            headers: {'Referer': '$baseUrl/manga/$slug', ..._apiHeaders},
          ),
        );
        for (final cookie in response.headers['set-cookie'] ?? const <String>[]) {
          final key = _setCookieKey.firstMatch(cookie)?.group(1);
          if (key != null && key.isNotEmpty && key != oldKey) {
            _apiKey = key;
            return;
          }
        }
      } catch (_) {
        // Coba berikutnya, lalu kunci acak.
      }
    }
  }

  static String _escape(String text) {
    final quoted = jsonEncode(text);
    return quoted.substring(1, quoted.length - 1);
  }

  // =========================== Daftar ===========================

  @override
  Future<MangaPage> popular(int page) => _list(page, order: 'POPULAR');

  @override
  Future<MangaPage> latest(int page) => _list(page, order: 'LATEST');

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) => _list(
        page,
        order: filters.single('order') ?? 'POPULAR',
        query: query.trim(),
        genre: filters.single('genre') ?? 'all',
        hideNsfw: filters.single('hideNsfw') == '1',
        hideYaoi: filters.single('hideYaoi') == '1',
      );

  Future<MangaPage> _list(
    int page, {
    required String order,
    String query = '',
    String genre = 'all',
    bool hideNsfw = false,
    bool hideYaoi = false,
  }) async {
    final data = await graphQL('''
{
  search(x: $mangaSource, q: "${_escape(query)}", genre: "$genre", mod: $order, hideNSFW: $hideNsfw, hideYaoi: $hideYaoi, offset: ${(page - 1) * pageSize}) {
    rows { title, slug, image }
  }
}''');
    final rows = asList(asMap(data['search'])['rows']);
    return MangaPage([
      for (final r in rows)
        if (parseListItem(asMap(r)) case final manga?) manga,
    ], hasNextPage: rows.length == pageSize);
  }

  SourceManga? parseListItem(JsonMap row) {
    final slug = asString(row['slug']);
    final title = clean(asString(row['title']));
    if (slug == null || title.isEmpty) return null;
    return SourceManga(url: '$baseUrl/manga/$slug', title: title, thumbnailUrl: _thumb(asString(row['image'])));
  }

  String? _thumb(String? image) => image == null || image.trim().isEmpty ? null : '$thumbUrl/$image';

  // =========================== Filter ===========================

  @override
  Future<List<FilterDef>> filters() async {
    var genres = <FilterOption>[];
    try {
      final data = await graphQL('{ genres { title, slug, group } }');
      genres = [
        for (final g in asList(data['genres']))
          if (asString(asMap(g)['slug']) case final slug?) FilterOption(clean(asString(asMap(g)['title'])), slug),
      ]..sort((a, b) => a.label.compareTo(b.label));
    } catch (_) {
      // Filter genre dilewati.
    }
    return [
      if (genres.isNotEmpty) SelectFilterDef('genre', 'Genre', [const FilterOption('All', 'all'), ...genres]),
      const SelectFilterDef('order', 'Order', [
        FilterOption('Popular', 'POPULAR'),
        FilterOption('Updates', 'LATEST'),
        FilterOption('A-Z', 'ALPHABET'),
        FilterOption('New', 'NEW'),
        FilterOption('Completed', 'COMPLETED'),
      ]),
      const SelectFilterDef('hideNsfw', 'Hide NSFW', [FilterOption('No', ''), FilterOption('Yes', '1')]),
      const SelectFilterDef('hideYaoi', 'Hide Yaoi', [FilterOption('No', ''), FilterOption('Yes', '1')]),
    ];
  }

  // =========================== Detail ===========================

  static String _slugOf(String url) {
    final segments = Uri.parse(url).pathSegments.where((s) => s.isNotEmpty).toList();
    return segments.length >= 2 ? segments[1] : (segments.lastOrNull ?? '');
  }

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final slug = _slugOf(mangaUrl);
    if (slug.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('URL seri tidak dikenali.'));
    final data = await graphQL('''
{
  manga(x: $mangaSource, slug: "${_escape(slug)}") {
    title, slug, status, image, author, artist, genres, description, alternativeTitle,
    chapters { number, title, date }
  }
}''', refreshUrl: '$baseUrl/manga/$slug');
    final manga = asMap(data['manga']);
    if (manga.isEmpty) throw SourceException(SourceErrorKind.notFound, detail: tr('Seri tidak ditemukan.'));
    return parseDetails(manga, slug);
  }

  static final _spaces = RegExp(r'\s+');

  /// "12.0" → "12" seperti `Float.toString().removeSuffix(".0")` di Kotlin.
  static String _numberText(double n) => n == n.truncateToDouble() ? n.toInt().toString() : n.toString();

  static String chapterName(String title, double number) {
    final n = _numberText(number);
    final t = title.trim().replaceAll(_spaces, ' ');
    if (t.contains(n)) return t;
    if (t.isNotEmpty) return 'Chapter $n - $t';
    return 'Chapter $n';
  }

  SourceMangaDetails parseDetails(JsonMap m, String slug) {
    final alt = (asString(m['alternativeTitle']) ?? '')
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final desc = asString(m['description']) ?? '';
    final description = [
      if (desc.isNotEmpty) desc,
      if (alt.isNotEmpty) 'Alternative Names:\n${alt.map((a) => '- $a').join('\n')}',
    ].join('\n\n');

    final chapters = <SourceChapter>[];
    for (final raw in asList(m['chapters'])) {
      final c = asMap(raw);
      final number = asDouble(c['number']);
      if (number == null) continue;
      chapters.add(SourceChapter(
        url: '$baseUrl/chapter/$slug/chapter-${number.toString()}',
        name: chapterName(asString(c['title']) ?? '', number),
        number: number,
        uploadedAt: DateTime.tryParse(asString(c['date']) ?? '')?.toLocal(),
      ));
    }
    return SourceMangaDetails(
      url: '$baseUrl/manga/$slug',
      title: clean(asString(m['title'])),
      thumbnailUrl: _thumb(asString(m['image'])),
      author: nonPlaceholder(asString(m['author'])),
      artist: nonPlaceholder(asString(m['artist'])),
      description: description.isEmpty ? null : description,
      genres: (asString(m['genres']) ?? '').split(',').map((g) => g.trim()).where((g) => g.isNotEmpty).toList(),
      status: switch (asString(m['status'])) {
        'ongoing' => SourceMangaStatus.ongoing,
        'completed' => SourceMangaStatus.completed,
        _ => SourceMangaStatus.unknown,
      },
      // API urut lama → baru; app memakai terbaru → terlama.
      chapters: chapters.reversed.toList(),
    );
  }

  // =========================== Halaman ===========================

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final segments = Uri.parse(chapter.url).pathSegments;
    // /chapter/<slug>/chapter-<n>
    if (segments.length < 3) throw SourceException(SourceErrorKind.parse, detail: tr('URL bab tidak dikenali.'));
    final slug = segments[1];
    final number = double.tryParse(segments[2].substring(segments[2].indexOf('-') + 1));
    if (number == null) throw SourceException(SourceErrorKind.parse, detail: tr('URL bab tidak dikenali.'));
    final data = await graphQL('''
{
  chapter(x: $mangaSource, slug: "${_escape(slug)}", number: $number) { pages, mangaID, number }
}''', refreshUrl: chapter.url);
    final pagesRaw = asString(asMap(data['chapter'])['pages']);
    if (pagesRaw == null) throw SourceException(SourceErrorKind.notFound, detail: tr('Bab tidak ditemukan.'));
    final text = pagesRaw.startsWith('enc:v1') ? await _decrypt(pagesRaw) : pagesRaw;
    return parsePages(text);
  }

  List<String> parsePages(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw SourceException(SourceErrorKind.parse, detail: tr('Daftar gambar tidak terbaca.'));
    }
    final List<String> paths;
    if (json is Map && json.containsKey('i')) {
      final prefix = asString(json['p']) ?? '';
      paths = [for (final i in asList(json['i'])) '$prefix${asString(i) ?? ''}'];
    } else if (json is List) {
      paths = [for (final p in json) asString(p) ?? ''];
    } else if (json is Map) {
      paths = [for (final p in json.values) asString(p) ?? ''];
    } else {
      paths = const [];
    }
    return [
      for (final p in paths)
        if (p.isNotEmpty) p.startsWith('http://') || p.startsWith('https://') ? p : '$cdnUrl/${p.replaceFirst(RegExp(r'^/'), '')}',
    ];
  }

  static Uint8List _b64(String s) => base64Url.decode(base64Url.normalize(s));

  Future<String> _decrypt(String pages) async {
    final params = asMap(await fetchJson(Uri.parse('$baseUrl/api/chapter-crypto'), headers: _apiHeaders));
    final parts = pages.split(':');
    if (parts.length < 6) throw SourceException(SourceErrorKind.parse, detail: tr('Format enkripsi tidak dikenal.'));
    final keyId = parts[2];
    final keys = asMap(params['keys']);
    final keyData = asString(keys[keyId]) ??
        (params['keyId'] == null || params['keyId'] == keyId ? asString(params['key']) : null);
    if (keyData == null) throw SourceException(SourceErrorKind.parse, detail: tr('Kunci dekripsi tidak ditemukan.'));
    return decryptGcm(_b64(keyData), _b64(parts[3]), _b64(parts[4]), _b64(parts[5]));
  }

  /// AES-GCM 128-bit tag. Masukan pointycastle = ciphertext + tag.
  static String decryptGcm(Uint8List key, Uint8List iv, Uint8List tag, Uint8List cipher) {
    final gcm = GCMBlockCipher(AESEngine())..init(false, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
    final out = gcm.process(Uint8List.fromList([...cipher, ...tag]));
    return utf8.decode(out);
  }
}

class _GraphQlError implements Exception {
  _GraphQlError(this.message);
  final String message;
}
