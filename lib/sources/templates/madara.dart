// Port Dart dari template Madara (MadaraBase, Madara, MadaraNoAjax) milik
// keiyoushi/extensions-source, lisensi Apache-2.0:
// https://github.com/keiyoushi/extensions-source/tree/main/lib-multisrc/madara
//
// Madara adalah tema WordPress "WP Manga" yang dipakai ratusan situs di banyak
// bahasa. Pseudo-selector Jsoup (:contains, :has) diganti filter manual.

import 'dart:convert';
import 'dart:typed_data';

import 'package:html/dom.dart';
import 'package:pointycastle/export.dart';

import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

/// Cara situs Madara menyajikan daftar bab (sama dengan enum di Kotlin).
enum MadaraChapterMode { mangaPage, adminAjax, mangaAjax, mangaAjaxPaginated, mangaAjaxQuery }

MadaraChapterMode madaraChapterModeFrom(String? name) => switch (name) {
      'AdminAjax' => MadaraChapterMode.adminAjax,
      'MangaAjax' => MadaraChapterMode.mangaAjax,
      'MangaAjaxPaginated' => MadaraChapterMode.mangaAjaxPaginated,
      'MangaAjaxQuery' => MadaraChapterMode.mangaAjaxQuery,
      _ => MadaraChapterMode.mangaPage,
    };

