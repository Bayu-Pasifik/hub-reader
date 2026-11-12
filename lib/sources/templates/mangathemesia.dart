// Port Dart dari template MangaThemesia (dulu WPMangaStream/WPMangaReader)
// milik keiyoushi/extensions-source, lisensi Apache-2.0:
// https://github.com/keiyoushi/extensions-source/tree/main/lib-multisrc/mangathemesia
//
// Selector & alur dipertahankan; pseudo-selector Jsoup (:contains, :has)
// diganti filter manual karena tidak didukung package:html.

import 'dart:convert';

import 'package:html/dom.dart';

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

/// Tema WordPress komik paling umum di situs Indonesia (29 situs id di
/// keiyoushi). Situs baru cukup:
///
/// ```dart
/// MangaThemesiaSource(id: 'id.xxx', name: 'Xxx', baseUrl: 'https://xxx.com')
/// ```
///
/// atau subclass bila perlu override selector.
class MangaThemesiaSource extends HttpSource {
  MangaThemesiaSource({
    required this.id,
    required this.name,
    required String baseUrl,
    this.lang = 'id',
    this.contentWarning = ContentWarning.safe,
    this.mangaUrlDirectory = '/manga',
    this.requestsPerSecond = 2,
    this.pageSelector = 'div#readerarea img',
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
  final int requestsPerSecond;

  /// Folder daftar seri, mis. "/manga" atau "/komik".
  final String mangaUrlDirectory;
  final String pageSelector;

  // ---------------------------------------------------------------- daftar

  @override
  Future<MangaPage> popular(int page) => _list(page, '', order: 'popular');

  @override
  Future<MangaPage> latest(int page) => _list(page, '', order: 'update');

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) =>
      _list(page, query.trim(), filters: filters);

  /// Parameter sama dengan `searchMangaUrl` di Kotlin:
  /// `title`, `page`, `status`, `type`, `order`, `genre[]`.
  Uri searchUrl(int page, String query, {String? order, FilterValues filters = FilterValues.empty}) {
    final selectedOrder = filters.single('order') ?? order;
    return baseUri.replace(
      path: '$mangaUrlDirectory/',
      queryParameters: <String, dynamic>{
        if (query.isNotEmpty) 'title': query,
        'page': '$page',
        if (filters.single('status') case final status?) 'status': status,
        if (filters.single('type') case final type?) 'type': type,
        if (selectedOrder != null) 'order': selectedOrder,
        if (filters.multi('genre').isNotEmpty) 'genre[]': filters.multi('genre'),
      },
    );
  }

  Future<MangaPage> _list(int page, String query, {String? order, FilterValues filters = FilterValues.empty}) async {
    final res = await fetchHtml(searchUrl(page, query, order: order, filters: filters));
    return parseMangaList(res.document, res.url);
  }

  // ---------------------------------------------------------------- filter

  List<FilterOption>? _genres;

  @override
  Future<List<FilterDef>> filters() async {
    // Daftar genre diambil sekali dari halaman daftar seri (ul.genrez).
    // Bila gagal, filter lain tetap tersedia.
    if (_genres == null) {
      try {
        final res = await fetchHtml(baseUri.replace(path: '$mangaUrlDirectory/'));
        _genres = parseGenres(res.document);
      } on SourceException {
        _genres = null;
      }
    }
    return [
      const SelectFilterDef('order', 'Urutkan', [
        FilterOption('Default', ''),
        FilterOption('Populer', 'popular'),
        FilterOption('Update terbaru', 'update'),
        FilterOption('Baru ditambahkan', 'latest'),
        FilterOption('A-Z', 'title'),
        FilterOption('Z-A', 'titlereverse'),
      ]),
      const SelectFilterDef('status', 'Status', [
        FilterOption('Semua', ''),
        FilterOption('Berjalan', 'ongoing'),
        FilterOption('Tamat', 'completed'),
        FilterOption('Hiatus', 'hiatus'),
        FilterOption('Dihentikan', 'dropped'),
      ]),
      const SelectFilterDef('type', 'Tipe', [
        FilterOption('Semua', ''),
        FilterOption('Manga', 'Manga'),
        FilterOption('Manhwa', 'Manhwa'),
        FilterOption('Manhua', 'Manhua'),
        FilterOption('Comic', 'Comic'),
      ]),
      if (_genres case final genres? when genres.isNotEmpty) MultiSelectFilterDef('genre', 'Genre', genres),
    ];
  }

  List<FilterOption> parseGenres(Document doc) => [
        for (final li in doc.querySelectorAll('ul.genrez li'))
          if (li.querySelector('input[type=checkbox]')?.attributes['value'] case final value?
              when value.isNotEmpty)
            FilterOption(clean(li.querySelector('label')?.text ?? value), value),
      ];

  static const listSelector = '.utao .uta .imgu, .listupd .bs .bsx, .listo .bs .bsx';
  static const nextPageSelector = 'div.pagination .next, div.hpage .r';

  MangaPage parseMangaList(Document doc, Uri pageUrl) {
    final items = <SourceManga>[];
    for (final element in doc.querySelectorAll(listSelector)) {
      final manga = mangaFromElement(element, pageUrl);
      if (manga != null && !items.contains(manga)) items.add(manga);
    }
    return MangaPage(items, hasNextPage: doc.querySelector(nextPageSelector) != null);
  }

  SourceManga? mangaFromElement(Element element, Uri pageUrl) {
    final a = element.querySelector('a');
    final url = attrAbs(a, 'href', pageUrl);
    if (url == null) return null;
    final title = clean(a!.attributes['title']).isNotEmpty
        ? clean(a.attributes['title'])
        : clean(element.querySelector('.tt, .bigor .tt, h2')?.text);
    return SourceManga(
      url: url,
      title: title.isEmpty ? 'Tanpa judul' : title,
      thumbnailUrl: imgAttr(
        element.querySelector('img.ts-post-image') ?? element.querySelector('img'),
        pageUrl,
      ),
    );
  }

  // ---------------------------------------------------------------- detail

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    return parseDetails(res.document, res.url);
  }

