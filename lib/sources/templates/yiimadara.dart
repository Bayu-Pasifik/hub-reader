// Port Dart dari template YiiMadara milik keiyoushi/extensions-source
// (Apache-2.0): lib-multisrc/yiimadara.
//
// Situs Yii2 yang meniru markup Madara: daftar `div.page-item`, detail
// `.post-title h1`, bab `ul.row-content-chapter`, gambar `.read-content img`.
// Beda antar situs: jalur katalog, pagination, parameter cari, dan entri "raw".

import 'package:html/dom.dart';

import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';
import '../../core/i18n/strings.dart';
import 'yiimanga.dart' show YiimangaSource;

class YiiMadaraSource extends HttpSource {
  YiiMadaraSource({
    required this.id,
    required this.name,
    required String baseUrl,
    required this.lang,
    this.contentWarning = ContentWarning.safe,
    this.vals = const {},
    this.genreList = const [],
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

  /// Override sederhana dari Kotlin (`pageSegment`, `searchParam`, dst).
  final JsonMap vals;

  /// Genre tetap dari Kotlin (situs tanpa tautan genre): [nama, jalur].
  final List<(String, String)> genreList;

  /// Jalur katalog urut `?orderby=`; null bila situs tidak punya.
  String? get directoryPath {
    if (vals.containsKey('directoryPath')) {
      final byLang = asString(vals['directoryPath$lang']);
      if (byLang != null) return byLang;
      final v = asString(vals['directoryPath']);
      return v == null || v.isEmpty ? null : v;
    }
    return 'manga';
  }

  bool get pageSegment => vals['pageSegment'] == true;
  bool get trailingSlash => vals['trailingSlash'] == true;
  String get searchParam => asString(vals['searchParam']) ?? 'q';
  String? get completedPath => vals.containsKey('completedPath') ? asString(vals['completedPath']) : 'completed';
  String? get rawPath => asString(vals['rawPath']);

  /// "show" | "hide" | "only": entri tanpa terjemahan di dalam daftar.
  String get rawEntries =>
      asString(vals['rawEntries']) ??
      switch (lang) {
        'en' => 'hide',
        'ko' => 'only',
        _ => 'show',
      };

  /// manga18fx: populer = /hot-manga?page=N, terbaru = /page/N.
  bool get hotMangaPopular => vals['hotMangaPopular'] == true;

  static const sortOptions = [
    FilterOption('Default', ''),
    FilterOption('Trending', 'trending'),
    FilterOption('Newest', 'latest'),
    FilterOption('Rating', 'rating'),
    FilterOption('A-Z', 'alphabet'),
  ];

  // =========================== Daftar ===========================

  Uri _listUrl(String path, int page, {Map<String, String>? query}) {
    final segments = [
      ...path.split('/').where((s) => s.isNotEmpty),
      if (pageSegment) 'page',
      '$page',
      if (trailingSlash) '',
    ];
    return Uri.parse(baseUrl).replace(pathSegments: segments, queryParameters: query);
  }

  @override
  Future<MangaPage> popular(int page) {
    if (hotMangaPopular) {
      return _fetchList(Uri.parse('$baseUrl/hot-manga').replace(queryParameters: {'page': '$page'}));
    }
    return _directory(page, 'trending');
  }

  @override
  Future<MangaPage> latest(int page) {
    if (hotMangaPopular) return _fetchList(_listUrl('page', page).replace(queryParameters: null));
    return _directory(page, null);
  }

  Future<MangaPage> _directory(int page, String? order) {
    final path = directoryPath;
    if (path == null) return _fetchList(_listUrl('', page));
    return _fetchList(_listUrl(path, page, query: order == null ? null : {'orderby': order}), rawListing: path == rawPath);
  }

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) {
    final text = query.trim();
    if (text.isNotEmpty) {
      return _fetchList(Uri.parse(baseUrl).replace(
        pathSegments: ['search', if (trailingSlash) ''],
        // Pencarian gagal HTTP 500 pada apostrof ASCII.
        queryParameters: {searchParam: text.replaceAll("'", '’'), 'page': '$page'},
      ));
    }
    final genre = filters.single('genre');
    final category = filters.single('category');
    final path = (genre != null && genre.isNotEmpty)
        ? genre
        : (category != null && category.isNotEmpty)
            ? category
            : directoryPath;
    if (path == null) return latest(page);
    final sort = filters.single('sort');
    return _fetchList(_listUrl(path, page, query: sort == null || sort.isEmpty ? null : {'orderby': sort}),
        rawListing: path == rawPath);
  }

  Future<MangaPage> _fetchList(Uri url, {bool rawListing = false}) async {
    final res = await fetchHtml(url);
    return parseList(res.document, res.url, rawListing: rawListing);
  }

  MangaPage parseList(Document doc, Uri base, {bool rawListing = false}) {
    final items = <SourceManga>[];
    for (final el in doc.querySelectorAll('div.page-item, div.page-item-detail, div.home-item, div.manga-item')) {
      final link = el.querySelector('h3 a');
      final url = absUrl(base, link?.attributes['href']);
      final title = clean(link?.text);
      if (url == null || title.isEmpty) continue;
      items.add(SourceManga(url: url, title: title, thumbnailUrl: _img(el.querySelector('img'), base)));
    }
    return MangaPage(_filterRaw(items, rawListing), hasNextPage: doc.querySelector('#blog-pager li.next a') != null);
  }

  String? _img(Element? img, Uri base) {
    if (img == null) return null;
    final lazy = absUrl(base, img.attributes['data-src']);
    if (lazy != null && lazy.isNotEmpty) return lazy;
    return absUrl(base, img.attributes['src']);
  }

  List<SourceManga> _filterRaw(List<SourceManga> items, bool rawListing) {
    if (rawListing || rawEntries == 'show') return items;
    bool isRaw(SourceManga m) {
      final path = m.url.endsWith('/') ? m.url.substring(0, m.url.length - 1) : m.url;
      return path.endsWith('-raw') || m.title.toLowerCase().endsWith(' raw');
    }

    return [
      for (final m in items)
        if (rawEntries == 'only' ? isRaw(m) : !isRaw(m)) m,
    ];
  }

  // =========================== Filter ===========================

  @override
  Future<List<FilterDef>> filters() async {
    var genres = genreList.map((g) => FilterOption(g.$1, g.$2)).toList();
    if (genres.isEmpty && vals['supportsFilterFetching'] != false) {
      try {
        final res = await fetchHtml(Uri.parse(baseUrl));
        genres = parseGenres(res.document, res.url);
      } catch (_) {
        // Filter genre dilewati.
      }
    }
    final categories = [
      if (completedPath != null) FilterOption('Completed', completedPath!),
      if (rawPath != null) FilterOption('Raw', rawPath!),
    ];
    return [
      if (genres.isNotEmpty) SelectFilterDef('genre', 'Genre', [const FilterOption('All', ''), ...genres]),
      if (categories.isNotEmpty) SelectFilterDef('category', 'Category', [const FilterOption('All', ''), ...categories]),
      const SelectFilterDef('sort', 'Sort by', sortOptions),
    ];
  }

  List<FilterOption> parseGenres(Document doc, Uri base) {
    final seen = <String>{};
    final out = <FilterOption>[];
    for (final a in doc.querySelectorAll('a[href*="genre/"]')) {
      final url = absUrl(base, a.attributes['href']);
      if (url == null) continue;
      final path = Uri.parse(url).path.replaceAll(RegExp(r'^/+|/+$'), '');
      final label = clean(a.text);
      if (label.isEmpty || !seen.add(path)) continue;
      out.add(FilterOption(label, path));
    }
    out.sort((a, b) => a.label.compareTo(b.label));
    return out;
  }

  // =========================== Detail ===========================

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    return parseDetails(res.document, res.url);
  }