class MadaraSource extends HttpSource {
  MadaraSource({
    required this.id,
    required this.name,
    required String baseUrl,
    required this.lang,
    this.contentWarning = ContentWarning.safe,
    this.mangaSubString = 'manga',
    this.chapterMode = MadaraChapterMode.mangaPage,
    this.noAjax = false,
    this.filterNonMangaItems = true,
    this.requestsPerSecond = 2,
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
  @override
  final int requestsPerSecond;

  final String mangaSubString;
  final MadaraChapterMode chapterMode;

  /// Situs turunan MadaraNoAjax: daftar dari halaman arsip HTML biasa.
  final bool noAjax;
  final bool filterNonMangaItems;

  /// Override selector/teks dari Kotlin situs (`override val x = "..."`),
  /// disalin generator katalog ke `options.vals`.
  final Map<String, Object?> vals;

  /// Selector override [key] bila bisa dipakai parser Dart. Pseudo khusus
  /// Jsoup (:contains, :has, :eq, ...) diabaikan; default yang dipakai.
  String? sel(String key) {
    final value = vals[key];
    if (value is! String || value.trim().isEmpty) return null;
    if (_jsoupOnly.hasMatch(value)) return null;
    return value;
  }

  static final _jsoupOnly =
      RegExp(r':(contains|containsOwn|has|eq|gt|lt|matches|matchesOwn|containsData|parent|lastOfType)\b');

  /// querySelector yang tidak melempar untuk selector tak didukung.
  static Element? _first(Node root, String? selector) {
    if (selector == null) return null;
    try {
      return root is Document ? root.querySelector(selector) : (root as Element).querySelector(selector);
    } catch (_) {
      return null;
    }
  }

  static List<Element> _all(Node root, String? selector) {
    if (selector == null) return const [];
    try {
      return root is Document ? root.querySelectorAll(selector) : (root as Element).querySelectorAll(selector);
    } catch (_) {
      return const [];
    }
  }

  String get _searchParam => (vals['searchQueryParameter'] as String?) ?? 's';

  static const pageSize = 25;
  static const _xhr = {'X-Requested-With': 'XMLHttpRequest'};

  Uri get _ajaxUrl => Uri.parse('$baseUrl/wp-admin/admin-ajax.php');

  // ---------------------------------------------------------------- daftar

  @override
  Future<MangaPage> popular(int page) =>
      noAjax ? _archivePage(page, order: 'views') : _ajaxList(page, sortKey: '_wp_manga_views');

  @override
  Future<MangaPage> latest(int page) =>
      noAjax ? _archivePage(page, order: 'latest') : _ajaxList(page, sortKey: '_latest_update');

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) {
    if (!noAjax) return _ajaxList(page, query: query, filters: filters, search: true);
    final order = filters.single('order') ?? '';
    final genrePath = filters.single('genre');
    if (genrePath != null) return _archivePage(page, order: order, path: genrePath, query: query);
    return query.trim().isEmpty ? _archivePage(page, order: order) : _htmlSearch(page, query.trim());
  }

  /// Form `madara_load_more`, sama persis dengan `Madara.ajaxList` di Kotlin.
  Map<String, String> ajaxForm(int page, {String? sortKey, String query = '', FilterValues filters = FilterValues.empty, bool search = false}) {
    final form = <String, String>{
      'action': 'madara_load_more',
      'page': '${page - 1}',
      'template': 'madara-core/content/content-archive',
      'vars[paged]': '1',
      'vars[template]': 'archive',
      'vars[posts_per_page]': '$pageSize',
      'vars[post_type]': 'wp-manga',
      'vars[post_status]': 'publish',
      'vars[manga_archives_item_layout]': 'big_thumbnail',
    };
    var meta = 0;
    if (filterNonMangaItems) {
      form['vars[meta_query][0][key]'] = '_wp_manga_chapter_type';
      form['vars[meta_query][0][value]'] = 'manga';
      meta = 1;
    }
    void sortBy(String key) {
      form['vars[orderby]'] = 'meta_value_num';
      form['vars[meta_key]'] = key;
      form['vars[order]'] = 'DESC';
    }

    if (!search) {
      sortBy(sortKey!);
      return form;
    }
    if (query.trim().isNotEmpty) form['vars[s]'] = query.trim();

    final statuses = filters.multi('status');
    if (statuses.isNotEmpty) {
      form['vars[meta_query][$meta][key]'] = '_wp_manga_status';
      form['vars[meta_query][$meta][compare]'] = 'IN';
      for (var i = 0; i < statuses.length; i++) {
        form['vars[meta_query][$meta][value][$i]'] = statuses[i];
      }
      meta++;
    }
    switch (filters.single('order')) {
      case 'latest':
        sortBy('_latest_update');
      case 'alphabet':
        form['vars[orderby]'] = 'post_title';
        form['vars[order]'] = 'ASC';
      case 'rating':
        form['vars[meta_query][query_average_reviews][key]'] = '_manga_avarage_reviews';
        form['vars[meta_query][query_average_reviews][compare]'] = 'EXISTS';
        form['vars[meta_query][query_total_reviews][key]'] = '_manga_total_votes';
        form['vars[meta_query][query_total_reviews][compare]'] = 'EXISTS';
        form['vars[orderby][query_average_reviews]'] = 'DESC';
        form['vars[orderby][query_total_reviews]'] = 'DESC';
      case 'trending':
        sortBy('_wp_manga_week_views_value');
      case 'views':
        sortBy('_wp_manga_views');
      case 'new-manga':
        form['vars[orderby]'] = 'date';
        form['vars[order]'] = 'DESC';
    }
    final adult = filters.single('adult');
    if (adult != null) {
      form['vars[meta_query][$meta][key]'] = 'manga_adult_content';
      form['vars[meta_query][$meta][compare]'] = adult == '0' ? 'not exists' : 'exists';
      meta++;
    }
    final genres = filters.multi('genre');
    if (genres.isNotEmpty) {
      form['vars[tax_query][0][taxonomy]'] = 'wp-manga-genre';
      form['vars[tax_query][0][field]'] = 'slug';
      for (var i = 0; i < genres.length; i++) {
        form['vars[tax_query][0][terms][$i]'] = genres[i];
      }
      if (filters.single('genre_and') == '1') form['vars[tax_query][0][operation]'] = 'AND';
    }
    return form;
  }

  Future<MangaPage> _ajaxList(int page, {String? sortKey, String query = '', FilterValues filters = FilterValues.empty, bool search = false}) async {
    final res = await postHtml(
      _ajaxUrl,
      ajaxForm(page, sortKey: sortKey, query: query, filters: filters, search: search),
      headers: _xhr,
    );
    final items = parseArchive(res.document, res.url);
    return MangaPage(items, hasNextPage: items.length >= pageSize);
  }

  static const archiveSelector = 'div.page-item-detail, .manga__item, .c-tabs-item__content';
  static const _nextPageSelector = 'div.nav-previous, a.nextpostslink, #navigation-ajax';

  List<SourceManga> parseArchive(Document doc, Uri pageUrl) {
    final items = <SourceManga>[];
    final urlSelector = sel('archiveUrlSelector');
    for (final element in doc.querySelectorAll(archiveSelector)) {
      final link = _first(element, urlSelector) ?? element.querySelector('.post-title a');
      final url = attrAbs(link, 'href', pageUrl);
      if (url == null) continue;
      final manga = SourceManga(
        url: url,
        title: clean(link!.text).isEmpty ? 'Tanpa judul' : clean(link.text),
        thumbnailUrl: madaraImage(element.querySelector('img'), pageUrl),
      );
      if (!items.contains(manga)) items.add(manga);
    }
    // Kartu arsip kustom (mis. Aqua Manga): ambil tautannya langsung, sampul
    // dari leluhur terdekat yang punya gambar.
    if (items.isEmpty && urlSelector != null) {
      for (final link in _all(doc, urlSelector)) {
        final url = attrAbs(link, 'href', pageUrl);
        if (url == null) continue;
        Element? card = link;
        Element? img;
        for (var i = 0; i < 5 && card != null && img == null; i++) {
          img = card.querySelector('img');
          card = card.parent;
        }
        final manga = SourceManga(
          url: url,
          title: clean(link.text).isEmpty ? (link.attributes['title'] ?? 'Tanpa judul') : clean(link.text),
          thumbnailUrl: madaraImage(img, pageUrl),
        );
        if (!items.contains(manga)) items.add(manga);
      }
    }
    return items;
  }

  Future<MangaPage> _archivePage(int page, {required String order, String? path, String query = ''}) async {
    final base = Uri.parse(baseUrl).resolve(path ?? '/$mangaSubString/');
    final url = base.replace(
      path: page > 1 ? '${base.path.replaceFirst(RegExp(r'/?$'), '/')}page/$page/' : base.path,
      queryParameters: {
        if (order.isNotEmpty) 'm_orderby': order,
        if (query.trim().isNotEmpty) _searchParam: query.trim(),
      },
    );
    final res = await fetchHtml(url);
    return MangaPage(
      parseArchive(res.document, res.url),
      hasNextPage: res.document.querySelector(_nextPageSelector) != null,
    );
  }

  Future<MangaPage> _htmlSearch(int page, String query) async {
    final url = Uri.parse(baseUrl).replace(
      path: page > 1 ? '/page/$page/' : '/',
      queryParameters: {_searchParam: query, 'post_type': 'wp-manga'},
    );
    final res = await fetchHtml(url);
    return MangaPage(
      parseArchive(res.document, res.url),
      hasNextPage: res.document.querySelector(_nextPageSelector) != null,
    );
  }

  // ---------------------------------------------------------------- filter

  List<FilterOption>? _genres;

  @override
  Future<List<FilterDef>> filters() async {
    if (_genres == null) {
      try {
        final res = await fetchHtml(Uri.parse('$baseUrl/$mangaSubString/'));
        _genres = parseGenres(res.document, res.url, asPath: noAjax);
      } on SourceException {
        _genres = null;
      }
    }
    final genres = _genres ?? const <FilterOption>[];
    const order = SelectFilterDef('order', 'Urutkan', [
      FilterOption('Relevansi', ''),
      FilterOption('Terbaru', 'latest'),
      FilterOption('A-Z', 'alphabet'),
      FilterOption('Rating', 'rating'),
      FilterOption('Trending', 'trending'),
      FilterOption('Paling dilihat', 'views'),
      FilterOption('Baru ditambahkan', 'new-manga'),
    ]);
    if (noAjax) {
      return [
        order,
        if (genres.isNotEmpty) SelectFilterDef('genre', 'Genre', [const FilterOption('Semua', ''), ...genres]),
      ];
    }
    return [
      order,
      const MultiSelectFilterDef('status', 'Status', [
        FilterOption('Tamat', 'end'),
        FilterOption('Berjalan', 'on-going'),
        FilterOption('Dibatalkan', 'canceled'),
        FilterOption('Ditunda', 'on-hold'),
      ]),
      const SelectFilterDef('adult', 'Konten dewasa', [
        FilterOption('Semua', ''),
        FilterOption('Tanpa konten dewasa', '0'),
        FilterOption('Hanya dewasa', '1'),
      ]),
      if (genres.isNotEmpty) ...[
        const SelectFilterDef('genre_and', 'Kondisi genre', [
          FilterOption('Salah satu (OR)', ''),
          FilterOption('Semua (AND)', '1'),
        ]),
        MultiSelectFilterDef('genre', 'Genre', genres),
      ],
    ];
  }

  /// Genre dari `div.genres a[href*='/manga-genre/']`. Untuk mode non-AJAX
  /// nilai filter = path arsip genre, selain itu = slug.
  List<FilterOption> parseGenres(Document doc, Uri pageUrl, {bool asPath = false}) {
    final seen = <String>{};
    final result = <FilterOption>[];
    for (final a in doc.querySelectorAll('div.genres a')) {
      final href = attrAbs(a, 'href', pageUrl);
      if (href == null || !href.contains('/${(vals['genreDirectory'] as String?) ?? 'manga-genre'}/')) continue;
      final path = Uri.parse(href).path;
      final slug = path.split('/').where((s) => s.isNotEmpty).lastOrNull;
      final label = clean(a.text);
      if (slug == null || label.isEmpty || !seen.add(slug)) continue;
      result.add(FilterOption(label, asPath ? path : slug));
    }
    return result;
  }

  // ---------------------------------------------------------------- detail

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final requested = Uri.parse(mangaUrl);
    final res = await fetchHtml(requested);
    if (res.url.path.contains('wp-login.php')) {
      throw const SourceException(SourceErrorKind.parse,
          detail: 'Situs ini wajib login untuk membuka seri. Login lewat "Buka di WebView".');
    }
    // Dialihkan ke beranda: seri dihapus/pindah (sering terjadi di situs satu judul).
    if (res.url.path.replaceAll('/', '').isEmpty && requested.path.replaceAll('/', '').isNotEmpty) {
      throw SourceException(SourceErrorKind.notFound, url: requested);
    }
    final details = parseDetails(res.document, res.url);
    final chapters = await _chapters(res.document, res.url);
    return SourceMangaDetails(
      url: details.url,
      title: details.title,
      thumbnailUrl: details.thumbnailUrl,
      author: details.author,
      artist: details.artist,
      description: details.description,
      genres: details.genres,
      status: details.status,
      chapters: chapters,
    );
  }

