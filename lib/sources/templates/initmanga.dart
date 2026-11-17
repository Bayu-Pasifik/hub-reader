// Port Dart dari template InitManga milik keiyoushi/extensions-source
// (Apache-2.0): lib-multisrc/initmanga.
//
// Tema WordPress "Init Manga" (UIkit). Daftar & detail dari HTML, pencarian dari
// `wp-json/initlise/v1/search`, bab dari `wp-json/initmanga/v1/chapters`.
// Gambar bab bisa: <img> biasa, terenkripsi AES-CBC (kunci dari PBKDF2 atau dari
// API `chapter-key`). Mode "Image Protector" (gambar diacak per-berkas) tidak
// didukung: pembacaan bab seperti itu gagal dengan pesan jelas.
// Bab berkunci (koin/login) disembunyikan.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:pointycastle/export.dart';

import '../../core/i18n/strings.dart';
import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class InitMangaSource extends HttpSource {
  InitMangaSource({
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

  String _s(String key, String fallback) => asString(vals[key]) ?? fallback;

  String get mangaUrlDirectory => _s('mangaUrlDirectory', 'seri');
  String get popularUrlSlug => _s('popularUrlSlug', mangaUrlDirectory);
  String get latestUrlSlug => _s('latestUrlSlug', 'son-guncellemeler');
  String get authorLabel => _s('authorLabel', 'Yazar');
  String get artistLabel => _s('artistLabel', 'İllüstratör');
  String get chapterPrefix => _s('chapterPrefix', 'Bölüm');
  String get genreFilterName => _s('genreFilterName', 'Kategoriler');
  String get allGenresLabel => _s('allGenresLabel', 'Tümü');
  String get altTitleLabel => _s('altTitleLabel', 'Alternatif Başlık');

  /// Selisih zona waktu situs terhadap UTC (jam); bawaan Turki (+3).
  int get siteOffsetHours => asInt(vals['siteOffsetHours']) ?? 3;

  // =========================== Daftar ===========================

  @override
  Future<MangaPage> popular(int page) => _list(popularUrlSlug, page);

  @override
  Future<MangaPage> latest(int page) => _list(latestUrlSlug, page);

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    final q = query.trim();
    if (q.isNotEmpty) {
      final json = await fetchJson(
          Uri.parse('$baseUrl/wp-json/initlise/v1/search').replace(queryParameters: {'term': q, 'page': '$page'}));
      return parseSearch(asList(json));
    }
    final genre = filters.single('genre');
    return _list(genre != null && genre.isNotEmpty ? genre : mangaUrlDirectory, page, isPath: genre != null && genre.isNotEmpty);
  }

  MangaPage parseSearch(List<Object?> results) => MangaPage(
        [
          for (final r in results)
            if (asString(asMap(r)['post_type']) == 'manga')
              if (_searchItem(asMap(r)) case final m?) m,
        ],
        hasNextPage: results.length == 10,
      );

  SourceManga? _searchItem(JsonMap r) {
    final url = asString(r['url']);
    final title = clean(html_parser.parseFragment(asString(r['title']) ?? '').text);
    if (url == null || title.isEmpty) return null;
    return SourceManga(url: url, title: title, thumbnailUrl: asString(r['thumb']));
  }

  Future<MangaPage> _list(String slug, int page, {bool isPath = false}) async {
    final base = isPath ? '$baseUrl${slug.startsWith('/') ? '' : '/'}${slug.replaceFirst(RegExp(r'/+$'), '')}' : '$baseUrl/$slug';
    final url = page > 1 ? '$base/page/$page/' : '$base/';
    final res = await fetchHtml(Uri.parse(url));
    return parseList(res.document, res.url);
  }

  MangaPage parseList(Document doc, Uri base) {
    final items = <SourceManga>[];
    for (final card in doc.querySelectorAll('div.manga-card, div.manga-item-grid > div.uk-panel')) {
      final link = card.querySelector('h2 a, h3 a');
      final url = absUrl(base, link?.attributes['href']);
      final title = clean(link?.text);
      if (url == null || title.isEmpty) continue;
      items.add(SourceManga(url: url, title: title, thumbnailUrl: _img(card.querySelector('img'), base)));
    }
    final next = doc.querySelector('ul.uk-pagination li:not(.uk-disabled) a [uk-pagination-next]');
    return MangaPage(items, hasNextPage: next != null);
  }

  static String? _img(Element? img, Uri base) {
    if (img == null) return null;
    for (final attr in const ['data-original-src', 'data-src', 'src']) {
      final v = img.attributes[attr];
      if (v == null || v.isEmpty || v.startsWith('data:')) continue;
      return absUrl(base, v);
    }
    return null;
  }

  // =========================== Filter ===========================

  @override
  Future<List<FilterDef>> filters() async {
    try {
      final res = await fetchHtml(Uri.parse('$baseUrl/$mangaUrlDirectory/'));
      final genres = [
        for (final a in res.document.querySelectorAll('ul.uk-list.uk-text-small a'))
          if (absUrl(res.url, a.attributes['href']) case final url?)
            FilterOption(clean(ownText(a)), Uri.parse(url).path),
      ];
      if (genres.isEmpty) return const [];
      return [
        SelectFilterDef('genre', genreFilterName, [FilterOption(allGenresLabel, ''), ...genres]),
      ];
    } catch (_) {
      return const [];
    }
  }

  // =========================== Detail ===========================

  static final _postId = RegExp(r'postid-(\d+)');
  static final _ldStatus = RegExp(r'"name":"status","value":"([a-z_]+)"');

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    final doc = res.document;
    final mangaId = _postId.firstMatch(doc.body?.className ?? '')?.group(1);
    if (mangaId == null) throw SourceException(SourceErrorKind.parse, detail: tr('Detail seri tidak ditemukan.'));
    final path = Uri.parse(mangaUrl).path.replaceFirst(RegExp(r'/+$'), '');

    final first = await _chapterPage(mangaId, 1);
    final pages = asInt(first['total_pages']) ?? 1;
    final items = [...asList(first['items'])];
    for (var p = 2; p <= pages; p++) {
      items.addAll(asList((await _chapterPage(mangaId, p))['items']));
    }
    return parseDetails(doc, res.url, items, path);
  }

  Future<JsonMap> _chapterPage(String mangaId, int page) async => asMap(await fetchJson(
        Uri.parse('$baseUrl/wp-json/initmanga/v1/chapters')
            .replace(queryParameters: {'manga_id': mangaId, 'per_page': '50', 'paged': '$page'}),
      ));

  String? _infoValue(Document doc, String label) {
    final info = doc.querySelector('div.manga-info-details');
    if (info == null) return null;
    final nodes = info.nodes;
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      if (n is Text && n.text.trim() == '$label:') {
        for (var j = i + 1; j < nodes.length; j++) {
          if (nodes[j] is Element) {
            final v = clean((nodes[j] as Element).text);
            return v.isEmpty ? null : v;
          }
        }
      }
    }
    return null;
  }

  SourceMangaStatus _status(Document doc) {
    final key = doc
            .querySelector('div.story-cover-wrap span.manga-status-ribbon')
            ?.classes
            .where((c) => c.startsWith('ribbon-'))
            .firstOrNull
            ?.substring(7) ??
        doc
            .querySelectorAll('script[type="application/ld+json"]')
            .map((s) => _ldStatus.firstMatch(s.text)?.group(1))
            .whereType<String>()
            .firstOrNull ??
        clean(doc.querySelector('#manga-status')?.text).toLowerCase().replaceAll(' ', '_');
    return switch (key) {
      'ongoing' || 'caught_up' => SourceMangaStatus.ongoing,
      'completed' => SourceMangaStatus.completed,
      'season_end' || 'source_hiatus' => SourceMangaStatus.hiatus,
      'dropped' => SourceMangaStatus.cancelled,
      _ => SourceMangaStatus.unknown,
    };
  }

  SourceMangaDetails parseDetails(Document doc, Uri base, List<Object?> rawChapters, String mangaPath) {
    final desc = doc.querySelector('div#manga-description');
    var text = '';
    if (desc != null) {
      var parts = desc.querySelectorAll('p, h1, h2, h3, h4, h5, h6, li');
      if (parts.isEmpty) parts = [desc];
      text = parts.map((e) => clean(e.text)).where((t) => t.isNotEmpty).join('\n\n');
    }
    final alt = clean(doc.querySelector('span#comic-othername')?.text);
    final description = [if (text.isNotEmpty) text, if (alt.isNotEmpty) '$altTitleLabel: $alt'].join('\n\n');
    final cover = doc.querySelector('meta[property="og:image"]')?.attributes['content'] ??
        _img(doc.querySelector('a.story-cover img'), base);

    final chapters = <SourceChapter>[];
    for (final raw in rawChapters) {
      final c = asMap(raw);
      final locked = (asString(c['lock_type']) ?? 'none') != 'none' && c['is_purchased'] != true;
      if (locked) continue;
      final slug = asString(c['slug'])?.replaceAll('/', '');
      final number = asDouble(c['number']);
      if (slug == null || number == null) continue;
      final title = clean(asString(c['title']));
      final lower = title.toLowerCase();
      final numText = number == number.truncateToDouble() ? '${number.toInt()}' : '$number';
      final name = lower.startsWith('bölüm') || lower.startsWith('chapter')
          ? title
          : title.isEmpty
              ? '$chapterPrefix $numText'
              : '$chapterPrefix $numText - $title';
      chapters.add(SourceChapter(
        url: '$baseUrl$mangaPath/$slug/',
        name: name,
        number: number,
        uploadedAt: _date(asString(c['created_at'])),
      ));
    }

    return SourceMangaDetails(
      url: base.toString(),
      title: clean(doc.querySelector('h1')?.text),
      thumbnailUrl: cover,
      author: _infoValue(doc, authorLabel),
      artist: _infoValue(doc, artistLabel),
      description: description.isEmpty ? null : description,
      genres: [
        for (final a in doc.querySelectorAll('div#genre-tags a:not(.uk-disabled)'))
          if (clean(a.text).isNotEmpty) clean(a.text),
      ],
      status: _status(doc),
      chapters: chapters,
    );
  }

  /// "yyyy-MM-dd HH:mm:ss" di zona waktu situs.
  DateTime? _date(String? raw) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})').firstMatch(raw ?? '');
    if (m == null) return null;
    final v = [for (var i = 1; i <= 6; i++) int.parse(m[i]!)];
    return DateTime.utc(v[0], v[1], v[2], v[3], v[4], v[5]).subtract(Duration(hours: siteOffsetHours)).toLocal();
  }

  // =========================== Halaman ===========================

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    final doc = res.document;
    if (doc.querySelector('div.lock-card') != null) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Bab berkunci.'));
    }
    final scripts = _scriptContents(doc);
    if (doc.querySelector('div.imip-protected-gallery') != null) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Bab dilindungi acak gambar; belum didukung.'));
    }
    final payloadScript = scripts.where((s) => s.contains('"ciphertext"')).firstOrNull;
    if (payloadScript == null) {
      return _toPages(doc.querySelectorAll('div#chapter-content > img'), res.url);
    }
    final payload = asMap(jsonDecode(_objectLiteral(payloadScript)));
    final dataScript = scripts.where((s) => s.contains('"decryption_key"')).firstOrNull;
    final data = dataScript == null ? const <String, Object?>{} : asMap(jsonDecode(_objectLiteral(dataScript)));

    final salt = asString(payload['salt']);
    final Uint8List key;
    if (salt != null) {
      key = passphraseKey(asString(data['decryption_key']) ?? '', salt);
    } else {
      key = await _fetchChapterKey(payload, asString(data['nonce']), chapter.url);
    }
    final content = decryptContent(asString(payload['ciphertext']) ?? '', asString(payload['iv']) ?? '', key);
    final fragment = html_parser.parseFragment(content);
    return _toPages(fragment.querySelectorAll('img, canvas[data-enc]'), res.url);
  }

  /// Isi skrip inline, atau skrip `data:` base64.
  static List<String> _scriptContents(Document doc) => [
        for (final s in doc.querySelectorAll('script'))
          () {
            final src = s.attributes['src'] ?? '';
            final i = src.indexOf('base64,');
            return i >= 0 ? utf8.decode(base64.decode(base64.normalize(src.substring(i + 7))), allowMalformed: true) : s.text;
          }(),
      ];

  static String _objectLiteral(String s) => s.substring(s.indexOf('{'), s.lastIndexOf('}') + 1);

  List<String> _toPages(Iterable<Element> elements, Uri base) {
    final out = <String>[];
    for (final e in elements) {
      String? url;
      if (e.localName == 'canvas') {
        final enc = e.attributes['data-enc'] ?? '';
        url = utf8.decode(base64.decode(base64.normalize(enc)).reversed.toList(), allowMalformed: true);
      } else {
        url = _img(e, base);
      }
      if (url != null && url.isNotEmpty) out.add(url);
    }
    if (out.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    return out;
  }

  static Uint8List _hex(String s) => Uint8List.fromList([
        for (var i = 0; i + 1 < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16),
      ]);

  /// Kunci AES-256 dari kata sandi (base64 `decryption_key`) lewat PBKDF2-SHA512, 999 putaran.
  static Uint8List passphraseKey(String decryptionKey, String saltHex) {
    final passphrase = utf8.decode(base64.decode(base64.normalize(decryptionKey)));
    final derivator = PBKDF2KeyDerivator(HMac(SHA512Digest(), 128))
      ..init(Pbkdf2Parameters(_hex(saltHex), 999, 32));
    return derivator.process(Uint8List.fromList(utf8.encode(passphrase)));
  }

  /// AES-CBC (padding PKCS7); `ciphertext` base64, `iv` heksadesimal.
  static String decryptContent(String ciphertext, String ivHex, Uint8List key) {
    final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
      ..init(false, PaddedBlockCipherParameters(ParametersWithIV(KeyParameter(key), _hex(ivHex)), null));
    return utf8.decode(cipher.process(base64.decode(base64.normalize(ciphertext))), allowMalformed: true);
  }

  Future<Uint8List> _fetchChapterKey(JsonMap payload, String? nonce, String chapterUrl) async {
    var response = await _postChapterKey(payload, nonce, chapterUrl, '');
    final token = asString(asMap(response['data'])['token']);
    if (asString(response['code']) == 'imc_challenge_required' && token != null) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      response = await _postChapterKey(payload, nonce, chapterUrl, token);
    }
    final key = asString(response['key']);
    if (key == null) {
      final code = asString(response['code']);
      throw SourceException(SourceErrorKind.parse,
          detail: code == 'imc_rate_limited' ? tr('Terlalu cepat, tunggu sebentar lalu coba lagi.') : tr('Buka bab ini di WebView.'));
    }
    return _hex(key);
  }

  Future<JsonMap> _postChapterKey(JsonMap payload, String? nonce, String chapterUrl, String challengeToken) async {
    try {
      final response = await dio.postUri<String>(
        Uri.parse('$baseUrl/wp-json/initmanga/v1/chapter-key'),
        data: jsonEncode({
          'chapter_id': payload['cid'],
          'epoch': payload['e'],
          'grant': payload['g'],
          'verdict': 'pass',
          'score': 0,
          'codes': <String>[],
          'challenge_token': challengeToken,
        }),
        options: Options(
          contentType: Headers.jsonContentType,
          validateStatus: (_) => true,
          headers: {
            'Accept': 'application/json',
            'Referer': chapterUrl,
            if (nonce != null && nonce.isNotEmpty) 'X-WP-Nonce': nonce,
          },
        ),
      );
      return asMap(jsonDecode(response.data ?? '{}'));
    } on FormatException {
      throw SourceException(SourceErrorKind.parse, detail: tr('Respons API bukan JSON.'));
    } catch (error) {
      throw toSourceException(error);
    }
  }
}
