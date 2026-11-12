// Port Dart dari template kecil milik keiyoushi/extensions-source
// (Apache-2.0): lib-multisrc/colorlibanime dan lib-multisrc/hwalumi.

import 'dart:convert';

import 'package:html/dom.dart';

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

/// Basis bersama: identitas sumber dari katalog.
abstract class _CatalogHttpSource extends HttpSource {
  _CatalogHttpSource({
    required this.id,
    required this.name,
    required String baseUrl,
    required this.lang,
    required this.contentWarning,
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
}

// ===================================================================
// ColorlibAnime (KomikZoid, SekteKomik)
// ===================================================================

class ColorlibAnimeSource extends _CatalogHttpSource {
  ColorlibAnimeSource({
    required super.id,
    required super.name,
    required super.baseUrl,
    required super.lang,
    super.contentWarning = ContentWarning.safe,
  });

  @override
  int get requestsPerSecond => 3;

  @override
  Future<MangaPage> popular(int page) => search(page, '', filters: FilterValues.empty.withSingle('sort', 'view'));

  @override
  Future<MangaPage> latest(int page) => search(page, '', filters: FilterValues.empty.withSingle('sort', 'updated'));

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    final res = await fetchHtml(Uri.parse('$baseUrl/manga').replace(queryParameters: {
      'page': '$page',
      'sort': filters.single('sort') ?? 'view',
      'search': query.trim(),
    }));
    return parseList(res.document, res.url);
  }

  static String? _setBg(Element? el, Uri base) {
    final bg = el?.querySelector('.set-bg')?.attributes['data-setbg'] ?? el?.attributes['data-setbg'];
    final url = absUrl(base, bg);
    return url?.split('?').first;
  }

  MangaPage parseList(Document doc, Uri pageUrl) {
    final items = <SourceManga>[];
    for (final el in doc.querySelectorAll('.product__page__content .product__item')) {
      final url = attrAbs(el.querySelector('a.img-link') ?? el.querySelector('a'), 'href', pageUrl);
      if (url == null) continue;
      final manga =
          SourceManga(url: url, title: clean(el.querySelector('h5')?.text), thumbnailUrl: _setBg(el, pageUrl));
      if (!items.contains(manga)) items.add(manga);
    }
    return MangaPage(items, hasNextPage: doc.querySelector('.fa-angle-right') != null);
  }

  @override
  Future<List<FilterDef>> filters() async => const [
        SelectFilterDef('sort', 'Urutkan', [
          FilterOption('Paling dilihat', 'view'),
          FilterOption('Update terbaru', 'updated'),
          FilterOption('Baru', 'published'),
          FilterOption('A-Z', 'default'),
        ]),
      ];

  static final _time = RegExp(r'Date\((\d+)\)');

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    return parseDetails(res.document, res.url);
  }

  SourceMangaDetails parseDetails(Document doc, Uri pageUrl) {
    final el = doc.querySelector('.anime__details__content');
    if (el == null) throw const SourceException(SourceErrorKind.parse, detail: 'Detail seri tidak ditemukan.');
    final statusText = whereContains(el, 'li', const ['status']).firstOrNull?.text ?? '';
    final chapters = <SourceChapter>[
      for (final a in doc.querySelectorAll('.anime__details__episodes a'))
        if (attrAbs(a, 'href', pageUrl) case final url?)
          SourceChapter(url: url, name: clean(a.text), number: parseChapterNumber(clean(a.text))),
    ];
    // Hanya bab terbaru yang punya tanggal (dari script lastUpdated).
    final ms = int.tryParse(_time
            .firstMatch(
                doc.querySelectorAll('script').map((s) => s.text).where((t) => t.contains('lastUpdated')).join())
            ?.group(1) ??
        '');
    if (ms != null && chapters.isNotEmpty) {
      final first = chapters.first;
      chapters[0] = SourceChapter(
          url: first.url, name: first.name, number: first.number, uploadedAt: DateTime.fromMillisecondsSinceEpoch(ms));
    }
    return SourceMangaDetails(
      url: pageUrl.toString(),
      title: clean(el.querySelector('h3')?.text),
      author: nonPlaceholder(el.querySelector('h3 + span')?.text),
      description: nonPlaceholder(el.querySelectorAll('p').map((p) => p.text).join(' ')),
      thumbnailUrl: _setBg(el, pageUrl),
      status: statusText.contains('Ongoing')
          ? SourceMangaStatus.ongoing
          : statusText.contains('Complete')
              ? SourceMangaStatus.completed
              : SourceMangaStatus.unknown,
      chapters: chapters,
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    final pages = [
      for (final img in res.document.querySelectorAll('.container .read-img > img'))
        if (imgAttr(img, res.url) case final url?) url,
    ];
    if (pages.isEmpty) throw const SourceException(SourceErrorKind.parse, detail: 'Gambar bab tidak ditemukan.');
    return pages;
  }
}

// ===================================================================
// Hwalumi (LumosKomik, Hwago)
// ===================================================================

class HwalumiSource extends _CatalogHttpSource {
  HwalumiSource({
    required super.id,
    required super.name,
    required super.baseUrl,
    required super.lang,
    super.contentWarning = ContentWarning.safe,
  });

  @override
  Future<MangaPage> popular(int page) => _list(page, Uri.parse('$baseUrl/all-series'), {'sort': 'popular'});

