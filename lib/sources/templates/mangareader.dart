// Port Dart dari template MangaReader milik keiyoushi/extensions-source
// (Apache-2.0): lib-multisrc/mangareader.
//
// Situs bergaya "ani" (MangaNow, RawOtaku, Jmanga): daftar `/filter/?sort=...&page=N`,
// pencarian `/search?keyword=...`, detail & bab dalam satu halaman, gambar dari
// JSON AJAX `{html: "..."}`. Filter khusus tiap situs (jenis, genre, ...) belum ikut:
// hanya urutan.

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../core/i18n/strings.dart';
import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class MangaReaderSource extends HttpSource {
  MangaReaderSource({
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

  String get _pageParam => asString(vals['pageParam']) ?? 'page';
  String get _searchPath => asString(vals['searchPathSegment']) ?? 'search';
  String get _searchKeyword => asString(vals['searchKeyword']) ?? 'keyword';
  String get _chapterIdSelect => asString(vals['chapterIdSelect']) ?? 'en-chapters';
  String get _ajaxPattern => asString(vals['ajaxUrl']) ?? '/ajax/image/list/{id}?mode=vertical';

  /// Nilai atribut tanpa tanda kutip (`[data-url$=a.jpg]`) dikutip agar dikenali parser selector.
  String get _pageSelector => (asString(vals['pageSelector']) ?? '.container-reader-chapter > div > img')
      .replaceAllMapped(RegExp(r'\[([\w-]+)([\^$*~|]?=)([^\]"]+)\]'), (m) => '[${m[1]}${m[2]}"${m[3]}"]');

  bool get _ja => lang == 'ja';

  @override
  Map<String, String> get extraHeaders => const {'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'};

  // =========================== Daftar ===========================

  @override
  Future<MangaPage> popular(int page) => _list(page, '', sort: 'most-viewed');

  @override
  Future<MangaPage> latest(int page) => _list(page, '', sort: 'latest-updated');

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) =>
      _list(page, query.trim(), sort: filters.single('sort') ?? 'default');

  Future<MangaPage> _list(int page, String query, {required String sort}) async {
    final Uri url;
    if (query.isNotEmpty) {
      url = Uri.parse(_searchPath.isEmpty ? '$baseUrl/' : '$baseUrl/$_searchPath')
          .replace(queryParameters: {_searchKeyword: query, _pageParam: '$page'});
    } else {
      url = Uri.parse('$baseUrl/filter/').replace(queryParameters: {'sort': sort, _pageParam: '$page'});
    }
    final res = await fetchHtml(url);
    return parseList(res.document, res.url);
  }

  MangaPage parseList(Document doc, Uri base) {
    final items = <SourceManga>[];
    for (final el in doc.querySelectorAll('.manga_list-sbs .manga-poster')) {
      final url = absUrl(base, el.attributes['href']);
      final img = el.querySelector('img');
      final title = clean(img?.attributes['alt']);
      if (url == null || title.isEmpty) continue;
      items.add(SourceManga(url: url, title: title, thumbnailUrl: _img(img, base)));
    }
    return MangaPage(items, hasNextPage: doc.querySelector('ul.pagination > li.active + li') != null);
  }

  static String _own(Element? e) => e == null ? '' : clean(ownText(e));

  static String? _img(Element? img, Uri base) {
    if (img == null) return null;
    for (final attr in const ['data-lazy-src', 'data-src', 'data-url', 'src']) {
      final v = img.attributes[attr];
      if (v != null && v.trim().isNotEmpty) return absUrl(base, v.trim());
    }
    return null;
  }

  // =========================== Filter ===========================

  @override
  Future<List<FilterDef>> filters() async => [
        SelectFilterDef('sort', _ja ? '選別' : 'Sort', [
          const FilterOption('Default', 'default'),
          const FilterOption('Latest Updated', 'latest-updated'),
          const FilterOption('Score', 'score'),
          const FilterOption('Name A-Z', 'name-az'),
          const FilterOption('Release Date', 'release-date'),
          const FilterOption('Most Viewed', 'most-viewed'),
        ]),
      ];

  // =========================== Detail ===========================

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    return parseDetails(res.document, res.url);
  }

  static SourceMangaStatus _status(String? raw) => switch ((raw ?? '').toLowerCase()) {
        'ongoing' || 'publishing' || 'releasing' => SourceMangaStatus.ongoing,
        'completed' || 'finished' => SourceMangaStatus.completed,
        'on-hold' || 'on_hiatus' => SourceMangaStatus.hiatus,
        'canceled' || 'discontinued' => SourceMangaStatus.cancelled,
        _ => SourceMangaStatus.unknown,
      };

  SourceMangaDetails parseDetails(Document doc, Uri base) {
    final root = doc.querySelector('#ani_detail');
    if (root == null) throw SourceException(SourceErrorKind.parse, detail: tr('Detail seri tidak ditemukan.'));
    final title = _own(root.querySelector('.manga-name'));
    final alt = _own(root.querySelector('.manga-name-or'));
    final description = [
      _own(root.querySelector('.description')),
      if (alt.isNotEmpty && alt != title) 'Alternative Title: $alt',
    ].where((s) => s.isNotEmpty).join('\n\n');

    String? author, artist;
    var status = SourceMangaStatus.unknown;
    final authorLabel = _ja ? '著者' : 'Authors';
    final statusLabel = _ja ? '地位' : 'Status';
    for (final info in root.querySelectorAll('.anisc-info > .item')) {
      final head = _own(info.querySelector('.item-head'));
      if (head == '$authorLabel:') {
        final links = info.querySelectorAll('a');
        final authors = <String>[];
        final artists = <String>[];
        for (final a in links) {
          final siblings = a.parent?.nodes ?? const <Node>[];
          final at = siblings.indexOf(a);
          final next = at >= 0 && at + 1 < siblings.length ? siblings[at + 1] : null;
          final isArt = next is Text && next.text.contains('(Art)');
          (isArt ? artists : authors).add(clean(ownText(a)).replaceAll(',', ''));
        }
        if (authors.isNotEmpty) author = authors.join(', ');
        if (artists.isNotEmpty) artist = artists.join(', ');
      } else if (head == '$statusLabel:') {
        status = _status(info.querySelector('.name')?.text);
      }
    }

    final chapters = <SourceChapter>[];
    for (final li in doc.querySelectorAll('#$_chapterIdSelect > li.chapter-item')) {
      final a = li.querySelector('a');
      final href = a?.attributes['href'];
      final url = absUrl(base, href);
      if (a == null || url == null) continue;
      final name = clean(a.querySelector('.name')?.text ?? a.text);
      chapters.add(SourceChapter(
        url: '$url#${li.attributes['data-id'] ?? ''}',
        name: name,
        number: parseChapterNumber(name),
      ));
    }

    return SourceMangaDetails(
      url: base.toString(),
      title: title,
      thumbnailUrl: _img(root.querySelector('img'), base),
      author: author,
      artist: artist,
      description: description.isEmpty ? null : description,
      genres: [
        for (final a in root.querySelectorAll('.genres > a'))
          if (clean(ownText(a)).isNotEmpty) clean(ownText(a)),
      ],
      status: status,
      chapters: chapters,
    );
  }

  // =========================== Halaman ===========================

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final uri = Uri.parse(chapter.url);
    var chapterId = uri.fragment;
    final chapterPage = uri.replace(fragment: '');
    if (chapterId.isEmpty) {
      final res = await fetchHtml(chapterPage);
      chapterId = res.document.querySelector('div[data-reading-id]')?.attributes['data-reading-id'] ?? '';
      if (chapterId.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('ID bab tidak ditemukan.'));
    }
    final json = await fetchJson(
      Uri.parse('$baseUrl${_ajaxPattern.replaceAll('{id}', chapterId)}'),
      headers: {
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Referer': Uri.encodeComponent(chapterPage.toString()),
        'X-Requested-With': 'XMLHttpRequest',
      },
    );
    return parsePages(asString(asMap(json)['html']) ?? '', chapterPage);
  }

  List<String> parsePages(String html, Uri base) {
    final fragment = html_parser.parseFragment(html);
    final out = <String>[];
    for (final el in fragment.querySelectorAll(_pageSelector)) {
      final url = _img(el, base) ?? _img(el.querySelector('img'), base);
      if (url != null && url.isNotEmpty) out.add(url);
    }
    if (out.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    return out;
  }
}