  static final _updating = RegExp('Updating|Atualizando', caseSensitive: false);

  String? _joined(Document doc, String selector) {
    final names = doc
        .querySelectorAll(selector)
        .map((e) => clean(e.text))
        .where((t) => t.isNotEmpty && !_updating.hasMatch(t))
        .toList();
    return names.isEmpty ? null : names.join(', ');
  }

  /// Nilai `.summary-content` dari `.post-content_item` yang judulnya memuat [labels].
  String? _infoItem(Document doc, List<String> labels) {
    for (final item in whereContains(doc.documentElement!, '.post-content_item', labels)) {
      final value = item.querySelector('.summary-content');
      if (value != null) return nonPlaceholder(ownOrFullText(value));
    }
    return null;
  }

  /// `og:title` tanpa akhiran nama situs ("Judul - Situs" / "Judul – Situs").
  static String _ogTitle(Document doc) {
    final og = clean(doc.querySelector('meta[property="og:title"]')?.attributes['content']);
    final site = clean(doc.querySelector('meta[property="og:site_name"]')?.attributes['content']);
    if (site.isEmpty) return og;
    for (final sep in const [' - ', ' – ', ' | ']) {
      if (og.endsWith('$sep$site')) return og.substring(0, og.length - sep.length - site.length).trim();
    }
    return og == site ? '' : og;
  }

