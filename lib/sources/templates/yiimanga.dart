// Port Dart dari template Yiimanga milik keiyoushi/extensions-source
// (Apache-2.0): lib-multisrc/yiimanga.
//
// Situs HTML biasa: daftar `/page/N/`, pencarian `/search/?s=...`, detail dan
// bab dalam satu halaman, gambar di `.reading-content`. Beda antar situs hanya
// jalur populer, nama parameter cari, dan jalur genre.

import 'package:html/dom.dart';

import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';
import '../../core/i18n/strings.dart';

class YiimangaSource extends HttpSource {
  YiimangaSource({
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

  /// Override sederhana dari Kotlin (`searchParam`, `popularPath`, dst).
  final JsonMap vals;

  String get searchParam => asString(vals['searchParam']) ?? 's';

  /// Jalur katalog yang bisa diurut `?order=views`; null = populer = terbaru.
  String? get popularPath => asString(vals['popularPath']);

  /// Segmen jalur genre (`genre`, atau `genero` di situs Spanyol).
  String get genreSegment => asString(vals['genreSegment']) ?? 'genre';

  /// ToonGod: `/genre/<slug>/<n>/` tanpa segmen `page`.
  bool get genreWithoutPageSegment => vals['genreWithoutPageSegment'] == true;

  bool get spanishGenres => vals['spanishGenres'] == true;

  /// ManhwaBuddy: populer = isi beranda.
  bool get popularFromHome => vals['popularFromHome'] == true;

  bool get fetchGenres => vals['supportsFilterFetching'] == true;

  @override
  bool get supportsLatest => popularPath != null || vals['supportsLatest'] == true;

  // =========================== Daftar ===========================

  Uri _listUrl(List<String> segments, int page, {Map<String, String>? query}) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      pathSegments: [...segments, 'page', '$page', ''],
      queryParameters: query,
    );
  }

  @override
  Future<MangaPage> popular(int page) async {
    if (popularFromHome) {
      final res = await fetchHtml(Uri.parse(baseUrl));
      return MangaPage([
        for (final el in res.document.querySelectorAll('.item-move'))
          if (_homeItem(el, res.url) case final manga?) manga,
      ], hasNextPage: false);
    }
    final path = popularPath;
    if (path == null) return latest(page);
    return _fetchList(_listUrl([path], page, query: {'order': 'views'}));
  }

  SourceManga? _homeItem(Element el, Uri base) {
    final link = el.querySelector('.name a');
    final url = absUrl(base, link?.attributes['href']);
    final title = clean(link?.text);
    if (url == null || title.isEmpty) return null;
    return SourceManga(url: url, title: title, thumbnailUrl: attrAbs(el.querySelector('img'), 'src', base));
  }

