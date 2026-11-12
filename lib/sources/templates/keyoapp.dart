// Port Dart dari template Keyoapp milik keiyoushi/extensions-source
// (Apache-2.0): lib-multisrc/keyoapp (Keyoapp.kt, KeyoappV2.kt, plus override
// situs ArtLapsa/KitsuneDawn/RitharScans untuk varian Livewire).
//
// Tiga varian situs:
// - classic: beranda + /latest/ + /series/ (semua seri di satu halaman,
//   pencarian & filter dilakukan di sisi klien). Gambar bab dari atribut
//   `uid` + host CDN di script `realUrl`.
// - livewire: /search?sort=&page=, /latest?page=, gambar bab dari
//   `x-data="immersiveReader(... JSON.parse('...'))"`.
// - v2: endpoint `?_ajax=search`, `?_ajax=recent-chapters`,
//   `?_chapters_html=1&series_slug=`.

import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

enum KeyoappVariant { classic, livewire, v2 }

final _relativeDate = RegExp(r'(a|an|one|\d+)\s*([a-z]+)\s+ago');

/// "Aug 3, 2026", atau relatif dengan satuan pendek: "2d ago", "5 hrs ago",
/// "3mo ago" (KeyoappBase.parseRelativeDate).
DateTime? parseKeyoappDate(String? raw, {DateTime? now}) {
  final text = clean(raw).toLowerCase();
  final match = _relativeDate.firstMatch(text);
  if (match == null) return parseLooseDate(text, now: now);
  final n = int.tryParse(match[1]!) ?? 1;
  final base = now ?? DateTime.now();
  return switch (match[2]!) {
    's' || 'sec' || 'secs' || 'second' || 'seconds' => base.subtract(Duration(seconds: n)),
    'm' || 'min' || 'mins' || 'minute' || 'minutes' => base.subtract(Duration(minutes: n)),
    'h' || 'hr' || 'hrs' || 'hour' || 'hours' => base.subtract(Duration(hours: n)),
    'd' || 'day' || 'days' => base.subtract(Duration(days: n)),
    'w' || 'wk' || 'wks' || 'week' || 'weeks' => base.subtract(Duration(days: 7 * n)),
    'mo' || 'mos' || 'month' || 'months' => DateTime(base.year, base.month - n, base.day),
    'y' || 'yr' || 'yrs' || 'year' || 'years' => DateTime(base.year - n, base.month, base.day),
    _ => null,
  };
}

KeyoappVariant keyoappVariantFrom(String? raw) => switch (raw) {
      'v2' => KeyoappVariant.v2,
      'livewire' => KeyoappVariant.livewire,
      _ => KeyoappVariant.classic,
    };