  static Element? _imgOf(Element? el) => el == null ? null : (el.localName == 'img' ? el : el.querySelector('img'));

  String? _joinedOverride(Document doc, String key) {
    final selector = sel(key);
    if (selector == null) return null;
    try {
      return _joined(doc, selector);
    } catch (_) {
      return null;
    }
  }

  SourceMangaStatus? _statusOverride(Document doc) {
    final status = madaraStatus(_all(doc, sel('mangaDetailsSelectorStatus')).lastOrNull?.text);
    return status == SourceMangaStatus.unknown ? null : status;
  }

  /// Detail tanpa daftar bab (dipisah supaya bisa dites tanpa jaringan).
  SourceMangaDetails parseDetails(Document doc, Uri pageUrl) {
    final titleEl = _first(doc, sel('mangaDetailsSelectorTitle')) ??
        doc.querySelector('div.post-title h3, div.post-title h1, #manga-title > h1');
    var title = titleEl == null ? '' : ownOrFullText(titleEl);
    // Tema turunan (mis. Toonizy, ManhwaToon) memindah judul; og:title tetap ada.
    if (title.isEmpty) title = _ogTitle(doc);
    if (title.isEmpty) {
      throw const SourceException(SourceErrorKind.parse, detail: 'Judul seri tidak ditemukan.');
    }

    final descEl = _first(doc, sel('mangaDetailsSelectorDescription')) ?? doc.querySelector(
      'div.description-summary div.summary__content, '
      'div.summary_content div.post-content_item > h5 + div, '
      'div.summary_content div.manga-excerpt',
    );
    final paragraphs = descEl?.querySelectorAll('p').map((p) => clean(p.text)).where((t) => t.isNotEmpty).toList() ?? const [];
    var description = paragraphs.isNotEmpty ? paragraphs.join('\n\n') : nonPlaceholder(descEl?.text);
    final alt = _infoItem(doc, const ['Alt']);
    if (alt != null && !_updating.hasMatch(alt)) {
      description = [if (description != null) description, 'Judul alternatif: $alt'].join('\n\n');
    }

    final genreSelector = [sel('mangaDetailsSelectorGenre'), sel('mangaDetailsSelectorTag')].nonNulls.join(', ');
    final genres = <String>{
      for (final a in [
        ..._all(doc, genreSelector.isEmpty ? null : genreSelector),
        ...doc.querySelectorAll('div.genres-content a, div.tags-content a'),
      ])
        if (clean(a.text).isNotEmpty) clean(a.text),
    };
    if (_infoItem(doc, const ['Type']) case final type?) genres.add(type);

    return SourceMangaDetails(
      url: pageUrl.toString(),
      title: title,
      thumbnailUrl: madaraImage(
          _imgOf(_first(doc, sel('mangaDetailsSelectorThumbnail'))) ?? doc.querySelector('div.summary_image img'),
          pageUrl),
      author: _joinedOverride(doc, 'mangaDetailsSelectorAuthor') ??
          _joined(doc, 'div.author-content > a, div.manga-authors > a'),
      artist: _joinedOverride(doc, 'mangaDetailsSelectorArtist') ?? _joined(doc, 'div.artist-content > a'),
      description: description,
      genres: genres.toList(),
      status: _statusOverride(doc) ?? madaraStatus(doc.querySelectorAll('div.summary-content').lastOrNull?.text),
    );
  }