  @override
  Future<MangaPage> latest(int page) => _fetchList(_listUrl(const [], page));

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) {
    final text = query.trim();
    if (text.isNotEmpty) {
      return _fetchList(Uri.parse(baseUrl).replace(
        pathSegments: ['search', ''],
        queryParameters: {searchParam: text, 'page': '$page'},
      ));
    }
    final genre = filters.single('genre') ?? '';
    if (genre.isEmpty) return latest(page);
    final segments = genreWithoutPageSegment
        ? Uri.parse(baseUrl).replace(pathSegments: [genreSegment, genre, '$page', ''])
        : _listUrl([genreSegment, genre], page);
    return _fetchList(segments);
  }

  Future<MangaPage> _fetchList(Uri url) async {
    final res = await fetchHtml(url);
    return parseList(res.document, res.url);
  }

  MangaPage parseList(Document doc, Uri base) {
    final items = <SourceManga>[];
    for (final el in doc.querySelectorAll('.latest-list .latest-item, .list .list-item')) {
      Element? link;
      for (final a in el.querySelectorAll('.latest-right a')) {
        if (a.querySelector('h3, h4') != null) {
          link = a;
          break;
        }
      }
      link ??= el.querySelector('.item-title a');
      final url = absUrl(base, link?.attributes['href']);
      final title = clean(link?.text);
      if (url == null || title.isEmpty) continue;
      items.add(SourceManga(
        url: url,
        title: title,
        thumbnailUrl: attrAbs(el.querySelector('.latest-left img, .item-img img'), 'src', base),
      ));
    }
    return MangaPage(items, hasNextPage: doc.querySelector('#pagination li.next a') != null);
  }

  // =========================== Filter ===========================

  static const _spanish = <(String, String)>[
    ('Acción', 'accion'),
    ('Adulto', 'adulto'),
    ('Aventura', 'aventura'),
    ('Ciencia ficción', 'ciencia-ficcion'),
    ('Comedia', 'comedia'),
    ('Drama', 'drama'),
    ('Ecchi', 'ecchi'),
    ('Familia', 'familia'),
    ('Fantasía', 'fantasia'),
    ('Harem', 'harem'),
    ('Isekai', 'isekai'),
    ('Josei', 'josei'),
    ('Maduro', 'maduro'),
    ('Magia', 'magia'),
    ('Recuentos de la vida', 'recuentos-de-la-vida'),
    ('Reencarnación', 'reencarnacion'),
    ('Romance', 'romance'),
    ('Seinen', 'seinen'),
    ('Shonen', 'shonen'),
    ('Sin censura', 'sin-censura'),
    ('Smut', 'smut'),
    ('Sobrenatural', 'sobrenatural'),
    ('Supervivencia', 'supervivencia'),
    ('Vida escolar', 'vida-escolar'),
  ];

  @override
  Future<List<FilterDef>> filters() async {
    if (spanishGenres) {
      return [
        SelectFilterDef('genre', 'Género', [
          const FilterOption('Todos', ''),
          for (final (label, slug) in _spanish) FilterOption(label, slug),
        ]),
      ];
    }
    if (!fetchGenres) return const [];
    try {
      final res = await fetchHtml(Uri.parse(baseUrl));
      final genres = parseGenres(res.document, res.url);
      if (genres.isEmpty) return const [];
      return [
        SelectFilterDef('genre', 'Genre', [const FilterOption('All', ''), ...genres]),
      ];
    } catch (_) {
      return const [];
    }
  }

  List<FilterOption> parseGenres(Document doc, Uri base) {
    final seen = <String>{};
    final out = <FilterOption>[];
    for (final a in doc.querySelectorAll(
        '.genre-list a, a.item-nav[href*="/genre/"], a.item-nav-mb[href*="/genre/"]')) {
      final url = absUrl(base, a.attributes['href']);
      final segments = url == null ? const <String>[] : Uri.parse(url).pathSegments;
      if (segments.length < 2) continue;
      final slug = segments[1];
      final label = clean(a.text);
      if (label.isEmpty || !seen.add(slug)) continue;
      out.add(FilterOption(label, slug));
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

  static const _infoHeadings = '.main-info-list li > h5, .post-content_item .summary-heading > h5, .info-item > span.sh';

  /// Nilai baris info ("Author(s)", "Status", ...) menurut label.
  Element? _info(Document doc, List<String> labels) {
    for (final heading in doc.querySelectorAll(_infoHeadings)) {
      var text = clean(heading.text);
      if (text.endsWith(':')) text = text.substring(0, text.length - 1).trim();
      if (text.endsWith(' -')) text = text.substring(0, text.length - 2).trim();
      if (!labels.contains(text)) continue;
      Element? row = heading.parent;
      while (row != null &&
          !(row.localName == 'li' ||
              row.classes.contains('post-content_item') ||
              row.classes.contains('info-item'))) {
        row = row.parent;
      }
      if (row == null) continue;
      for (final child in row.children) {
        if (child.localName == 'h5' || child.classes.contains('summary-heading') || child.classes.contains('sh')) {
          continue;
        }
        return child;
      }
    }
    return null;
  }

  /// Daftar tautan (nama dipisah koma) atau teks polos.
  String? _names(Element? el) {
    if (el == null) return null;
    final links = el.querySelectorAll('a');
    final names = links.isEmpty
        ? [clean(el.text)]
        : [for (final a in links) clean(ownText(a).isEmpty ? a.text : ownText(a)).replaceAll(RegExp(r',$'), '')];
    final joined = names.where((n) => n.isNotEmpty).join(', ');
    return joined.isEmpty ? null : joined;
  }

  SourceMangaDetails parseDetails(Document doc, Uri base) {
    final titleEl = doc.querySelector('h1.main-info-title, .post-title h1, .manga-detail .info h1');
    final title = clean(titleEl?.text);
    if (title.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Judul seri tidak ditemukan.'));
    }
    final statusText =
        clean((_info(doc, ['Status', 'Estado']) ?? doc.querySelector('.manga-detail .info p.type'))?.text).toLowerCase();
    final block = doc.querySelector('.short-desc-content, .dsct, .description-summary');
    var synopsis = '';
    if (block != null) {
      final parts = block.querySelectorAll('p, li').map((e) => clean(e.text)).where((t) => t.isNotEmpty).toList();
      synopsis = (parts.isEmpty ? [clean(block.text)] : parts).where((t) => t.isNotEmpty).join('\n\n');
    }
    final altEl = _info(doc, ['Alternative']) ?? doc.querySelector('.main-info-list li > h4, .manga-detail .info h6');
    final alt = clean(altEl?.text);
    final description = [if (synopsis.isNotEmpty) synopsis, if (alt.isNotEmpty) 'Alternative names: $alt'].join('\n\n');

    return SourceMangaDetails(
      url: base.toString(),
      title: title,
      thumbnailUrl: attrAbs(doc.querySelector('img.img-cover, .summary_image img, .manga-detail .poster img'), 'src', base),
      author: _names(_info(doc, ['Author(s)', 'Author', 'Autores'])),
      artist: _names(_info(doc, ['Artist(s)', 'Artist', 'Artistas'])),
      description: description.isEmpty ? null : description,
      genres: (_names(_info(doc, ['Genres', 'Genre(s)', 'Géneros'])) ?? '')
          .split(',')
          .map((g) => g.trim())
          .where((g) => g.isNotEmpty)
          .toList(),
      status: switch (statusText) {
        'ongoing' => SourceMangaStatus.ongoing,
        'completed' => SourceMangaStatus.completed,
        _ => SourceMangaStatus.unknown,
      },
      chapters: parseChapters(doc, base),
    );
  }

  List<SourceChapter> parseChapters(Document doc, Uri base) {
    final out = <SourceChapter>[];
    for (final li in doc.querySelectorAll('ul.chapter-list li, ul.row-content-chapter li, .list-items li.item')) {
      final link = li.querySelector('a[href]');
      final url = absUrl(base, link?.attributes['href']);
      if (url == null) continue;
      final nameEl = li.querySelector('.chapter-name') ?? link?.querySelector('span');
      final name = clean(nameEl?.text);
      if (name.isEmpty) continue;
      final dateEl = li.querySelector('.ct-update, .chapter-time') ??
          ((link?.querySelectorAll('span').length ?? 0) > 1 ? link!.querySelectorAll('span')[1] : null);
      out.add(SourceChapter(
        url: url,
        name: name,
        number: parseChapterNumber(name),
        uploadedAt: parseShortDate(dateEl?.text),
      ));
    }
    return out;
  }

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12, //
  };

  /// "06 Oct 2026", "12 Oct 26", atau hanya bulan: "Oct 26" (tgl 1, tahun 2026?
  /// situs memakai dua digit tahun, bukan hari).
  static DateTime? parseShortDate(String? raw) {
    final text = clean(raw).toLowerCase();
    if (text.isEmpty) return null;
    final full = RegExp(r'^(\d{1,2})\s+([a-z]{3})[a-z]*\.?\s+(\d{2}|\d{4})$').firstMatch(text);
    if (full != null && _months.containsKey(full[2])) {
      final y = int.parse(full[3]!);
      return DateTime(y < 100 ? 2000 + y : y, _months[full[2]]!, int.parse(full[1]!));
    }
    final monthYear = RegExp(r'^([a-z]{3})[a-z]*\.?\s+(\d{2}|\d{4})$').firstMatch(text);
    if (monthYear != null && _months.containsKey(monthYear[1])) {
      final y = int.parse(monthYear[2]!);
      return DateTime(y < 100 ? 2000 + y : y, _months[monthYear[1]]!, 1);
    }
    return parseLooseDate(text);
  }

  // =========================== Halaman ===========================

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    return parsePages(res.document, res.url);
  }

  List<String> parsePages(Document doc, Uri base) => [
        for (final img in doc.querySelectorAll('.reading-content img, .read-content img'))
          if (imgAttr(img, base) case final url?) url,
      ];
}
