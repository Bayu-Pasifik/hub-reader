// Port Dart dari extension Holotoon milik keiyoushi/extensions-source
// (Apache-2.0): src/id/holotoon.

import 'dart:convert';

import 'package:html/dom.dart';

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class HolotoonSource extends HttpSource {
  HolotoonSource({super.dio});

  @override
  String get id => 'id.holotoon';
  @override
  String get name => 'Holotoon';
  @override
  String get lang => 'id';
  @override
  String get defaultBaseUrl => 'https://holodek.run';
  @override
  ContentWarning get contentWarning => ContentWarning.mixed;

  /// Situs mewajibkan client hint Chrome yang cocok dengan User-Agent di /read/.
  @override
  Map<String, String> get extraHeaders {
    final version = RegExp(r'Chrome/(\d+)').firstMatch(HttpSource.userAgent)?.group(1);
    return version == null
        ? const {}
        : {'Sec-CH-UA': '"Chromium";v="$version", "Google Chrome";v="$version", "Not.A/Brand";v="99"'};
  }

  @override
  Future<MangaPage> popular(int page) => _browse(page, {'sort': 'popular'});

  @override
  Future<MangaPage> latest(int page) => _browse(page, {'sort': 'latest'});

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) => _browse(page, {
        'sort': filters.single('sort') ?? 'latest',
        if (query.trim().isNotEmpty) 'q': query.trim(),
        for (final key in const ['type', 'status'])
          if (filters.single(key) case final v?) key: v,
      });

  Future<MangaPage> _browse(int page, Map<String, String> params) async {
    final res = await fetchHtml(Uri.parse('$baseUrl/browse').replace(queryParameters: {
      ...params,
      'media': 'comic',
      if (page > 1) 'page': '$page',
    }));
    return parseList(res.document, res.url, page);
  }

  MangaPage parseList(Document doc, Uri pageUrl, int page) {
    // Situs menyisipkan honeypot; ambil grid katalog terakhir yang berisi /comic/.
    // Jsoup mengabaikan isi <template>, package:html tidak: honeypot (rel=nofollow)
    // di dalam <template> harus dibuang manual.
    bool inTemplate(Element e) {
      for (Element? p = e.parent; p != null; p = p.parent) {
        if (p.localName == 'template') return true;
      }
      return false;
    }

    final grids = doc
        .querySelectorAll('div.grid')
        .where((g) => !inTemplate(g) && g.querySelector('a[href^="/comic/"]') != null)
        .toList();
    if (grids.isEmpty) return const MangaPage([], hasNextPage: false);
    final seen = <String>{};
    final items = <SourceManga>[];
    // Class kartu kini "group/vz" (bukan "group"), jadi ambil semua tautan /comic/.
    for (final card in grids.first.querySelectorAll('a[href^="/comic/"]')) {
      if (card.attributes['rel'] == 'nofollow') continue;
      final url = attrAbs(card, 'href', pageUrl);
      final h3 = clean(card.querySelector('h3')?.text);
      final title = h3.isNotEmpty ? h3 : clean(card.querySelector('img')?.attributes['alt']);
      if (url == null || title.isEmpty || !seen.add(Uri.parse(url).path)) continue;
      final img = card.querySelector('img');
      items.add(SourceManga(
        url: url,
        title: title,
        thumbnailUrl: attrAbs(img, 'data-src', pageUrl) ?? attrAbs(img, 'src', pageUrl),
      ));
    }
    final hasNext =
        doc.querySelectorAll('a[href*="page="]').any((a) => (a.attributes['href'] ?? '').contains('page=${page + 1}'));
    return MangaPage(items, hasNextPage: hasNext);
  }

  @override
  Future<List<FilterDef>> filters() async => const [
        SelectFilterDef('sort', 'Urutkan', [
          FilterOption('Terbaru', 'latest'),
          FilterOption('Populer', 'popular'),
          FilterOption('Rating', 'rating'),
          FilterOption('A-Z', 'az'),
        ]),
        SelectFilterDef('type', 'Tipe', [
          FilterOption('Semua', ''),
          FilterOption('Manga', 'manga'),
          FilterOption('Manhwa', 'manhwa'),
          FilterOption('Manhua', 'manhua'),
          FilterOption('Webtoon', 'webtoon'),
        ]),
        SelectFilterDef('status', 'Status', [
          FilterOption('Semua', ''),
          FilterOption('Berjalan', 'ongoing'),
          FilterOption('Tamat', 'completed'),
          FilterOption('Hiatus', 'hiatus'),
        ]),
      ];

  /// Halaman detail & baca dilindungi pemeriksaan browser JS milik situs
  /// ("Memverifikasi browser kamu…"). Dilaporkan seperti Cloudflare supaya
  /// UI menawarkan "Buka di WebView"; setelah selesai, cookie-nya dipakai Dio.
  Future<HtmlResponse> _fetchChecked(Uri url) async {
    final res = await fetchHtml(url);
    if (res.body.contains('Memverifikasi browser')) {
      throw SourceException(SourceErrorKind.cloudflare, detail: 'Pemeriksaan browser situs', url: url);
    }
    return res;
  }

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final path = Uri.parse(mangaUrl).path.replaceFirst('/komik/', '/comic/');
    final res = await _fetchChecked(Uri.parse('$baseUrl$path'));
    return parseDetails(res.document, res.url);
  }

  static final _author =
      RegExp(r'(?:Author|Pengarang|Penulis)\s*:?\s*([^\n•|]+?)(?:\s{2,}|Artist|Ilustrator|$)', caseSensitive: false);
  static final _artist = RegExp(r'(?:Artist|Ilustrator)\s*:?\s*([^\n•|]+?)(?:\s{2,}|Status|$)', caseSensitive: false);

  SourceMangaDetails parseDetails(Document doc, Uri pageUrl) {
    final h1 = doc.querySelector('h1');
    final title = clean(h1?.text);
    if (title.isEmpty) throw const SourceException(SourceErrorKind.parse, detail: 'Judul tidak ditemukan.');
    // Akar detail: induk h1 terdekat (maks 6 tingkat) yang memuat tautan genre.
    Element? root = h1?.parent;
    for (var i = 0; i < 6 && root != null && root.querySelector('a[href*="genre="]') == null; i++) {
      root = root.parent;
    }
    root ??= h1?.parent;
    final metadata = clean(root?.text);

    final descEl = doc.querySelector('#synopsis-wrapper div[data-sr], div[data-sr], div.prose');
    String? description;
    final encoded = descEl?.attributes['data-sr'];
    if (encoded != null && encoded.isNotEmpty) {
      try {
        description = utf8.decode(base64.decode(base64.normalize(encoded))).trim();
      } on FormatException {
        description = null;
      }
    }
    description ??= nonPlaceholder(descEl?.text);

    final statusText = (root ?? doc.documentElement!)
        .querySelectorAll('span')
        .map((s) => clean(s.text).toLowerCase())
        .where((t) => const {'ongoing', 'completed', 'hiatus', 'dropped'}.contains(t))
        .firstOrNull;
    final seen = <String>{};
    return SourceMangaDetails(
      url: pageUrl.toString(),
      title: title,
      author: nonPlaceholder(_author.firstMatch(metadata)?.group(1)),
      artist: nonPlaceholder(_artist.firstMatch(metadata)?.group(1)),
      description: description,
      genres: [
        for (final a in root?.querySelectorAll('a[href*="genre="]') ?? const <Element>[])
          if (clean(a.text).isNotEmpty) clean(a.text),
      ].toSet().toList(),
      thumbnailUrl: attrAbs(
        doc
            .querySelectorAll('img')
            .where((i) => clean(i.attributes['alt']).toLowerCase() == title.toLowerCase())
            .firstOrNull,
        'src',
        pageUrl,
      ),
      status: switch (statusText) {
        'ongoing' => SourceMangaStatus.ongoing,
        'completed' => SourceMangaStatus.completed,
        'hiatus' => SourceMangaStatus.hiatus,
        'dropped' => SourceMangaStatus.cancelled,
        _ => SourceMangaStatus.unknown,
      },
      chapters: [
        for (final a in doc.querySelectorAll('a[href^="/read/"][data-chapter]'))
          if (absUrl(pageUrl, (a.attributes['href'] ?? '').split('#').first.split('?').first) case final url?
              when seen.add(url))
            _chapter(a, url),
      ],
    );
  }

  SourceChapter _chapter(Element a, String url) {
    final raw = a.attributes['data-chapter'] ?? '';
    final number = double.tryParse(RegExp(r'\d+(?:\.\d+)?').firstMatch(raw)?.group(0) ?? '');
    final label = clean(a.querySelector('span.font-semibold')?.text);
    final subtitle = clean(a.querySelector('span.truncate')?.text).replaceFirst(RegExp(r'^—\s*'), '');
    final name = [if (label.isNotEmpty) label, if (subtitle.isNotEmpty) subtitle].join(' - ');
    return SourceChapter(
      url: url,
      name: name.isNotEmpty ? name : 'Chapter ${number ?? raw}',
      number: number,
      uploadedAt: madaraLikeDate(a.querySelector('span.text-right')?.text),
    );
  }

  /// Tanggal relatif berbahasa Indonesia ("3 hari lalu").
  static DateTime? madaraLikeDate(String? raw) {
    final t = clean(raw);
    if (t.isEmpty) return null;
    return parseLooseDate(t.contains('lalu') || t.contains('ago') ? t : '$t lalu');
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await _fetchChecked(Uri.parse(chapter.url));
    var images = res.document.querySelectorAll('#reader-pages img');
    if (images.isEmpty) {
      images = res.document.querySelectorAll('main img').where((i) {
        final s = '${i.attributes['src']} ${i.attributes['data-src']}';
        return s.contains('/image/comic/');
      }).toList();
    }
    final seen = <String>{};
    final pages = [
      for (final img in images)
        if ((attrAbs(img, 'src', res.url) ?? attrAbs(img, 'data-src', res.url)) case final url?
            when !url.contains('/chapter-header/') && !url.contains('/chapter-footer/') && seen.add(url))
          url,
    ];
    if (pages.isEmpty) throw const SourceException(SourceErrorKind.parse, detail: 'Gambar bab tidak ditemukan.');
    return pages;
  }
}