class KeyoappSource extends HttpSource {
  KeyoappSource({
    required this.id,
    required this.name,
    required String baseUrl,
    required this.lang,
    this.contentWarning = ContentWarning.safe,
    this.variant = KeyoappVariant.classic,
    this.popularFromSearch = false,
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

  final KeyoappVariant variant;

  /// Classic: beranda tidak punya bagian populer yang bisa dibaca, jadi
  /// "populer" memakai daftar /series/ (GenzToons).
  final bool popularFromSearch;

  static const _types = ['Manhwa', 'Manhua', 'Manga', 'Mangatoon', 'Comic'];
  static const _statuses = ['Ongoing', 'Completed', 'Dropped', 'Hiatus'];

  // =========================== Daftar ===========================

  @override
  Future<MangaPage> popular(int page) async {
    switch (variant) {
      case KeyoappVariant.v2:
        return _v2List(page, sort: 'popular');
      case KeyoappVariant.livewire:
        return search(page, '', filters: FilterValues.empty.withSingle('sort', 'popular'));
      case KeyoappVariant.classic:
        if (popularFromSearch || page > 1) return popularFromSearch ? search(page, '') : _empty;
        final res = await fetchHtml(Uri.parse('$baseUrl/'));
        final items = parsePopularClassic(res.document, res.url);
        // Beranda berubah? Pakai daftar semua seri.
        return items.isEmpty ? search(1, '') : MangaPage(items, hasNextPage: false);
    }
  }

  static const _empty = MangaPage([], hasNextPage: false);

  @override
  Future<MangaPage> latest(int page) async {
    switch (variant) {
      case KeyoappVariant.v2:
        final res = await fetchHtml(baseUri.replace(queryParameters: {'_ajax': 'recent-chapters', 'page': '$page'}),
            headers: const {'X-Requested-With': 'XMLHttpRequest'});
        final items = <SourceManga>[
          for (final card in res.document.querySelectorAll('article.ru-card'))
            if (_v2LatestCard(card, res.url) case final manga?) manga,
        ];
        final next = res.document
            .querySelectorAll('button[aria-label="Next recently updated page"]')
            .any((b) => !b.attributes.containsKey('disabled'));
        return MangaPage(_dedupe(items), hasNextPage: next);
      case KeyoappVariant.livewire:
        final res = await fetchHtml(Uri.parse('$baseUrl/latest').replace(queryParameters: {'page': '$page'}));
        final items = parseCards(res.document.querySelectorAll('div.grid > div.group'), res.url);
        return MangaPage(items, hasNextPage: res.document.querySelector('a[href*="?page=${page + 1}"]') != null);
      case KeyoappVariant.classic:
        if (page > 1) return _empty;
        final res = await fetchHtml(Uri.parse('$baseUrl/latest/'));
        return MangaPage(parseCards(res.document.querySelectorAll('div.grid > div.group'), res.url),
            hasNextPage: false);
    }
  }

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    switch (variant) {
      case KeyoappVariant.v2:
        return _v2List(page, query: query, filters: filters, sort: filters.single('sort'));
      case KeyoappVariant.livewire:
        final params = <String, String>{
          if (page > 1) 'page': '$page',
          if (query.trim().isNotEmpty) 'title': query.trim(),
          if (filters.single('sort') case final sort?) 'sort': sort,
          if (filters.single('genre') case final genre?) 'genre': genre,
          if (filters.single('type') case final type?) 'type': type,
          if (filters.single('status') case final status?) 'status': status,
        };
        final res = await fetchHtml(Uri.parse('$baseUrl/search').replace(queryParameters: params));
        final items = parseCards(res.document.querySelectorAll('main#main-content [wire\\:key^="serie"]'), res.url);
        return MangaPage(items, hasNextPage: items.length >= 20);
      case KeyoappVariant.classic:
        if (page > 1) return _empty;
        final res = await fetchHtml(Uri.parse('$baseUrl/series/'));
        return MangaPage(parseSeriesClassic(res.document, res.url, query: query, filters: filters),
            hasNextPage: false);
    }
  }

  // ---------- classic ----------

  static final _popularHeading = RegExp(r'^(popular|popularie|trending)\b', caseSensitive: false);

  /// Kartu di bawah judul "Popular"/"Trending" di beranda, atau carousel
  /// Splide (NyanuKafe).
  List<SourceManga> parsePopularClassic(Document doc, Uri pageUrl) {
    final slides = doc.querySelectorAll('.series-splide .splide__slide').where((e) => !e.classes.contains('splide__slide--clone'));
    if (slides.isNotEmpty) return parseCards(slides, pageUrl);
    for (final heading in doc.querySelectorAll('h1, h2, h3, div')) {
      if (heading.children.length > 1 || !_popularHeading.hasMatch(clean(heading.text))) continue;
      // Struktur: <div>(<h2>Trending</h2>)</div> + <div>kartu</div>.
      for (Element? node = heading; node != null && node.localName != 'body'; node = node.parent) {
        final next = node.nextElementSibling;
        if (next == null) continue;
        final cards = next.querySelectorAll('.group');
        if (cards.isNotEmpty) return parseCards(cards, pageUrl);
        break;
      }
    }
    return const [];
  }

  /// `/series/` berisi semua seri; filter judul/genre/tipe/status di klien.
  List<SourceManga> parseSeriesClassic(Document doc, Uri pageUrl,
      {String query = '', FilterValues filters = FilterValues.empty}) {
    final q = query.trim().toLowerCase();
    final genres = filters.multi('genre').map((g) => g.toLowerCase()).toList();
    final type = filters.single('type');
    final status = filters.single('status');
    final entries = doc.querySelectorAll('#searched_series_page > button').where((e) {
      if (_isNovel(e)) return false;
      if (q.isNotEmpty && !(e.attributes['title'] ?? '').toLowerCase().contains(q)) return false;
      if (type != null && (e.attributes['data-type'] ?? '').toLowerCase() != type) return false;
      if (status != null && (e.attributes['data-status'] ?? '').toLowerCase() != status) return false;
      if (genres.isNotEmpty) {
        final tags = _tags(e.attributes['tags']);
        if (!genres.every(tags.contains)) return false;
      }
      return true;
    });
    return parseCards(entries, pageUrl);
  }

  static Set<String> _tags(String? raw) {
    try {
      return asList(jsonDecode((raw ?? '[]').replaceAll('___', "'"))).map((t) => '$t'.toLowerCase()).toSet();
    } catch (_) {
      return const {};
    }
  }

  static bool _isNovel(Element e) =>
      (e.attributes['data-type'] ?? '').toLowerCase() == 'novel' ||
      e.querySelectorAll('[data-type]').any((x) => x.attributes['data-type']!.toLowerCase() == 'novel') ||
      e.querySelectorAll('span').any((s) => clean(s.text).toLowerCase() == 'novel');

  static final _bgUrl = RegExp(r'''url\(['"]?([^'")]+)''');

  /// Sampul: `<img alt="... cover">` (Livewire) atau `background-image:url()`.
  static String? cardThumbnail(Element card, Uri base) {
    final img = card.querySelectorAll('img').where((i) => (i.attributes['alt'] ?? '').endsWith(' cover')).firstOrNull;
    if (img != null) return imgAttr(img, base);
    for (final el in [card, ...card.querySelectorAll('[style]')]) {
      final style = el.attributes['style'] ?? '';
      if (!style.contains('background-image') && !style.contains('photoURL')) continue;
      final url = _bgUrl.firstMatch(style)?.group(1);
      if (url != null) return _resize(absUrl(base, url.trim()));
    }
    return null;
  }

  /// Keyoapp/wsrv mengembalikan ukuran sesuai parameter `w`.
  /// Ganti teks, bukan lewat Uri: parameter `url=` milik wsrv tidak boleh
  /// di-encode ulang.
  static String? _resize(String? url) => url?.replaceFirstMapped(_widthParam, (m) => '${m[1]}w=480');

  static final _widthParam = RegExp(r'([?&])w=\d+');

  List<SourceManga> parseCards(Iterable<Element> cards, Uri pageUrl) {
    final items = <SourceManga>[];
    for (final card in cards) {
      if (_isNovel(card)) continue;
      final link = card.localName == 'a' ? card : card.querySelector('a[href]');
      final url = attrAbs(link, 'href', pageUrl);
      if (link == null || url == null) continue;
      final title = clean(link.attributes['title']).isNotEmpty
          ? clean(link.attributes['title'])
          : clean(card.attributes['title']).isNotEmpty
              ? clean(card.attributes['alt'] ?? card.attributes['title'])
              : clean(card.querySelector('h2, h3')?.text);
      if (title.isEmpty) continue;
      items.add(SourceManga(url: url, title: title, thumbnailUrl: cardThumbnail(card, pageUrl)));
    }
    return _dedupe(items);
  }

  static List<SourceManga> _dedupe(List<SourceManga> items) {
    final seen = <String>{};
    return [for (final m in items) if (seen.add(m.url)) m];
  }

  // ---------- v2 ----------

  Future<MangaPage> _v2List(int page, {String? query, FilterValues filters = FilterValues.empty, String? sort}) async {
    final params = <String, dynamic>{
      '_ajax': 'search',
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (sort != null) 'sort': sort,
      'offset': '${(page - 1) * 20}',
      if (filters.single('type') case final type?) 'type': type,
      if (filters.single('status') case final status?) 'status': status,
      if (filters.multi('genre').isNotEmpty) 'tag[]': filters.multi('genre'),
    };
    final json = asMap(await fetchJson(baseUri.replace(queryParameters: params),
        headers: const {'X-Requested-With': 'XMLHttpRequest'}));
    final doc = html_parser.parse(asString(json['html']) ?? '');
    final items = <SourceManga>[
      for (final a in doc.querySelectorAll('a.group[href]'))
        if (!_isNovel(a) && attrAbs(a, 'href', baseUri) != null)
          SourceManga(
            url: attrAbs(a, 'href', baseUri)!,
            title: clean(a.querySelector('h2')?.text),
            thumbnailUrl: absUrl(baseUri, a.querySelector('img')?.attributes['data-src']),
          ),
    ];
    return MangaPage(_dedupe(items), hasNextPage: asBool(json['has_more']));
  }

  SourceManga? _v2LatestCard(Element card, Uri base) {
    final link = card.querySelector('h2.ru-title > a');
    final url = attrAbs(link, 'href', base);
    if (link == null || url == null) return null;
    return SourceManga(
      url: url,
      title: clean(link.text),
      thumbnailUrl: absUrl(base, card.querySelector('img.ru-cover-img')?.attributes['data-src']),
    );
  }

  // =========================== Filter ===========================

  @override
  Future<List<FilterDef>> filters() async {
    if (variant == KeyoappVariant.livewire) return _livewireFilters();
    final genres = await _genres().catchError((Object _) => const <FilterOption>[]);
    final sorts = switch (variant) {
      KeyoappVariant.v2 => const [
          FilterOption('Latest', 'latest'),
          FilterOption('Trending', 'trending'),
          FilterOption('Popular', 'popular'),
          FilterOption('Most Viewed', 'views'),
          FilterOption('Top Rated', 'rating'),
          FilterOption('A-Z', 'az'),
          FilterOption('Z-A', 'za'),
        ],
      _ => const <FilterOption>[],
    };
    return [
      if (sorts.isNotEmpty) SelectFilterDef('sort', 'Sort by', sorts),
      SelectFilterDef('type', 'Type', [
        const FilterOption('All', ''),
        for (final t in variant == KeyoappVariant.v2 ? _types.take(4) : _types) FilterOption(t, t.toLowerCase()),
      ]),
      SelectFilterDef('status', 'Status', [
        const FilterOption('All', ''),
        for (final s in variant == KeyoappVariant.v2 ? _statuses.take(2) : _statuses) FilterOption(s, s.toLowerCase()),
      ]),
      if (genres.isNotEmpty) MultiSelectFilterDef('genre', 'Genre', genres),
    ];
  }

  /// Livewire: opsi diambil dari `<select wire:model.live="...">` di /search
  /// (nilainya beda antar situs, mis. status "droped").
  Future<List<FilterDef>> _livewireFilters() async {
    final res = await fetchHtml(Uri.parse('$baseUrl/search'));
    List<FilterOption> options(String key) {
      final seen = <String>{};
      return [
        for (final o in res.document.querySelectorAll('[wire\\:model\\.live="$key"] option'))
          if (seen.add(o.attributes['value'] ?? ''))
            FilterOption(clean(o.text).isEmpty ? 'All' : clean(o.text), o.attributes['value'] ?? ''),
      ];
    }

    return [
      for (final (key, label) in const [('sort', 'Sort by'), ('type', 'Type'), ('status', 'Status'), ('genre', 'Genre')])
        if (options(key) case final opts when opts.length > 1)
          SelectFilterDef(key, label, [
            if (!opts.any((o) => o.value.isEmpty)) const FilterOption('All', ''),
            ...opts,
          ]),
    ];
  }

  static final _dropdownItems = RegExp(r'type:\s*"genre",[\s\S]*?items:\s*\[([\s\S]*?)\]');
  static final _displayName = RegExp(r'''displayName:\s*["']([^"']+)["'][\s\S]*?value:\s*["']([^"']+)["']''');

  Future<List<FilterOption>> _genres() async {
    switch (variant) {
      case KeyoappVariant.v2:
        final res = await fetchHtml(baseUri.replace(queryParameters: {'browse': '1'}));
        final tags = <String>{
          for (final a in res.document.querySelectorAll('#fsel-genres a[role=option][href]'))
            if (Uri.tryParse(attrAbs(a, 'href', res.url) ?? '')?.queryParameters['tag[]'] case final tag?) tag,
        };
        return [for (final t in tags) FilterOption(t.isEmpty ? t : t[0].toUpperCase() + t.substring(1), t)];
      case KeyoappVariant.livewire:
      case KeyoappVariant.classic:
        final res = await fetchHtml(Uri.parse('$baseUrl/series/'));
        final script = res.document
            .querySelectorAll('script')
            .map((s) => s.text)
            .firstWhere((t) => t.contains('initializeDropdownMenu'), orElse: () => '');
        final items = _dropdownItems.firstMatch(script)?.group(1) ?? '';
        final options = [
          for (final m in _displayName.allMatches(items)) FilterOption(m.group(1)!, m.group(2)!.toLowerCase()),
        ]..sort((a, b) => a.label.compareTo(b.label));
        return options;
    }
  }

  // =========================== Detail ===========================

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    if (variant == KeyoappVariant.v2) {
      final slug = res.document.querySelector('[data-series-uid]')?.attributes['data-series-slug'] ??
          Uri.parse(mangaUrl).pathSegments.where((s) => s.isNotEmpty).lastOrNull;
      if (slug == null) throw const SourceException(SourceErrorKind.parse, detail: 'Seri tidak ditemukan.');
      final json = asMap(await fetchJson(baseUri.replace(queryParameters: {'_chapters_html': '1', 'series_slug': slug}),
          headers: const {'X-Requested-With': 'XMLHttpRequest'}));
      return parseDetailsV2(res.document, res.url, html_parser.parse(asString(json['rows_html']) ?? ''));
    }
    return parseDetails(res.document, res.url);
  }