  /// Nilai baris info menurut label: pasangan .summary-heading/.summary-content,
  /// `<b>` + nilai, atau `.minfo` dengan nilai di `<i>`.
  List<Element>? _info(Document doc, String label) {
    for (final item in doc.querySelectorAll('.post-content_item')) {
      final head = item.children.where((c) => c.classes.contains('summary-heading') || c.localName == 'b').firstOrNull;
      if (head == null || !clean(head.text).toLowerCase().startsWith(label.toLowerCase())) continue;
      final content = item.children.where((c) => c.classes.contains('summary-content')).toList();
      return content.isNotEmpty ? content : item.children.where((c) => c.localName != 'b').toList();
    }
    for (final m in doc.querySelectorAll('.minfo')) {
      if (ownText(m).trim().toLowerCase().startsWith(label.toLowerCase())) {
        return m.children.where((c) => c.localName == 'i').toList();
      }
    }
    return null;
  }

  static String? _value(List<Element>? els) {
    if (els == null) return null;
    final text = clean(els.map((e) => e.text).join(' '));
    return text.isEmpty || text == 'Updating' || text == 'N/A' ? null : text;
  }

  static String? _names(List<Element>? els) {
    if (els == null) return null;
    final links = [for (final e in els) ...e.querySelectorAll('a')];
    final names = links.isEmpty ? [_value(els)] : links.map((a) => clean(a.text)).toList();
    final joined = names.whereType<String>().where((n) => n.isNotEmpty && n != 'Updating').join(', ');
    return joined.isEmpty ? null : joined;
  }