  // ----------------------------------------------------------------- bab

  /// ID post WordPress (untuk mode AdminAjax).
  static String? mangaId(Document doc) {
    String? nonEmpty(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
    final holder = doc.querySelectorAll('[id]').where((e) => e.id.startsWith('manga-chapters-holder')).firstOrNull;
    return nonEmpty(holder?.attributes['data-id']) ??
        nonEmpty(doc.querySelector('input.rating-post-id')?.attributes['value']) ??
        nonEmpty(doc.querySelector('a[data-post]')?.attributes['data-post']) ??
        nonEmpty(RegExp(r'\?p=(\d+)').firstMatch(doc.querySelector('link[rel=shortlink]')?.attributes['href'] ?? '')?.group(1));
  }

  Future<List<SourceChapter>> _chapters(Document page, Uri pageUrl) async {
    final fromPage = parseChapters(page, pageUrl);
    if (chapterMode == MadaraChapterMode.mangaPage && fromPage.isNotEmpty) return fromPage;

    final mangaPath = pageUrl.path.replaceFirst(RegExp(r'/+$'), '');
    final ajaxBase = pageUrl.replace(path: '$mangaPath/ajax/chapters/', query: '');
    final referer = {..._xhr, 'Referer': pageUrl.toString()};
    try {
      switch (chapterMode) {
        case MadaraChapterMode.adminAjax:
          final id = mangaId(page);
          if (id != null) {
            final res = await postHtml(_ajaxUrl, {'action': 'manga_get_chapters', 'manga': id}, headers: referer);
            final list = parseChapters(res.document, pageUrl);
            if (list.isNotEmpty) return list;
          }
        case MadaraChapterMode.mangaAjaxPaginated:
          final all = <SourceChapter>[];
          for (var t = 1; t <= 50; t++) {
            final res = await postHtml(ajaxBase.replace(queryParameters: {'t': '$t'}), const {}, headers: referer);
            final list = parseChapters(res.document, pageUrl);
            if (list.isEmpty || (all.isNotEmpty && list.last == all.last)) break;
            all.addAll(list);
          }
          if (all.isNotEmpty) return all;
        case MadaraChapterMode.mangaAjaxQuery:
          final slug = mangaPath.split('/').last;
          final res = await postHtml(
            Uri.parse('$baseUrl/index.php'),
            {'manga-core': slug, 'manga_ajax': '1', 'maction': 'get_chapters'},
            headers: referer,
          );
          final list = parseChapters(res.document, pageUrl);
          if (list.isNotEmpty) return list;
        case MadaraChapterMode.mangaAjax:
        case MadaraChapterMode.mangaPage:
          break;
      }
      // Default & cadangan: endpoint ajax/chapters (paling umum di situs Madara modern).
      if (fromPage.isEmpty) {
        final res = await postHtml(ajaxBase, const {}, headers: referer);
        return parseChapters(res.document, pageUrl);
      }
    } on SourceException catch (e) {
      if (fromPage.isEmpty) rethrow;
      // Endpoint gagal tapi halaman seri punya daftar bab: pakai itu.
      if (e.kind == SourceErrorKind.cloudflare) rethrow;
    }
    return fromPage;
  }

  List<SourceChapter> parseChapters(Document doc, Uri pageUrl) {
    final seen = <String>{};
    final chapters = <SourceChapter>[];
    final urlSelector = sel('chapterUrlSelector');
    final nameSelector = sel('chapterNameSelector');
    final dateSelector = sel('chapterDateSelector');
    for (final li in doc.querySelectorAll('li.wp-manga-chapter')) {
      final a = (urlSelector == 'a' ? null : _first(li, urlSelector)) ?? li.querySelector('a');
      final url = attrAbs(a, 'href', pageUrl);
      if (url == null || !seen.add(url)) continue;
      final name = clean((_first(li, nameSelector) ?? a!).text);
      final dateText = li.querySelectorAll('img').where((i) => !i.classes.contains('thumb')).firstOrNull?.attributes['alt'] ??
          li.querySelector('span a')?.attributes['title'] ??
          _first(li, dateSelector)?.text ??
          li.querySelector('span.chapter-release-date')?.text;
      chapters.add(SourceChapter(
        url: url,
        name: name.isEmpty ? 'Chapter' : name,
        number: parseChapterNumber(name),
        uploadedAt: madaraDate(dateText),
      ));
    }
    return chapters;
  }

  // ------------------------------------------------------------- halaman

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    var res = await fetchHtml(Uri.parse(chapter.url));
    if (res.document.querySelector('#single-pager') != null) {
      final url = Uri.parse(chapter.url);
      res = await fetchHtml(url.replace(queryParameters: {...url.queryParameters, 'style': 'list'}));
    }
    if (res.document.querySelector('.content-blocked.login-required') != null) {
      throw const SourceException(SourceErrorKind.parse,
          detail: 'Situs ini wajib login (member) untuk membaca bab. Login lewat "Buka di WebView".');
    }
    final protector = res.document.querySelector('#chapter-protector-data');
    final pages = protector != null ? decryptProtectedPages(protector) : parsePages(res.document, res.url);
    if (pages.isEmpty) {
      throw const SourceException(SourceErrorKind.parse, detail: 'Gambar bab tidak ditemukan.');
    }
    return pages;
  }