  /// Nilai di samping label, mis. `<div><img><span>Status</span></div><div>ongoing</div>`.
  static String? _metaValue(Document doc, String label) {
    for (final span in doc.querySelectorAll('span')) {
      if (clean(span.text) != label) continue;
      final value = span.parent?.nextElementSibling;
      final text = clean(value?.text);
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  /// Livewire: `<dt>Author</dt><dd>..</dd>`.
  static String? _dtValue(Document doc, String label) {
    for (final dt in doc.querySelectorAll('dt')) {
      if (!clean(dt.text).contains(label)) continue;
      final dd = dt.nextElementSibling;
      if (dd?.localName == 'dd') return nonPlaceholder(dd!.text);
    }
    return null;
  }

  static SourceMangaStatus _status(String? raw) => switch (clean(raw).toLowerCase()) {
        'ongoing' => SourceMangaStatus.ongoing,
        'dropped' => SourceMangaStatus.cancelled,
        'paused' || 'hiatus' => SourceMangaStatus.hiatus,
        'completed' => SourceMangaStatus.completed,
        final s => parseStatus(s),
      };

  SourceMangaDetails parseDetails(Document doc, Uri pageUrl) {
    final livewire = variant == KeyoappVariant.livewire;
    final h1 = doc.querySelector('div.grid > h1') ?? doc.querySelector('h1');
    if (h1 == null) throw const SourceException(SourceErrorKind.parse, detail: 'Detail seri tidak ditemukan.');

    String? thumb;
    if (livewire) {
      thumb = cardThumbnail(doc.body ?? doc.documentElement!, pageUrl);
    } else {
      final photo = doc.querySelectorAll('[style*=photoURL]').firstOrNull;
      thumb = photo == null ? null : cardThumbnail(photo, pageUrl);
    }
    thumb ??= doc.querySelector('meta[property="og:image"]')?.attributes['content'];

    final statusText = livewire
        ? clean(doc.querySelector('a[aria-label=Status]')?.text)
        : _metaValue(doc, 'Status');
    final type = livewire ? clean(doc.querySelector('a[aria-label=Type]')?.text) : _metaValue(doc, 'Type');
    final genreLinks = doc.querySelectorAll(livewire ? 'a[href*="/genres/"]' : 'a[href*="genre="]');
    final genres = <String>{
      if (type != null && type.isNotEmpty) type[0].toUpperCase() + type.substring(1),
      // Genre di dekat judul; tautan genre lain (menu, kartu) diabaikan.
      for (final a in genreLinks)
        if (h1.parent?.querySelectorAll('a').contains(a) ?? false) clean(a.text).replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), ''),
    }.where((g) => g.isNotEmpty).toList();

    final synopsis = clean(doc.querySelector('#expand_content p')?.text);
    final altNames = [
      for (final s in doc.querySelectorAll(livewire
          ? 'details[data-testid=series-other-names] li.select-all'
          : '#expand_content .grid.flex-wrap span'))
        if (clean(s.text).isNotEmpty && clean(s.text) != 'No alternative titles.') clean(s.text),
    ];
    final description = [
      if (synopsis.isNotEmpty) synopsis,
      if (altNames.isNotEmpty) 'Alternative names:\n${altNames.map((n) => '- $n').join('\n')}',
    ].join('\n\n');

    return SourceMangaDetails(
      url: pageUrl.toString(),
      title: clean(h1.text),
      thumbnailUrl: thumb,
      author: livewire ? _dtValue(doc, 'Author') : nonPlaceholder(_metaValue(doc, 'Author')),
      artist: livewire ? _dtValue(doc, 'Artist') : nonPlaceholder(_metaValue(doc, 'Artist')),
      description: description.isEmpty ? null : description,
      genres: genres,
      status: _status(statusText),
      chapters: parseChapters(doc, pageUrl),
    );
  }

