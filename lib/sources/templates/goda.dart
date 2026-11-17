// Port Dart dari template GoDa milik keiyoushi/extensions-source
// (Apache-2.0): lib-multisrc/goda.
//
// Situs Astro: daftar `/hots/page/N` & `/newss/page/N`, pencarian `/s/<kata>`, detail dari
// halaman `/manga/<kunci>` (susunan elemen tetap), bab dari `/manga/get?mid=<id>&mode=all`
// (HTML) dan gambar dari `/chapter/getcontent?m=<id>&c=<bab>` (HTML).

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../core/i18n/strings.dart';
import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class GoDaSource extends HttpSource {
  GoDaSource({
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

  bool get enableGenres => vals['enableGenres'] != false;
  bool get _zh => lang == 'zh';

  // =========================== Daftar ===========================

  @override
  Future<MangaPage> popular(int page) => _list('$baseUrl/hots/page/$page');

  @override
  Future<MangaPage> latest(int page) => _list('$baseUrl/newss/page/$page');

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) {
    final q = query.trim();
    if (q.isNotEmpty) {
      return _list('$baseUrl/s/${Uri.encodeComponent(q)}?page=$page');
    }
    final genre = filters.single('genre');
    if (genre != null && genre.isNotEmpty) return _list('$baseUrl$genre/page/$page');
    return popular(page);
  }

  Future<MangaPage> _list(String url) async {
    final res = await fetchHtml(Uri.parse(url));
    return parseList(res.document, res.url);
  }

  static String _key(String link) {
    final i = link.indexOf('/manga/');
    final tail = i >= 0 ? link.substring(i + 7) : link;
    return tail.replaceFirst(RegExp(r'/+$'), '');
  }

  MangaPage parseList(Document doc, Uri base) {
    final items = <SourceManga>[];
    for (final a in doc.querySelectorAll('.container > .cardlist .pb-2 a')) {
      final href = a.attributes['href'];
      final title = clean(ownText(a.querySelector('h3') ?? a));
      if (href == null || href.isEmpty || title.isEmpty) continue;
      final src = a.querySelector('img')?.attributes['src'];
      items.add(SourceManga(
        url: '$baseUrl/manga/${_key(href)}',
        title: title,
        thumbnailUrl: src == null ? null : _thumb(src, base),
      ));
    }
    final next = doc.querySelector('a[aria-label="${_zh ? '下一頁' : 'NEXT'}"] button');
    return MangaPage(items, hasNextPage: next != null);
  }

  /// Sampul lewat proxy gambar (`?url=<asli>`): ambil alamat aslinya.
  static String? _thumb(String src, Uri base) {
    final abs = absUrl(base, src);
    if (abs == null) return null;
    final inner = Uri.tryParse(abs)?.queryParameters['url'];
    return inner != null && src.contains('url=') ? inner : abs;
  }

  // =========================== Filter ===========================

  @override
  Future<List<FilterDef>> filters() async {
    if (!enableGenres) return const [];
    try {
      final res = await fetchHtml(Uri.parse('$baseUrl/hots/page/1'));
      final box = res.document.querySelector('h2')?.parent?.parent;
      if (box == null) return const [];
      final genres = [
        for (final a in box.querySelectorAll('a'))
          if ((a.attributes['href'] ?? '').isNotEmpty && clean(a.text).isNotEmpty)
            FilterOption(clean(a.text).replaceFirst(RegExp(r'^#'), ''), a.attributes['href']!),
      ];
      if (genres.isEmpty) return const [];
      return [SelectFilterDef('genre', _zh ? '分类（搜索文本时无效）' : 'Genre (ignored with text search)', [const FilterOption('', ''), ...genres])];
    } catch (_) {
      return const [];
    }
  }

  // =========================== Detail ===========================

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    final mangaId = res.document.querySelector('#mangachapters')?.attributes['data-mid'];
    if (mangaId == null || mangaId.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Detail seri tidak ditemukan.'));
    }
    final list = await fetchText(
      Uri.parse('$baseUrl/manga/get').replace(queryParameters: {'mid': mangaId, 'mode': 'all'}),
      headers: {'X-Requested-With': 'XMLHttpRequest'},
    );
    final chapters = parseChapters(html_parser.parse(list), mangaId);
    return parseDetails(res.document, res.url, mangaId, chapters);
  }

  SourceMangaDetails parseDetails(Document doc, Uri base, String mangaId, List<SourceChapter> chapters) {
    final main = doc.querySelector('main') ?? doc.body!;
    final h1 = main.querySelector('h1');
    final elements = h1?.parent?.parent?.children ?? const <Element>[];
    if (h1 == null || elements.length < 5) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Detail seri tidak ditemukan.'));
    }
    String join(Iterable<Element> items, {bool hashtag = false}) => items
        .map((e) => clean(e.text).replaceFirst(RegExp(r' ,$'), '').replaceFirst(hashtag ? RegExp(r'^#') : RegExp(r'^$'), ''))
        .where((t) => t.isNotEmpty)
        .join(', ');
    final statusText = clean(h1.children.isEmpty ? '' : h1.children.first.text);
    final description = '${clean(elements[4].text)}\n\nID: $mangaId'.trim();
    final genres = [
      ...elements[2].children.skip(1).map((e) => clean(e.text).replaceFirst(RegExp(r' ,$'), '')),
      ...elements[3].children.map((e) => clean(e.text).replaceFirst(RegExp(r'^#'), '')),
    ].where((t) => t.isNotEmpty).toList();
    final author = join(elements[1].children.skip(1));
    return SourceMangaDetails(
      url: base.toString(),
      title: clean(ownText(h1)),
      thumbnailUrl: main.querySelector('img.object-cover')?.attributes['src'],
      author: author.isEmpty ? null : author,
      description: description,
      genres: genres,
      status: switch (statusText) {
        '連載中' || 'Ongoing' => SourceMangaStatus.ongoing,
        '完結' => SourceMangaStatus.completed,
        '停止更新' => SourceMangaStatus.cancelled,
        '休刊' => SourceMangaStatus.hiatus,
        _ => SourceMangaStatus.unknown,
      },
      chapters: chapters,
    );
  }

  /// Urutan dari situs terbaru→terlama dibalik; `.chapteritem` diurutkan lama→baru oleh situs.
  List<SourceChapter> parseChapters(Document doc, String mangaId) {
    final out = <SourceChapter>[];
    for (final el in doc.querySelectorAll('.chapteritem').toList().reversed) {
      final a = el.querySelector('a');
      final href = a?.attributes['href'];
      final name = clean(a?.attributes['data-ct']);
      final cs = a?.attributes['data-cs'];
      if (href == null || name.isEmpty || cs == null) continue;
      out.add(SourceChapter(
        url: '$baseUrl/manga/${_key(href)}#$mangaId/$cs',
        name: name,
        number: parseChapterNumber(name),
      ));
    }
    return out;
  }

  // =========================== Halaman ===========================

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final frag = Uri.parse(chapter.url).fragment;
    final parts = frag.split('/');
    if (parts.length < 2 || parts[0].isEmpty || parts[1].isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Muat ulang daftar bab.'));
    }
    final html = await fetchText(
      Uri.parse('$baseUrl/chapter/getcontent').replace(queryParameters: {'m': parts[0], 'c': parts[1]}),
      headers: {'X-Requested-With': 'XMLHttpRequest'},
    );
    return parsePages(html_parser.parse(html));
  }

  List<String> parsePages(Document doc) {
    final out = <String>[];
    for (final img in doc.querySelectorAll('#chapcontent > div > img')) {
      final url = (img.attributes['data-src'] ?? '').isNotEmpty ? img.attributes['data-src']! : (img.attributes['src'] ?? '');
      if (url.isNotEmpty) out.add(url);
    }
    if (out.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    return out;
  }
}