  SourceMangaDetails parseDetails(Document doc, Uri base) {
    final heading = doc.querySelector('.post-title h1');
    // Sebagian situs menaruh lencana "18+" di dalam judul.
    final title = clean(heading == null ? null : (ownText(heading).isEmpty ? heading.text : ownText(heading)));
    if (title.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Judul seri tidak ditemukan.'));
    final block = doc.querySelector('.dsct, .ss-manga, .post-content_item .entry-content');
    var synopsis = '';
    if (block != null) {
      final ps = block.querySelectorAll('p').map((p) => clean(p.text)).where((t) => t.isNotEmpty).toList();
      synopsis = (ps.isEmpty ? [clean(block.text)] : ps).where((t) => t.isNotEmpty).join('\n\n');
    }
    final alt = _value(_info(doc, 'Alternative'));
    final description = [if (synopsis.isNotEmpty) synopsis, if (alt != null) 'Alternative names: $alt'].join('\n\n');
    final genres = [_names(_info(doc, 'Genre')), _value(_info(doc, 'Type'))].whereType<String>().join(', ');
    return SourceMangaDetails(
      url: base.toString(),
      title: title,
      thumbnailUrl: _img(doc.querySelector('.summary_image img'), base),
      author: _names(_info(doc, 'Author')),
      artist: _names(_info(doc, 'Artist')),
      description: description.isEmpty ? null : description,
      genres: genres.split(',').map((g) => g.trim()).where((g) => g.isNotEmpty).toList(),
      status: switch (clean(_info(doc, 'Status')?.map((e) => e.text).join(' ')).toLowerCase()) {
        'ongoing' => SourceMangaStatus.ongoing,
        'completed' => SourceMangaStatus.completed,
        _ => SourceMangaStatus.unknown,
      },
      chapters: parseChapters(doc, base),
    );
  }

  List<SourceChapter> parseChapters(Document doc, Uri base) {
    final out = <SourceChapter>[];
    for (final li in doc.querySelectorAll('ul.row-content-chapter li')) {
      final link = li.querySelector('a');
      final url = absUrl(base, link?.attributes['href']);
      final name = clean(link?.text);
      if (url == null || name.isEmpty) continue;
      out.add(SourceChapter(
        url: url,
        name: name,
        number: parseChapterNumber(name),
        uploadedAt: YiimangaSource.parseShortDate(li.querySelector('.chapter-time')?.text),
      ));
    }
    return out;
  }

  // =========================== Halaman ===========================

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    return parsePages(res.document, res.url);
  }

  List<String> parsePages(Document doc, Uri base) => [
        for (final img in doc.querySelectorAll('.read-content img'))
          if (_img(img, base) case final url?) url,
      ];
}