  static bool _isPaid(Element e) => e.querySelectorAll('img').any((img) {
        final alt = (img.attributes['alt'] ?? '').split(RegExp(r'\s+'));
        return alt.contains('Coin') || (img.attributes['src'] ?? '').contains('star-circle');
      });

  static bool _isUpcoming(Element e) => e.querySelectorAll('.text-sm span').any((s) => s.text.contains('Upcoming'));

  /// Bab gratis saja (Kotlin: "show paid chapters" mati secara bawaan).
  List<SourceChapter> parseChapters(Document doc, Uri pageUrl) {
    final container = doc.getElementById('chapters');
    if (container == null) return const [];
    final chapters = <SourceChapter>[];
    for (final row in container.children) {
      if (row.localName != 'a' && row.localName != 'div') continue;
      if (_isUpcoming(row) || _isPaid(row)) continue;
      final link = row.localName == 'a' ? row : row.querySelector('a[href]');
      final url = attrAbs(link, 'href', pageUrl);
      if (url == null) continue;
      final name = clean(row.querySelector('.text-sm')?.text).isNotEmpty
          ? clean(row.querySelector('.text-sm')!.text)
          : clean(link!.attributes['title']);
      final date = row.attributes['d'] ?? row.querySelector('.text-xs')?.text;
      chapters.add(SourceChapter(
        url: url,
        name: name,
        number: parseChapterNumber(name),
        uploadedAt: parseKeyoappDate(date),
      ));
    }
    return chapters;
  }