  /// Plugin "WP Manga Chapter Protector": daftar gambar dienkripsi CryptoJS
  /// (AES-256-CBC, kunci & IV dari EVP_BytesToKey MD5 atas nonce + salt).
  static List<String> decryptProtectedPages(Element protector) {
    final src = protector.attributes['src'] ?? '';
    const prefix = 'data:text/javascript;base64,';
    final script = src.startsWith(prefix) ? utf8.decode(base64.decode(src.substring(prefix.length))) : protector.text;
    String between(String start, String end) {
      final i = script.indexOf(start);
      if (i < 0) return '';
      final from = i + start.length;
      final j = script.indexOf(end, from);
      return j < 0 ? '' : script.substring(from, j);
    }

    try {
      final password = between("wpmangaprotectornonce='", "';");
      final data = asMap(jsonDecode(between("chapter_data='", "';").replaceAll(r'\/', '/')));
      final plain = cryptoJsDecrypt(asString(data['ct']) ?? '', asString(data['s']) ?? '', password);
      // Isinya string JSON yang membungkus array JSON.
      return [for (final url in asList(jsonDecode(jsonDecode(plain) as String))) '$url'];
    } catch (_) {
      throw const SourceException(SourceErrorKind.parse, detail: 'Gagal mendekripsi gambar bab (chapter protector).');
    }
  }

