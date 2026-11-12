// Port Dart dari template NatsuId milik keiyoushi/extensions-source
// (Apache-2.0): lib-multisrc/natsuid (Kiryuu, Natsu).
//
// Pencarian lewat admin-ajax `advanced_search` (multipart + nonce), detail
// dari WordPress REST `wp-json/wp/v2/manga`, bab dari admin-ajax `chapter_list`.

import 'dart:convert';
import 'dart:math';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class NatsuIdSource extends HttpSource {
  NatsuIdSource({
    required this.id,
    required this.name,
    required String baseUrl,
    required this.lang,
    this.contentWarning = ContentWarning.safe,
    this.chapterPageOne = false,
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

  /// Kiryuu memakai `page=1` untuk daftar bab (lainnya angka acak > 3).
  final bool chapterPageOne;

  Uri get _ajax => Uri.parse('$baseUrl/wp-admin/admin-ajax.php');
  static const _xhr = {'X-Requested-With': 'XMLHttpRequest'};

  String? _nonce;

  Future<String> _getNonce() async {
    if (_nonce != null) return _nonce!;
    final body =
        await fetchText(_ajax.replace(queryParameters: {'type': 'search_form', 'action': 'get_nonce'}), headers: _xhr);
    final value = html_parser.parseFragment(body).querySelector('input[name=search_nonce]')?.attributes['value'];
    if (value == null || value.isEmpty) {
      throw const SourceException(SourceErrorKind.parse, detail: 'Nonce pencarian tidak ditemukan.');
    }
    return _nonce = value;
  }

  // ---------------------------------------------------------------- daftar

  @override
  Future<MangaPage> popular(int page) => search(page, '', filters: FilterValues.empty.withSingle('orderby', 'popular'));

  @override
  Future<MangaPage> latest(int page) => search(page, '', filters: FilterValues.empty.withSingle('orderby', 'updated'));

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    final fields = {
      'nonce': await _getNonce(),
      'inclusion': 'OR',
      'exclusion': 'OR',
      'page': '$page',
      'genre': jsonEncode(filters.multi('genre')),
      'genre_exclude': '[]',
      'author': '[]',
      'artist': '[]',
      'project': '0',
      'type': jsonEncode(filters.multi('type')),
      'status': jsonEncode(filters.multi('status')),
      'order': 'desc',
      'orderby': filters.single('orderby') ?? 'popular',
      'query': query.trim(),
    };
    final body =
        await postMultipart(_ajax.replace(queryParameters: {'action': 'advanced_search'}), fields, headers: _xhr);
    final doc = html_parser.parseFragment(body);
    final slugs = <String>[];
    for (final a in doc.querySelectorAll('div > a[href*="/manga/"]')) {
      if (a.querySelector('img') == null) continue;
      final segs = Uri.tryParse(a.attributes['href'] ?? '')?.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segs != null && segs.length >= 2 && !slugs.contains(segs[1])) slugs.add(segs[1]);
    }
    if (slugs.isEmpty) return const MangaPage([], hasNextPage: false);

    final api = Uri.parse('$baseUrl/wp-json/wp/v2/manga').replace(
      query: [...slugs.map((s) => 'slug[]=${Uri.encodeQueryComponent(s)}'), 'per_page=${slugs.length + 1}', '_embed']
          .join('&'),
    );
    final bySlug = {
      for (final m in asList(await fetchJson(api)))
        if (!_isNovel(asMap(m))) asString(asMap(m)['slug']): asMap(m),
    };
    final hasNext = doc.querySelectorAll('button').any((b) => b.querySelector('svg') != null);
    return MangaPage([
      for (final slug in slugs)
        if (bySlug[slug] case final m?)
          SourceManga(url: '$baseUrl/manga/$slug/', title: _title(m), thumbnailUrl: _cover(m)),
    ], hasNextPage: hasNext);
  }

  @override
  Future<List<FilterDef>> filters() async => const [
        SelectFilterDef('orderby', 'Urutkan', [
          FilterOption('Populer', 'popular'),
          FilterOption('Rating', 'rating'),
          FilterOption('Update terbaru', 'updated'),
          FilterOption('Terbaru', 'latest'),
          FilterOption('A-Z', 'title'),
        ]),
        MultiSelectFilterDef('type', 'Tipe', [
          FilterOption('Manga', 'manga'),
          FilterOption('Manhwa', 'manhwa'),
          FilterOption('Manhua', 'manhua'),
        ]),
        MultiSelectFilterDef('status', 'Status', [
          FilterOption('Berjalan', 'ongoing'),
          FilterOption('Tamat', 'completed'),
          FilterOption('Hiatus', 'on-hiatus'),
        ]),
      ];

  // ------------------------------------------------------------ WP REST

  static List<String> terms(JsonMap manga, String taxonomy) {
    for (final group in asList(asMap(manga['_embedded'])['wp:term'])) {
      final list = asList(group);
      if (list.isNotEmpty && asMap(list.first)['taxonomy'] == taxonomy) {
        return [
          for (final t in list)
            if (asString(asMap(t)['name']) case final n?) n
        ];
      }
    }
    return const [];
  }

  static bool _isNovel(JsonMap m) => terms(m, 'type').contains('Novel');

  static String _unescape(String s) => html_parser.parseFragment(s).text ?? s;

  static String _title(JsonMap m) => _unescape(asString(asMap(m['title'])['rendered']) ?? 'Tanpa judul').trim();

  static String? _cover(JsonMap m) {
    final media = asList(asMap(m['_embedded'])['wp:featuredmedia']);
    final src = media.isEmpty ? null : asString(asMap(media.first)['source_url']);
    if (src != null) return src;
    final og = asList(asMap(m['yoast_head_json'])['og_image']);
    return og.isEmpty ? null : asString(asMap(og.first)['url']);
  }

  // ---------------------------------------------------------------- detail

  String _slug(String url) => Uri.parse(url).pathSegments.where((s) => s.isNotEmpty).elementAt(1);

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final slug = _slug(mangaUrl);
    final list = asList(await fetchJson(
      Uri.parse('$baseUrl/wp-json/wp/v2/manga').replace(query: 'slug[]=${Uri.encodeQueryComponent(slug)}&_embed'),
    ));
    if (list.isEmpty) throw const SourceException(SourceErrorKind.notFound);
    final m = asMap(list.first);
    final mangaId = '${m['id']}';
    return parseDetails(m, mangaUrl, await _chapters(mangaId));
  }

  SourceMangaDetails parseDetails(JsonMap m, String url, List<SourceChapter> chapters) {
    final title = _title(m);
    final content = html_parser.parseFragment(asString(asMap(m['content'])['rendered']) ?? '');
    final description = content.querySelectorAll('p').map((p) => clean(p.text)).where((t) => t.isNotEmpty).join('\n\n');
    final alt = asString(asMap(asMap(m['metadata'] ?? m['meta'])['meta'])['alternative_title']);
    final alts = alt
            ?.split(',')
            .map((a) => _unescape(a).trim())
            .where((a) => a.isNotEmpty && a.toLowerCase() != title.toLowerCase())
            .toSet()
            .toList() ??
        const <String>[];
    final status = terms(m, 'status');
    return SourceMangaDetails(
      url: url,
      title: title,
      thumbnailUrl: _cover(m),
      author: terms(m, 'series-author').join(', ').trim().isEmpty ? null : terms(m, 'series-author').join(', '),
      artist: terms(m, 'artist').join(', ').trim().isEmpty ? null : terms(m, 'artist').join(', '),
      description: [
        if (description.isNotEmpty) description else if (clean(content.text).isNotEmpty) clean(content.text),
        if (alts.isNotEmpty) 'Judul alternatif:\n${alts.map((a) => '- $a').join('\n')}',
      ].join('\n\n'),
      genres: {...terms(m, 'genre'), ...terms(m, 'type')}.toList(),
      status: status.contains('Ongoing')
          ? SourceMangaStatus.ongoing
          : status.contains('Completed')
              ? SourceMangaStatus.completed
              : status.contains('On Hiatus')
                  ? SourceMangaStatus.hiatus
                  : status.contains('Cancelled')
                      ? SourceMangaStatus.cancelled
                      : SourceMangaStatus.unknown,
      chapters: chapters,
    );
  }

  Future<List<SourceChapter>> _chapters(String mangaId) async {
    final page = chapterPageOne ? '1' : '${99 + Random().nextInt(9900)}';
    final body = await fetchText(
      _ajax.replace(queryParameters: {'manga_id': mangaId, 'page': page, 'action': 'chapter_list'}),
      headers: _xhr,
    );
    return parseChapters(html_parser.parseFragment(body), Uri.parse(baseUrl));
  }

  /// Padanan `div a:has(time)`: tautan yang memuat elemen `<time>`.
  List<SourceChapter> parseChapters(DocumentFragment doc, Uri base) {
    final seen = <String>{};
    return [
      for (final a in doc.querySelectorAll('div a'))
        if (a.querySelector('time') case final time?)
          if (absUrl(base, a.attributes['href']) case final url? when seen.add(url))
            SourceChapter(
              url: url,
              name: ownOrFullText(a.querySelector('span') ?? a),
              number: parseChapterNumber(ownOrFullText(a.querySelector('span') ?? a)),
              uploadedAt: DateTime.tryParse(time.attributes['datetime'] ?? '')?.toLocal(),
            ),
    ];
  }

  // ------------------------------------------------------------- halaman

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    final pages = parsePages(res.document, res.url);
    if (pages.isEmpty) throw const SourceException(SourceErrorKind.parse, detail: 'Gambar bab tidak ditemukan.');
    return pages;
  }

  List<String> parsePages(Document doc, Uri pageUrl) => [
        for (final img in doc.querySelectorAll('section[data-image-data] img'))
          if (imgAttr(img, pageUrl) case final url?) url,
      ];
}