  SourceMangaDetails parseDetailsV2(Document doc, Uri pageUrl, Document rows) {
    final h1 = doc.querySelector('h1');
    if (h1 == null) throw const SourceException(SourceErrorKind.parse, detail: 'Detail seri tidak ditemukan.');
    // "Manga · Fantasy · Ongoing"
    final meta = clean(doc.querySelector('.l2-meta span')?.text).split('·').map(clean).toList();
    final status = meta.map(_status).firstWhere((s) => s != SourceMangaStatus.unknown,
        orElse: () => SourceMangaStatus.unknown);
    String? metaValue(String label) {
      for (final span in doc.querySelectorAll('span.text-xs')) {
        if (clean(span.text) == label) return nonPlaceholder(span.parent?.nextElementSibling?.text);
      }
      return null;
    }

    final chapters = <SourceChapter>[
      for (final a in rows.querySelectorAll('a.chapter-row[href]'))
        if (a.attributes['data-ch-locked'] != '1' && attrAbs(a, 'href', pageUrl) != null)
          SourceChapter(
            url: attrAbs(a, 'href', pageUrl)!,
            name: clean(a.attributes['data-ch-label']),
            number: parseChapterNumber(clean(a.attributes['data-ch-label'])),
            uploadedAt: parseKeyoappDate(a.querySelector('.ch-date-row span:last-child')?.text),
          ),
    ];
    return SourceMangaDetails(
      url: pageUrl.toString(),
      title: clean(h1.text),
      thumbnailUrl: doc.querySelector('meta[property="og:image"]')?.attributes['content'],
      author: metaValue('Author'),
      artist: metaValue('Artist'),
      description: nonPlaceholder(doc.getElementById('series-desc')?.text),
      genres: [for (final a in doc.querySelectorAll('a[href*="?browse&tag"]')) clean(a.text)],
      status: status,
      chapters: chapters,
    );
  }