  List<String> parsePages(Document doc, Uri pageUrl) {
    final seen = <String>{};
    final custom = [
      for (final el in _all(doc, sel('pageListParseSelector')))
        if (madaraImage(_imgOf(el), pageUrl) case final url? when seen.add(url)) url,
    ];
    if (custom.isNotEmpty) return custom;
    final standard = [
      for (final img in doc.querySelectorAll('div.page-break img, li.blocks-gallery-item img, .reading-content .text-left img'))
        if (madaraImage(img, pageUrl) case final url? when seen.add(url)) url,
    ];
    if (standard.isNotEmpty) return standard;
    // Cadangan: gambar digambar ke <canvas data-page-url> (proteksi klik
    // kanan), atau <img> langsung di dalam .reading-content.
    return [
      for (final canvas in doc.querySelectorAll('.reading-content canvas[data-page-url]'))
        if (absUrl(pageUrl, canvas.attributes['data-page-url']) case final url? when seen.add(url)) url,
      for (final img in doc.querySelectorAll('.reading-content img'))
        if (madaraImage(img, pageUrl) case final url? when seen.add(url)) url,
    ];
  }
}

// ------------------------------------------------------------- utilitas

/// Dekripsi format CryptoJS `{ct, s}`: kunci 32 byte + IV 16 byte dari
/// MD5(prev + password + salt) berulang, lalu AES-256-CBC + PKCS7.
String cryptoJsDecrypt(String ciphertextBase64, String saltHex, String password) {
  final salt = Uint8List.fromList([
    for (var i = 0; i + 1 < saltHex.length; i += 2) int.parse(saltHex.substring(i, i + 2), radix: 16),
  ]);
  final pass = utf8.encode(password);
  final keyIv = <int>[];
  var previous = Uint8List(0);
  while (keyIv.length < 48) {
    previous = MD5Digest().process(Uint8List.fromList([...previous, ...pass, ...salt]));
    keyIv.addAll(previous);
  }
  final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
    ..init(
      false,
      PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
        ParametersWithIV(KeyParameter(Uint8List.fromList(keyIv.sublist(0, 32))), Uint8List.fromList(keyIv.sublist(32, 48))),
        null,
      ),
    );
  return utf8.decode(cipher.process(base64.decode(ciphertextBase64)));
}

final _whitespace = RegExp(r'\s+');

/// Padanan `imageFromElement` Madara: banyak atribut lazy-load + srcset.
String? madaraImage(Element? img, Uri base) {
  if (img == null) return null;
  for (final key in const ['data-src', 'data-lazy-src', 'data-lzl-src', 'data-cfsrc', 'data-manga-src']) {
    final url = absUrl(base, img.attributes[key]?.trim());
    if (url != null) return url;
  }
  final srcset = img.attributes['srcset'];
  if (srcset != null && srcset.trim().isNotEmpty) {
    String? best;
    var bestSize = -1.0;
    for (final part in srcset.split(',')) {
      final pieces = part.trim().split(_whitespace);
      if (pieces.isEmpty || pieces.first.isEmpty) continue;
      final size = pieces.length > 1 ? double.tryParse(pieces[1].replaceAll(RegExp('[wx]'), '')) ?? 0 : 0.0;
      if (size > bestSize) {
        bestSize = size;
        best = pieces.first;
      }
    }
    final url = absUrl(base, best);
    if (url != null) return url;
  }
  return absUrl(base, img.attributes['src']?.trim());
}