  static const detailsSelector = 'div.bigcontent, div.animefull, div.main-info, div.postbody';

  static const _authorLabels = ['author', 'autor', 'mangaka', 'seniman', 'pengarang', 'penulis'];
  static const _artistLabels = ['artist', 'artista', 'ilustrator'];
  static const _statusLabels = ['status'];
  static const _typeLabels = ['type', 'tipe', 'jenis'];
  static const _altLabels = ['alternative', 'alternatif'];

  /// Padanan selector berpola
  /// `.infotable tr:contains(L) td:last-child, .tsinfo .imptdt:contains(L) i, .fmed b:contains(L)+span`.
  String? findLabeled(Element root, List<String> labels) {
    for (final tr in whereContains(root, '.infotable tr', labels)) {
      final tds = tr.querySelectorAll('td');
      if (tds.isNotEmpty) return nonPlaceholder(ownOrFullText(tds.last));
    }
    for (final box in whereContains(root, '.tsinfo .imptdt', labels)) {
      final value = box.querySelector('i') ?? box.querySelector('a');
      if (value != null) return nonPlaceholder(ownOrFullText(value));
    }
    for (final b in whereContains(root, '.fmed b', labels)) {
      final span = b.nextElementSibling;
      if (span != null && span.localName == 'span') {
        return nonPlaceholder(ownOrFullText(span));
      }
    }
    return null;
  }

  SourceMangaDetails parseDetails(Document doc, Uri pageUrl) {
    final root = doc.querySelector(detailsSelector) ?? doc.body;
    if (root == null) {
      throw const SourceException(SourceErrorKind.parse, detail: 'Halaman seri kosong.');
    }

    final title = clean(root.querySelector('.entry-title')?.text).isNotEmpty
        ? clean(root.querySelector('.entry-title')!.text)
        : clean(root.querySelectorAll('.ts-breadcrumb li').lastOrNull?.text);
    if (title.isEmpty) {
      throw const SourceException(
        SourceErrorKind.parse,
        detail: 'Judul seri tidak ditemukan; mungkin bukan halaman seri.',
      );
    }

    final descElement = root.querySelector('.desc, .entry-content[itemprop=description]');
    final paragraphs = descElement
            ?.querySelectorAll('p')
            .map((p) => clean(p.text))
            .where((t) => t.isNotEmpty)
            .toList() ??
        const <String>[];
    var description = paragraphs.isNotEmpty
        ? paragraphs.join('\n\n')
        : nonPlaceholder(descElement?.text);

    final altElement = root.querySelector('.alternative, .alter, .seriestualt');
    final altNames = altElement != null ? ownOrFullText(altElement) : findLabeled(root, _altLabels);
    if (altNames != null && altNames.isNotEmpty) {
      final names = altNames
          .split(RegExp(r'[|/•,;]'))
          .map((n) => n.trim())
          .where((n) => n.isNotEmpty)
          .map((n) => '- $n')
          .join('\n');
      description = [if (description != null) description, 'Judul alternatif:\n$names'].join('\n\n');
    }

    final genres = <String>{
      for (final a in root.querySelectorAll('div.gnr a, .mgen a, .seriestugenre a'))
        if (clean(a.text).isNotEmpty) clean(a.text),
    };
    final type = findLabeled(root, _typeLabels);
    if (type != null) genres.add(type);

    return SourceMangaDetails(
      url: pageUrl.toString(),
      title: title,
      thumbnailUrl: imgAttr(
        root.querySelector('.infomanga > div[itemprop=image] img, .thumb img'),
        pageUrl,
      ),
      author: findLabeled(root, _authorLabels),
      artist: findLabeled(root, _artistLabels),
      description: description,
      genres: genres.map(_titleCase).toList(),
      status: parseStatus(findLabeled(root, _statusLabels)),
      chapters: parseChapters(doc, pageUrl),
    );
  }