  @override
  Future<MangaPage> latest(int page) => _list(page, Uri.parse('$baseUrl/all-series'), {'sort': 'latest'});

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) => _list(
        page,
        Uri.parse('$baseUrl/browse'),
        {
          if (query.trim().isNotEmpty) 'q': query.trim(),
          'sort': filters.single('sort') ?? 'latest',
          if (filters.single('status') case final s?) 'status': s,
          if (filters.single('type') case final t?) 'type': t,
        },
      );

  Future<MangaPage> _list(int page, Uri base, Map<String, String> params) async {
    final res = await fetchHtml(base.replace(queryParameters: {...params, 'lang': 'id', 'page': '$page'}));
    return parseList(res.document, res.url, page);
  }

  MangaPage parseList(Document doc, Uri pageUrl, int page) {
    final items = <SourceManga>[];
    for (final a in doc.querySelectorAll('a[href^="/comic/"]')) {
      // Lewati entri "honeypot" tersembunyi & gambar bendera.
      if (a.parent?.attributes['aria-hidden'] == 'true' || _hiddenAncestor(a)) continue;
      final img = a.querySelectorAll('img').where((i) => !(i.attributes['src'] ?? '').contains('flagcdn')).firstOrNull;
      if (img == null) continue;
      final title = clean(img.attributes['alt']).isNotEmpty ? clean(img.attributes['alt']) : clean(a.text);
      final url = attrAbs(a, 'href', pageUrl);
      if (title.isEmpty || url == null) continue;
      final manga = SourceManga(url: url, title: title, thumbnailUrl: attrAbs(img, 'src', pageUrl));
      if (!items.contains(manga)) items.add(manga);
    }
    final hasNext =
        doc.querySelectorAll('a[href]').any((a) => (a.attributes['href'] ?? '').contains('page=${page + 1}'));
    return MangaPage(items, hasNextPage: hasNext);
  }

  static bool _hiddenAncestor(Element e) {
    for (Element? p = e.parent; p != null; p = p.parent) {
      if (p.attributes['aria-hidden'] == 'true') return true;
    }
    return false;
  }

  @override
  Future<List<FilterDef>> filters() async => const [
        SelectFilterDef('sort', 'Urutkan', [
          FilterOption('Terbaru', 'latest'),
          FilterOption('Populer', 'popular'),
          FilterOption('Rating', 'rating'),
          FilterOption('A-Z', 'az'),
        ]),
        SelectFilterDef('status', 'Status', [
          FilterOption('Semua', ''),
          FilterOption('Berjalan', 'ongoing'),
          FilterOption('Tamat', 'completed'),
          FilterOption('Hiatus', 'hiatus'),
        ]),
      ];

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final slug = Uri.parse(mangaUrl).pathSegments.where((s) => s.isNotEmpty).last;
    final res = await fetchHtml(Uri.parse('$baseUrl/comic/$slug'));
    return parseDetails(res.document, res.url);
  }

  /// `div:has(> span:containsOwn(Label)) > span:last-child`
  static String? _labeled(Document doc, String label, {String childTag = 'span'}) {
    for (final div in doc.querySelectorAll('div')) {
      final kids = div.children.where((c) => c.localName == childTag).toList();
      if (kids.length >= 2 && ownText(kids.first).contains(label)) {
        final v = clean(kids.last.text);
        return v.isEmpty || v.toLowerCase() == 'updating' ? null : v;
      }
    }
    return null;
  }

  SourceMangaDetails parseDetails(Document doc, Uri pageUrl) {
    final encoded = doc.querySelector('div[data-sr]')?.attributes['data-sr'];
    String? description;
    if (encoded != null && encoded.trim().isNotEmpty) {
      try {
        description = utf8.decode(base64.decode(base64.normalize(encoded.trim()))).trim();
      } on FormatException {
        description = null;
      }
    }
    description ??= nonPlaceholder(doc.querySelector('p.text-sm')?.text);
    final status = (_labeled(doc, 'Status', childTag: 'div') ?? '').toLowerCase();
    return SourceMangaDetails(
      url: pageUrl.toString(),
      title: clean(doc.querySelector('h1')?.text),
      thumbnailUrl: attrAbs(doc.querySelector('aside img[src*="/cover"]'), 'src', pageUrl),
      description: description,
      author: _labeled(doc, 'Author'),
      artist: _labeled(doc, 'Artist'),
      genres: {
        for (final a in doc.querySelectorAll('a[href*="genre="]'))
          if (clean(a.text).isNotEmpty) clean(a.text),
      }.toList(),
      status: switch (status) {
        'completed' || 'tamat' => SourceMangaStatus.completed,
        'ongoing' || 'berjalan' => SourceMangaStatus.ongoing,
        'hiatus' => SourceMangaStatus.hiatus,
        _ => SourceMangaStatus.unknown,
      },
      chapters: [
        for (final a in doc.querySelectorAll('a[href*="/read/"][data-chapter]'))
          if (attrAbs(a, 'href', pageUrl) case final url?)
            SourceChapter(
              url: url,
              name: clean((a.querySelector('span.text-sm') ?? a).text),
              number: double.tryParse(a.attributes['data-chapter']?.trim() ?? ''),
              uploadedAt: parseLooseDate('${a.querySelector('[class*="tabular-nums"]')?.text ?? ''} lalu'),
            ),
      ],
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    final pages = [
      for (final img in res.document.querySelectorAll('img[alt^="Page "]'))
        if (attrAbs(img, 'src', res.url) case final url? when !url.contains('/api/image/p/')) url,
    ];
    if (pages.isEmpty) throw const SourceException(SourceErrorKind.parse, detail: 'Gambar bab tidak ditemukan.');
    return pages;
  }
}
