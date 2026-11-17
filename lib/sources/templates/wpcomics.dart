// Port Dart dari template WPComics milik keiyoushi/extensions-source
// (Apache-2.0): lib-multisrc/wpcomics.
//
// Situs komik bertema "NetTruyen" (WordPress): daftar `/hot` & beranda, pencarian
// `/tim-truyen?keyword=`, detail `article#item-detail`, bab `div.list-chapter`, gambar
// `div.page-chapter > img`. Selector dan jalur yang berbeda per situs dibaca dari
// opsi katalog. Penyesuaian di luar itu (mis. gambar via interceptor) tidak ikut.

import 'package:html/dom.dart';

import '../../core/i18n/strings.dart';
import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class WPComicsSource extends HttpSource {
  WPComicsSource({
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

  String get popularPath => _s('popularPath', 'hot');
  String get searchPath => _s('searchPath', 'tim-truyen');
  String get queryParam => _s('queryParam', 'keyword');
  String? get latestPath => asString(vals['latestPath']);
  String get popularSelector => _s('popularMangaSelector', 'div.items div.item');
  String get latestSelector => _s('latestUpdatesSelector', popularSelector);
  String get searchSelector => _s('searchMangaSelector', 'div.items div.item');
  String get chapterListSelector => _s('chapterListSelector', 'div.list-chapter li.row:not(.heading)');
  String get chapterDateSelector => _s('chapterDateSelector', 'div.col-xs-4');
  String get pageListSelector => _s('pageListSelector', 'div.page-chapter > img, li.blocks-gallery-item img');
  String get genresSelector => _s('genresSelector', '.genres ul.nav li:not(.active) a');
  String get pagesSuffix => _s('pagesSuffix', '');

  /// Tanggal bulan/hari/tahun (AS) bukan hari/bulan/tahun.
  bool get monthFirst => vals['monthFirst'] == true;

  // =========================== Daftar ===========================

  @override
  Future<MangaPage> popular(int page) => _list('$baseUrl/$popularPath${page > 1 ? '?page=$page' : ''}', popularSelector);

  @override
  Future<MangaPage> latest(int page) {
    final path = latestPath;
    final url = path != null ? '$baseUrl/$path?page=$page' : '$baseUrl${page > 1 ? '?page=$page' : ''}';
    return _list(url, latestSelector);
  }

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) {
    final genre = filters.single('genre');
    final status = filters.single('status');
    final plain = query.trim().isNotEmpty || (genre == null && status == null);
    final path = [searchPath, if (!plain && genre != null) genre].join('/');
    final url = Uri.parse('$baseUrl/$path').replace(queryParameters: {
      if (plain) queryParam: query.trim(),
      if (!plain && status != null) 'status': status,
      'page': '$page',
      'sort': '0',
    });
    return _list(url.toString(), searchSelector);
  }

  Future<MangaPage> _list(String url, String selector) async {
    final res = await fetchHtml(Uri.parse(url));
    return parseList(res.document, res.url, selector);
  }

  MangaPage parseList(Document doc, Uri base, String selector) {
    final items = <SourceManga>[];
    for (final el in doc.querySelectorAll(selector)) {
      final link = el.querySelector('h3 a');
      final url = absUrl(base, link?.attributes['href']);
      final title = clean(link?.text);
      if (url == null || title.isEmpty) continue;
      items.add(SourceManga(url: url, title: title, thumbnailUrl: _cover(el, base)));
    }
    return MangaPage(items, hasNextPage: doc.querySelector('a.next-page, a[rel=next]') != null);
  }

  String? _cover(Element el, Uri base) {
    final img = el.querySelector('div.image img') ?? el.querySelector('img');
    return imageOrNull(img, base);
  }

  /// Gambar dengan atribut kosong sering bukan gambar sungguhan.
  static String? imageOrNull(Element? img, Uri base) {
    if (img == null) return null;
    for (final attr in const ['data-original', 'data-src', 'src']) {
      final v = img.attributes[attr];
      if (v == null || v.trim().isEmpty) continue;
      final abs = absUrl(base, v.trim());
      if (abs != null && RegExp(r'^https?://', caseSensitive: false).hasMatch(abs)) return abs;
    }
    return null;
  }

  // =========================== Filter ===========================

  @override
  Future<List<FilterDef>> filters() async {
    var genres = <FilterOption>[];
    try {
      final res = await fetchHtml(Uri.parse('$baseUrl/$searchPath'));
      genres = [
        for (final a in res.document.querySelectorAll(genresSelector.replaceAll(RegExp(r':contains\([^)]*\)'), '')))
          if ((a.attributes['href'] ?? '').isNotEmpty && clean(a.text).isNotEmpty)
            FilterOption(clean(a.text), a.attributes['href']!.replaceFirst(RegExp(r'/+$'), '').split('/').last),
      ];
    } catch (_) {
      // Tanpa genre.
    }
    return [
      const SelectFilterDef('status', 'Status', [
        FilterOption('All', ''),
        FilterOption('Ongoing', '1'),
        FilterOption('Completed', '2'),
      ]),
      if (genres.isNotEmpty) SelectFilterDef('genre', 'Genre', [const FilterOption('All', ''), ...genres]),
    ];
  }

  // =========================== Detail ===========================

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    final chapters = <SourceChapter>[];
    var doc = res.document;
    var base = res.url;
    // Beberapa situs membagi daftar bab ke beberapa halaman.
    for (var guard = 0; guard < 50; guard++) {
      chapters.addAll(parseChapters(doc, base));
      final next = absUrl(base, doc.querySelector('ul.pagination a[rel=next]')?.attributes['href']);
      if (next == null) break;
      final page = await fetchHtml(Uri.parse(next));
      doc = page.document;
      base = page.url;
    }
    return parseDetails(res.document, res.url, chapters);
  }

  static SourceMangaStatus _status(String text) {
    bool any(List<String> words) => words.any((w) => text.toLowerCase().contains(w.toLowerCase()));
    if (any(['Ongoing', 'Updating', 'Đang tiến hành', 'Đang cập nhật', 'Đang thực hiện', 'Đang ra', '連載中'])) {
      return SourceMangaStatus.ongoing;
    }
    if (any(['Complete', 'Hoàn thành', 'Đã hoàn thành', 'Full', 'Truyện Full', '完結済み'])) return SourceMangaStatus.completed;
    if (any(['Tạm Ngưng', 'Tạm Hoãn'])) return SourceMangaStatus.hiatus;
    return SourceMangaStatus.unknown;
  }

  SourceMangaDetails parseDetails(Document doc, Uri base, List<SourceChapter> chapters) {
    final info = doc.querySelector('article#item-detail');
    if (info == null) throw SourceException(SourceErrorKind.parse, detail: tr('Detail seri tidak ditemukan.'));
    final other = clean(info.querySelector('h2.other-name')?.text);
    final description = [
      info.querySelectorAll('div.detail-content p').map((p) => p.text.trim()).where((t) => t.isNotEmpty).join('\n'),
      if (other.isNotEmpty) 'Other name: $other',
    ].where((t) => t.isNotEmpty).join('\n\n');
    final author = clean(info.querySelector('li.author p.col-xs-8')?.text);
    return SourceMangaDetails(
      url: base.toString(),
      title: clean(info.querySelector('h1.title-detail')?.text ?? doc.querySelector('h1')?.text),
      thumbnailUrl: imageOrNull(info.querySelector('div.col-image img'), base),
      author: author.isEmpty ? null : author,
      description: description.isEmpty ? null : description,
      genres: [
        for (final a in info.querySelectorAll('li.kind p.col-xs-8 a'))
          if (clean(a.text).isNotEmpty) clean(a.text),
      ],
      status: _status(clean(info.querySelector('li.status p.col-xs-8')?.text)),
      chapters: chapters,
    );
  }

  List<SourceChapter> parseChapters(Document doc, Uri base, {DateTime? now}) {
    final out = <SourceChapter>[];
    for (final el in doc.querySelectorAll(chapterListSelector)) {
      final a = el.querySelector('a');
      final url = absUrl(base, a?.attributes['href']);
      final name = clean(a?.text);
      if (url == null || name.isEmpty) continue;
      out.add(SourceChapter(
        url: url,
        name: name,
        number: parseChapterNumber(name),
        uploadedAt: parseDate(clean(el.querySelector(chapterDateSelector)?.text), now: now),
      ));
    }
    return out;
  }

  static const _units = <(List<String>, Duration Function(int))>[
    (['year', 'năm'], _years),
    (['month', 'tháng', '月'], _months),
    (['week', 'tuần', '週間'], _weeks),
    (['day', 'ngày', '日'], _days),
    (['hour', 'giờ', '時間'], _hours),
    (['minute', 'phút', '分'], _minutes),
    (['second', 'giây'], _seconds),
  ];
  static Duration _years(int n) => Duration(days: 365 * n);
  static Duration _months(int n) => Duration(days: 30 * n);
  static Duration _weeks(int n) => Duration(days: 7 * n);
  static Duration _days(int n) => Duration(days: n);
  static Duration _hours(int n) => Duration(hours: n);
  static Duration _minutes(int n) => Duration(minutes: n);
  static Duration _seconds(int n) => Duration(seconds: n);

  /// "3 days ago", "5 giờ trước", "07/11/2025", "20:15 - 07/11/2025 +0500".
  DateTime? parseDate(String raw, {DateTime? now}) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();
    if (const ['ago', 'trước', '前'].any(lower.contains)) {
      final n = int.tryParse(RegExp(r'(\d+)').firstMatch(text)?.group(1) ?? '');
      if (n == null) return null;
      for (final (words, make) in _units) {
        if (words.any(lower.contains)) return (now ?? DateTime.now()).subtract(make(n));
      }
      return now ?? DateTime.now();
    }
    final m = RegExp(r'(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})').firstMatch(text);
    if (m == null) return null;
    final a = int.parse(m[1]!);
    final b = int.parse(m[2]!);
    var year = int.parse(m[3]!);
    if (year < 100) year += 2000;
    final (day, month) = monthFirst ? (b, a) : (a, b);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }

  // =========================== Halaman ===========================

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse('${chapter.url}$pagesSuffix'));
    return parsePages(res.document, res.url);
  }

  List<String> parsePages(Document doc, Uri base) {
    final out = <String>[];
    for (final img in doc.querySelectorAll(pageListSelector)) {
      final url = imageOrNull(img, base);
      if (url != null && !out.contains(url)) out.add(url);
    }
    if (out.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    return out;
  }
}