  static String _titleCase(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ----------------------------------------------------------------- bab

  List<SourceChapter> parseChapters(Document doc, Uri pageUrl) {
    var rows = doc.querySelectorAll('div.bxcl li, div.cl li, #chapterlist li');
    if (rows.isEmpty) {
      // Padanan `ul li:has(div.chbox):has(div.eph-num)`
      rows = doc
          .querySelectorAll('ul li')
          .where((li) => li.querySelector('div.chbox') != null && li.querySelector('div.eph-num') != null)
          .toList();
    }

    final seen = <String>{};
    final chapters = <SourceChapter>[];
    for (final li in rows) {
      final a = li.querySelector('a');
      final url = attrAbs(a, 'href', pageUrl);
      if (url == null || !seen.add(url)) continue;
      final label = clean(li.querySelector('.lch a, .chapternum')?.text);
      final name = label.isNotEmpty ? label : clean(a!.text);
      chapters.add(SourceChapter(
        url: url,
        name: name.isEmpty ? 'Bab' : name,
        number: double.tryParse(li.attributes['data-num'] ?? '') ?? parseChapterNumber(name),
        uploadedAt: parseLooseDate(li.querySelector('.chapterdate')?.text),
      ));
    }
    return chapters;
  }

  // ------------------------------------------------------------- halaman

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    final pages = parsePages(res.document, res.body, res.url);
    if (pages.isEmpty) {
      throw const SourceException(
        SourceErrorKind.parse,
        detail: 'Gambar bab tidak ditemukan. Bab mungkin terkunci atau format situs berubah.',
      );
    }
    return pages;
  }

  static final jsonImageList =
      RegExp(r'''["']?(?:images|imageUrls)["']?\s*[:=]\s*(\[.*?\])''');

  /// base64 dari "ts_reader.run({"
  static const _tsReaderPrefix = 'data:text/javascript;base64,dHNfcmVhZGVyLnJ1bih7';

  List<String> parsePages(Document doc, String body, Uri pageUrl) {
    final htmlPages = doc
        .querySelectorAll(pageSelector)
        .where((img) => img.parent?.localName != 'noscript')
        .map((img) => imgAttr(img, pageUrl))
        .whereType<String>()
        .toList();
    if (htmlPages.isNotEmpty) return htmlPages;

    // Sebagian situs memuat gambar lewat JavaScript ts_reader.
    var script = body;
    for (final s in doc.querySelectorAll('script[src]')) {
      final src = s.attributes['src'] ?? '';
      if (src.startsWith(_tsReaderPrefix)) {
        try {
          final encoded = src.substring(src.indexOf('base64,') + 7);
          script = utf8.decode(base64.decode(base64.normalize(encoded)));
        } on FormatException {
          // tetap pakai body
        }
        break;
      }
    }

    final json = jsonImageList.firstMatch(script)?.group(1);
    if (json == null) return const [];
    try {
      final list = jsonDecode(json);
      if (list is! List) return const [];
      return list
          .whereType<String>()
          .map((u) => absUrl(pageUrl, u))
          .whereType<String>()
          .toList();
    } on FormatException {
      return const [];
    }
  }
}