const _completed = [
  'completed', 'completo', 'completado', 'concluído', 'concluido', 'finalizado', 'achevé', 'terminé',
  'hoàn thành', 'مكتملة', 'مكتمل', '已完结', 'tamamlandı', 'завершено', 'tamamlanan', 'complété', 'tamat', 'end',
];
const _ongoing = [
  'ongoing', 'on going', 'updating', 'продолжается', 'em lançamento', 'em andamento', 'en cours', 'ativo',
  'lançando', 'đang tiến hành', 'còn nữa', 'devam ediyor', 'in corso', 'in arrivo', 'مستمرة', 'مستمر',
  'en curso', 'emision', 'curso', 'en marcha', 'publicandose', 'publicándose', 'en emision', '连载中',
  'đang làm', 'em postagem', 'devam eden', 'em progresso', 'atualizações semanais', 'виходить', 'đang ra', 'berjalan',
];
const _hiatus = [
  'on hold', 'hiatus', 'pausado', 'en espera', 'durduruldu', 'beklemede', 'đang chờ', 'متوقف', 'en pause',
  'заморожено', 'en attente', 'tạm dừng',
];
const _cancelled = ['canceled', 'cancelled', 'cancelado', 'iptal edildi', 'đã hủy', 'ملغي', 'abandonné', 'заброшено', 'annulé'];

SourceMangaStatus madaraStatus(String? raw) {
  final s = clean(raw).toLowerCase();
  if (s.isEmpty) return SourceMangaStatus.unknown;
  if (_completed.any(s.contains)) return SourceMangaStatus.completed;
  if (_ongoing.any(s.contains)) return SourceMangaStatus.ongoing;
  if (_hiatus.any(s.contains)) return SourceMangaStatus.hiatus;
  if (_cancelled.any(s.contains)) return SourceMangaStatus.cancelled;
  return SourceMangaStatus.unknown;
}

RegExp _words(List<String> words) => RegExp('(?<!\\p{L})(?:${words.map(RegExp.escape).join('|')})', unicode: true);

final _yearW = _words(['year', 'año', 'ano', 'năm', 'yıl', 'سنة', 'سنوات', 'tahun']);
final _monthW = _words(['month', 'mes', 'tháng', 'ay', 'شهر', 'أشهر', 'شهور', 'bulan']);
final _weekW = _words(['week', 'semana', 'tuần', 'hafta', 'أسبوع', 'أسابيع', 'minggu']);
final _dayW = _words(['day', 'día', 'dia', 'jour', 'hari', 'gün', 'ngày', 'giorni', 'أيام', '天']);
final _hourW = _words(['hour', 'hora', 'heure', 'jam', 'saat', 'giờ', 'ore', 'ساعة', 'ساعات', '小时']);
final _minuteW = _words(['minute', 'minuto', 'min', 'menit', 'dakika', 'phút', 'دقيقة', 'دقائق']);
final _secondW = _words(['second', 'segundo', 'sec', 'detik', 'giây', 'ثانية', 'ثوان']);

/// Padanan `parseChapterDate` Madara: today/yesterday, relatif multi-bahasa,
/// lalu format tanggal umum.
DateTime? madaraDate(String? raw, {DateTime? now}) {
  final text = clean(raw).toLowerCase();
  if (text.isEmpty) return null;
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  if (['today', 'hoje', 'hoy', 'hari ini'].any(text.startsWith)) return today;
  if (['yesterday', 'ontem', 'ayer', 'kemarin', 'يوم واحد'].any(text.startsWith)) {
    return today.subtract(const Duration(days: 1));
  }
  final amount = int.tryParse(RegExp(r'\d+').firstMatch(text)?.group(0) ?? '');
  if (amount != null) {
    Duration? d;
    if (_yearW.hasMatch(text)) {
      d = Duration(days: 365 * amount);
    } else if (_monthW.hasMatch(text)) {
      d = Duration(days: 30 * amount);
    } else if (_weekW.hasMatch(text)) {
      d = Duration(days: 7 * amount);
    } else if (_dayW.hasMatch(text)) {
      d = Duration(days: amount);
    } else if (_hourW.hasMatch(text)) {
      d = Duration(hours: amount);
    } else if (_minuteW.hasMatch(text)) {
      d = Duration(minutes: amount);
    } else if (_secondW.hasMatch(text)) {
      d = Duration(seconds: amount);
    }
    if (d != null && !RegExp(r'\d{4}').hasMatch(text)) return current.subtract(d);
  }
  return parseLooseDate(text, now: current);
}
