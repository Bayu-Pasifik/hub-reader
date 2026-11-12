// Port Dart dari template ZeistManga milik keiyoushi/extensions-source
// (Apache-2.0): lib-multisrc/zeistmanga.
//
// ZeistManga adalah tema Blogger (Blogspot). Daftar seri & bab diambil dari
// feed JSON Blogger (/feeds/posts/default?alt=json), detail & gambar dari HTML.

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class ZeistMangaSource extends HttpSource {
  ZeistMangaSource({
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

  /// Override sederhana dari Kotlin situs (selector & flag), lihat katalog.
  final Map<String, Object?> vals;

  String _s(String key, String fallback) => vals[key] is String ? vals[key]! as String : fallback;
  bool _b(String key, bool fallback) => vals[key] is bool ? vals[key]! as bool : fallback;

  @override
  bool get supportsLatest => _b('supportsLatest', true);

  String get chapterCategory => _s('chapterCategory', 'Chapter');
  bool get _useNewFeed => _b('useNewChapterFeed', false);
  bool get _useOldFeed => _b('useOldChapterFeed', false);
  bool get _preferUpdated => _b('preferChapterUpdatedDate', false);

  static const _maxResults = 20;
  static const _chapterChunk = 150;

  static const _included = [
    'Series',
    'Manga',
    'Manhwa',
    'Manhua',
    'Doujinshi',
    'Web Novel (JP)',
    'Web Novel (KR)',
    'Web Novel (CN)'
  ];
  List<String> get _excluded => ['Anime', 'Novel', 'Novela', chapterCategory];

  /// Selector dari Kotlin bisa memakai pseudo Jsoup yang tidak didukung
  /// package:html; bila gagal, pakai selector bawaan.
  List<Element> _select(Element root, String key, String fallback) {
    try {
      return root.querySelectorAll(_s(key, fallback));
    } catch (_) {
      return root.querySelectorAll(fallback);
    }
  }

  Element? _first(Element root, String key, String fallback) {
    final list = _select(root, key, fallback);
    return list.isEmpty ? null : list.first;
  }

  Uri _feedUrl([String label = '']) => Uri.parse(
        label.isEmpty
            ? '$baseUrl/feeds/posts/default/'
            : '$baseUrl/feeds/posts/default/-/${Uri.encodeComponent(label)}',
      );

  /// Query Blogger: `{label:"Series" …} -label:"Anime" … <kata kunci|filter>`.
  String _labelQuery(String query, FilterValues filters) {
    final b = StringBuffer('{');
    for (final c in _included) {
      b.write('label:"$c" ');
    }
    b.write('}');
    for (final c in _excluded) {
      b.write('-label:"${c.trim()}" ');
    }
    if (query.trim().isNotEmpty) {
      b.write(query.trim());
    } else {
      for (final key in const ['status', 'type']) {
        if (filters.single(key) case final v?) b.write('label:"$v" ');
      }
      for (final g in filters.multi('genre')) {
        b.write('label:"$g" ');
      }
    }
    return b.toString().trim();
  }

  Uri searchUrl(int page, String query, {FilterValues filters = FilterValues.empty, String? orderBy}) =>
      _feedUrl().replace(queryParameters: {
        'alt': 'json',
        if (orderBy != null) 'orderby': orderBy,
        'max-results': '${_maxResults + 1}',
        'start-index': '${_maxResults * (page - 1) + 1}',
        'q': _labelQuery(query, filters),
      });

  // ---------------------------------------------------------------- daftar

  @override
  Future<MangaPage> popular(int page) async {
    if (!supportsLatest) return latest(page);
    final res = await fetchHtml(Uri.parse(baseUrl));
    final items = <SourceManga>[];
    for (final el
        in _select(res.document.documentElement!, 'popularMangaSelector', 'div.PopularPosts div.grid > figure')) {
      final titleEl = _first(el, 'popularMangaSelectorTitle', 'figcaption > a');
      final linkEl = _first(el, 'popularMangaSelectorUrl', 'figcaption > a');
      final url = attrAbs(linkEl, 'href', res.url);
      if (url == null) continue;
      items.add(SourceManga(
        url: url,
        title: clean(titleEl?.text).isEmpty ? 'Tanpa judul' : clean(titleEl!.text),
        thumbnailUrl: attrAbs(el.querySelector('img'), 'src', res.url),
      ));
    }
    // Situs tanpa widget PopularPosts: pakai daftar terbaru.
    return items.isEmpty ? latest(page) : MangaPage(items, hasNextPage: false);
  }

  @override
  Future<MangaPage> latest(int page) async =>
      parseFeedList(asMap(await fetchJson(searchUrl(page, '', orderBy: 'published'))));

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async =>
      parseFeedList(asMap(await fetchJson(searchUrl(page, query, filters: filters))));

  static List<JsonMap> _entries(JsonMap json) => [for (final e in asList(asMap(json['feed'])['entry'])) asMap(e)];

  static String? _t(Object? v) => asString(asMap(v)[r'$t']);

  static String? _alternate(JsonMap entry) {
    for (final l in asList(entry['link'])) {
      final m = asMap(l);
      if (m['rel'] == 'alternate') return asString(m['href']);
    }
    return null;
  }

  static String? _thumbnail(JsonMap entry) {
    final thumb = asString(asMap(entry[r'media$thumbnail'])['url']);
    if (thumb != null) {
      return thumb.replaceAll(RegExp(r'/s\d+[^/]*-c/'), '/w600/').replaceFirst(RegExp(r'=s\d+[^=]*-c$'), '=w600');
    }
    final content = _t(entry['content']);
    if (content == null) return null;
    return html_parser.parse(content).querySelector('img')?.attributes['src'];
  }

  MangaPage parseFeedList(JsonMap json) {
    final items = <SourceManga>[
      for (final e in _entries(json))
        if (_alternate(e) case final url?)
          SourceManga(url: url, title: _t(e['title']) ?? 'Tanpa judul', thumbnailUrl: _thumbnail(e)),
    ];
    final hasNext = items.length > _maxResults;
    return MangaPage(hasNext ? items.sublist(0, _maxResults) : items, hasNextPage: hasNext);
  }

  // ---------------------------------------------------------------- filter

  @override
  Future<List<FilterDef>> filters() async {
    if (!_b('hasFilters', false)) return const [];
    return [
      const SelectFilterDef('status', 'Status', [
        FilterOption('Semua', ''),
        FilterOption('Berjalan', 'Ongoing'),
        FilterOption('Tamat', 'Completed'),
        FilterOption('Hiatus', 'Hiatus'),
        FilterOption('Dihentikan', 'Dropped'),
      ]),
      const SelectFilterDef('type', 'Tipe', [
        FilterOption('Semua', ''),
        FilterOption('Manga', 'Manga'),
        FilterOption('Manhua', 'Manhua'),
        FilterOption('Manhwa', 'Manhwa'),
      ]),
      MultiSelectFilterDef('genre', 'Genre', [
        for (final g in [
          'Action',
          'Adventure',
          'Comedy',
          'Crime',
          'Drama',
          'Ecchi',
          'Fantasy',
          'Harem',
          'Historical',
          'Horror',
          'Isekai',
          'Josei',
          'Magic',
          'Martial Arts',
          'Medical',
          'Military',
          'Music',
          'Mystery',
          'One Shot',
          'Police',
          'Psychological',
          'Reincarnation',
          'Revenge',
          'Romance',
          'School Life',
          'Sci-Fi',
          'Seinen',
          'Shounen',
          'Slice of Life',
          'Sports',
          'Supernatural',
          'Survival',
          'Thriller',
          'Time Travel',
          'Tragedy',
          'Vampire',
        ])
          FilterOption(g, g),
      ]),
    ];
  }

  // ---------------------------------------------------------------- detail

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    final details = parseDetails(res.document, res.url);
    final chapters = await _chapters(res.document, details.title);
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

  static const _ongoing = [
    'ongoing',
    'en curso',
    'en emisión',
    'em lançamento',
    'activo',
    'ativo',
    'lançando',
    'مستمر',
    'مستمرة',
    'berjalan'
  ];
  static const _completed = ['completed', 'completo', 'finalizado', 'مكتمل', 'مكتملة', 'tamat', 'end'];
  static const _hiatus = ['hiatus', 'pausado'];
  static const _cancelled = ['cancelled', 'dropped', 'dropado', 'abandonado', 'cancelado'];

  static SourceMangaStatus zeistStatus(String? raw) {
    final s = clean(raw).toLowerCase();
    if (_ongoing.contains(s)) return SourceMangaStatus.ongoing;
    if (_completed.contains(s)) return SourceMangaStatus.completed;
    if (_hiatus.contains(s)) return SourceMangaStatus.hiatus;
    if (_cancelled.contains(s)) return SourceMangaStatus.cancelled;
    return parseStatus(raw);
  }

  SourceMangaDetails parseDetails(Document doc, Uri pageUrl) {
    final root = doc.documentElement!;
    final profile = _first(root, 'mangaDetailsSelector', '.grid.gtc-235fr') ?? doc.body ?? root;
    final title = clean(doc.querySelector('h1')?.text).isNotEmpty
        ? clean(doc.querySelector('h1')!.text)
        : clean(doc.querySelector('meta[property="og:title"]')?.attributes['content']);
    if (title.isEmpty) {
      throw const SourceException(SourceErrorKind.parse, detail: 'Judul seri tidak ditemukan.');
    }

    var author = nonPlaceholder(_first(profile, 'mangaDetailsSelectorAuthor', 'span#author')?.text);
    var artist = nonPlaceholder(_first(profile, 'mangaDetailsSelectorArtist', 'span#artist')?.text);
    var status = zeistStatus(_first(profile, 'mangaDetailsSelectorStatus', 'span[data-status]')?.text);
    for (final info in _select(profile, 'mangaDetailsSelectorInfo', '.y6x11p')) {
      final label = ownText(info).isNotEmpty
          ? ownText(info)
          : clean(_first(info, 'mangaDetailsSelectorInfoTitle', 'strong')?.text);
      final value = clean(_select(info, 'mangaDetailsSelectorInfoDescription', 'span.dt').map((e) => e.text).join(' '));
      if (status == SourceMangaStatus.unknown && ['Status', 'Estado', 'الحالة'].any(label.contains)) {
        status = zeistStatus(value);
      } else if (author == null && ['Author', 'Autor', 'Mangaka', 'الكاتب', 'Yazar', 'Pengarang'].any(label.contains)) {
        author = nonPlaceholder(value);
      } else if (artist == null && ['Artist', 'Artista', 'الرسام', 'Çizer'].any(label.contains)) {
        artist = nonPlaceholder(value);
      }
    }

    final synopsis =
        clean(_select(profile, 'mangaDetailsSelectorDescription', '#synopsis').map((e) => e.text).join(' '));
    final alt = clean(_first(profile, 'mangaDetailsSelectorAltName', 'header > p')?.text);
    final description = [if (synopsis.isNotEmpty) synopsis, if (alt.isNotEmpty) 'Judul alternatif: $alt'].join('\n\n');

    return SourceMangaDetails(
      url: pageUrl.toString(),
      title: title,
      thumbnailUrl: attrAbs(_first(profile, 'mangaDetailsSelectorThumbnail', 'img'), 'src', pageUrl),
      author: author,
      artist: artist,
      description: description.isEmpty ? null : description,
      genres: [
        for (final a in _select(profile, 'mangaDetailsSelectorGenres', 'div.mt-15 > a[rel=tag]'))
          if (clean(a.text).isNotEmpty) clean(a.text),
      ],
      status: status,
    );
  }

  // ----------------------------------------------------------------- bab

  static final _clwd = RegExp(r'''clwd\.run\(["'](.*?)["']\)''');
  static final _oldFeed = RegExp(r"([^']+)\?");
  static final _newLabel = RegExp(r"label\s*=\s*'([^']+)'");

  /// URL feed bab: dari script `#clwd`, `#myUL` (lama), `#latest` (baru),
  /// atau judul seri sebagai label (cadangan), sama seperti Kotlin.
  Uri chapterFeedUrl(Document doc, String mangaTitle) {
    Uri newFeed() {
      final clwd = doc.querySelector('#clwd > script');
      final label = clwd != null
          ? _clwd.firstMatch(clwd.text)?.group(1)
          : _newLabel.firstMatch(doc.querySelector('#latest > script')?.text ?? '')?.group(1);
      if (label == null) throw const SourceException(SourceErrorKind.parse, detail: 'Feed bab tidak ditemukan.');
      return _feedUrl(label).replace(queryParameters: {'alt': 'json'});
    }

    Uri oldFeed() {
      final src = doc.querySelector('#myUL > script')?.attributes['src'] ?? '';
      final path = _oldFeed.firstMatch(src)?.group(1);
      if (path == null) throw const SourceException(SourceErrorKind.parse, detail: 'Feed bab tidak ditemukan.');
      return Uri.parse('$baseUrl$path').replace(queryParameters: {'alt': 'json'});
    }

    if (_useNewFeed) return newFeed();
    if (_useOldFeed) return oldFeed();
    final script = doc.querySelector('#clwd > script');
    if (script == null) {
      try {
        return oldFeed();
      } on SourceException {
        try {
          return newFeed();
        } on SourceException {
          // jatuh ke judul seri
        }
      }
    }
    final feed = (script != null ? _clwd.firstMatch(script.text)?.group(1) : null) ?? mangaTitle;
    return Uri.parse(
            '$baseUrl/feeds/posts/default/-/${Uri.encodeComponent(chapterCategory)}/${Uri.encodeComponent(feed)}')
        .replace(queryParameters: {'alt': 'json'});
  }

  Future<List<SourceChapter>> _chapters(Document doc, String title) async {
    final feed = chapterFeedUrl(doc, title);
    final entries = <JsonMap>[];
    for (var start = 1; start < 5000; start += _chapterChunk) {
      final json = asMap(await fetchJson(feed.replace(queryParameters: {
        ...feed.queryParameters,
        'start-index': '$start',
        'max-results': '$_chapterChunk',
      })));
      final batch = _entries(json);
      entries.addAll(batch);
      final total = int.tryParse(_t(asMap(json['feed'])[r'openSearch$totalResults']) ?? '') ?? 0;
      if (batch.isEmpty || entries.length >= total) break;
    }
    return parseChapterEntries(entries);
  }

  List<SourceChapter> parseChapterEntries(List<JsonMap> entries) => [
        for (final e in entries)
          if (asList(e['category']).any((c) => asMap(c)['term'] == chapterCategory))
            if (_alternate(e) case final url?)
              SourceChapter(
                url: url,
                name: _t(e['title']) ?? 'Chapter',
                number: parseChapterNumber(_t(e['title']) ?? ''),
                uploadedAt: DateTime.tryParse(
                  (_preferUpdated ? _t(e['updated']) ?? _t(e['published']) : _t(e['published']) ?? _t(e['updated'])) ??
                      '',
                )?.toLocal(),
              ),
      ];

  // ------------------------------------------------------------- halaman

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    final pages = parsePages(res.document, res.url);
    if (pages.isEmpty) {
      throw const SourceException(SourceErrorKind.parse, detail: 'Gambar bab tidak ditemukan.');
    }
    return pages;
  }

  static final _chapterImage = RegExp(r'"(https?://.*?)"');

  List<String> parsePages(Document doc, Uri pageUrl) {
    // Beberapa situs (mis. ReYume) menyimpan HTML gambar di textarea.
    final raw = doc.querySelector('textarea#zeist-raw-data')?.text;
    if (raw != null && raw.trim().isNotEmpty) doc = html_parser.parse(raw);
    // Situs lain menaruh daftar gambar di script config['chapterImage'].
    for (final s in doc.querySelectorAll('script')) {
      final data = s.text;
      final i = data.indexOf("config['chapterImage']");
      if (i < 0) continue;
      final urls = [for (final m in _chapterImage.allMatches(data.substring(i))) m.group(1)!];
      if (urls.isNotEmpty) return urls;
    }
    final seen = <String>{};
    return [
      for (final box in _select(doc.documentElement!, 'pageListSelector', 'div.check-box div.separator'))
        for (final img in [if (box.localName == 'img') box, ...box.querySelectorAll('img[src]')])
          if (absUrl(pageUrl, img.attributes['src']) case final url? when seen.add(url)) url,
    ];
  }
}