  // =========================== Halaman ===========================

  static final _cdnHost = RegExp(r'realUrl\s*=\s*`[^`]+//([^/]+)');
  static final _cdnClean = RegExp(r'\$\{[^}]*\}');
  static final _oldCdn = RegExp(r'^(https?:)?//cdn\d*\.keyoapp\.com');
  static final _pagesJson = RegExp(r"JSON\.parse\('((?:[^'\\]|\\.)*)'\)");

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    return parsePages(res.document, res.body, res.url);
  }

  List<String> parsePages(Document doc, String body, Uri pageUrl) {
    switch (variant) {
      case KeyoappVariant.v2:
        return [
          for (final img in doc.querySelectorAll('#strip-reader img.reader-page'))
            if (imgAttr(img, pageUrl) case final url?) url,
        ];
      case KeyoappVariant.livewire:
        final xData = doc.querySelectorAll('[x-data]').map((e) => e.attributes['x-data']!).firstWhere(
            (x) => x.startsWith('immersiveReader'),
            orElse: () => '');
        final raw = _pagesJson.firstMatch(xData)?.group(1);
        if (raw == null || raw.isEmpty) {
          throw const SourceException(SourceErrorKind.parse,
              detail: 'Bab terkunci: login & beli bab ini lewat WebView untuk membaca.');
        }
        // Isi literal JS '...': \uXXXX dan escape lain diurai sebagai string JSON.
        final decoded = jsonDecode('"${raw.replaceAll(r"\'", "'").replaceAll('"', r'\"')}"') as String;
        return [
          for (final p in asList(jsonDecode(decoded)))
            if (asString(asMap(p)['path']) case final path?) path,
        ];
      case KeyoappVariant.classic:
        final imgs = doc.querySelectorAll('#pages > img');
        final uids = [for (final img in imgs) if ((img.attributes['uid'] ?? '').isNotEmpty) img.attributes['uid']!];
        if (uids.isNotEmpty) {
          final host = _cdnHost.firstMatch(body)?.group(1)?.replaceAll(_cdnClean, '');
          if (host == null) {
            throw const SourceException(SourceErrorKind.parse, detail: 'Host CDN gambar tidak ditemukan.');
          }
          return [for (final uid in uids) 'https://$host/uploads/$uid'];
        }
        return [
          for (final img in imgs)
            if (imgAttr(img, pageUrl) case final url? when _oldCdn.hasMatch(url)) url,
        ];
    }
  }
}
