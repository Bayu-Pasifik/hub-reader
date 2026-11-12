// Port Dart dari extension Komiku milik keiyoushi/extensions-source
// (Apache-2.0): src/id/komiku/src/eu/kanade/tachiyomi/extension/id/komiku/Komiku.kt

import 'package:html/dom.dart';

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

/// Komiku: daftar dari api.komiku.org (HTML), detail & bab dari komiku.org.
class KomikuSource extends HttpSource {
  KomikuSource({super.dio});

  @override
  String get id => 'id.komiku';
  @override
  String get name => 'Komiku';
  @override
  String get lang => 'id';
  @override
  String get baseUrl => 'https://komiku.org';
  @override
  ContentWarning get contentWarning => ContentWarning.safe;
  @override
  int get requestsPerSecond => 2;

  static const apiUrl = 'https://api.komiku.org';

  // ---------------------------------------------------------------- daftar

  @override
  Future<MangaPage> popular(int page) => _list(Uri.parse(
        page > 1 ? '$apiUrl/other/hot/page/$page/' : '$apiUrl/other/hot/',
      ).replace(queryParameters: {'orderby': 'meta_value_num'}));

  @override
  Future<MangaPage> latest(int page) =>
      _list(_mangaApiUrl(page).replace(queryParameters: {'orderby': 'modified'}));

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) =>
      _list(searchUrl(page, query, filters));

  /// Parameter sama dengan UriPartFilter di Filters.kt Komiku.
  Uri searchUrl(int page, String query, FilterValues filters) => _mangaApiUrl(page).replace(
        queryParameters: {
          if (query.trim().isNotEmpty) 's': query.trim(),
          for (final key in const ['tipe', 'orderby', 'genre', 'genre2', 'statusmanga'])
            if (filters.single(key) case final value?) key: value,
        },
      );

  @override
  Future<List<FilterDef>> filters() async => const [
        SelectFilterDef('orderby', 'Urutkan', [
          FilterOption('Default', ''),
          FilterOption('Chapter terbaru', 'modified'),
          FilterOption('Komik terbaru', 'date'),
          FilterOption('Peringkat', 'meta_value_num'),
          FilterOption('Acak', 'rand'),
        ]),
        SelectFilterDef('tipe', 'Tipe', [
          FilterOption('Semua', ''),
          FilterOption('Manga', 'manga'),
          FilterOption('Manhua', 'manhua'),
          FilterOption('Manhwa', 'manhwa'),
        ]),
        SelectFilterDef('statusmanga', 'Status', [
          FilterOption('Semua', ''),
          FilterOption('Berjalan', 'ongoing'),
          FilterOption('Tamat', 'end'),
        ]),
        SelectFilterDef('genre', 'Genre 1', [FilterOption('Semua', ''), ..._genres]),
        SelectFilterDef('genre2', 'Genre 2', [FilterOption('Semua', ''), ..._genres]),
      ];

  static const _genres = [
    FilterOption('Academy', 'academy'),
    FilterOption('Action', 'action'),
    FilterOption('Adaptation', 'adaptation'),
    FilterOption('Adult', 'adult'),
    FilterOption('Adventure', 'adventure'),
    FilterOption('Apocalypse', 'apocalypse'),
    FilterOption('Beasts', 'beasts'),
    FilterOption('Blacksmith', 'blacksmith'),
    FilterOption('Comedy', 'comedy'),
    FilterOption('Comic', 'comic'),
    FilterOption('Cooking', 'cooking'),
    FilterOption('Crime', 'crime'),
    FilterOption('Crossdressing', 'crossdressing'),
    FilterOption('Dark Fantasy', 'dark-fantasy'),
    FilterOption('Demons', 'demons'),
    FilterOption('Doujinshi', 'doujinshi'),
    FilterOption('Drama', 'drama'),
    FilterOption('Ecchi', 'ecchi'),
    FilterOption('Entertainment', 'entertainment'),
    FilterOption('Fantasy', 'fantasy'),
    FilterOption('Game', 'game'),
    FilterOption('Gender Bender', 'gender-bender'),
    FilterOption('Genderswap', 'genderswap'),
    FilterOption('Genius', 'genius'),
    FilterOption('Ghosts', 'ghosts'),
    FilterOption('Gore', 'gore'),
    FilterOption('Gyaru', 'gyaru'),
    FilterOption('Harem', 'harem'),
    FilterOption('Hentai', 'hentai'),
    FilterOption('Historical', 'historical'),
    FilterOption('Horror', 'horror'),
    FilterOption('Isekai', 'isekai'),
    FilterOption('Josei', 'josei'),
    FilterOption('Knight', 'knight'),
    FilterOption('Long Strip', 'long-strip'),
    FilterOption('Magic', 'magic'),
    FilterOption('Magical Girls', 'magical-girls'),
    FilterOption('Manga', 'manga'),
    FilterOption('Mangatoon', 'mangatoon'),
    FilterOption('Manhwa', 'manhwa'),
    FilterOption('Martial Art', 'martial-art'),
    FilterOption('Martial Arts', 'martial-arts'),
    FilterOption('Mature', 'mature'),
    FilterOption('MC Rebirth', 'mc-rebirth'),
    FilterOption('Mecha', 'mecha'),
    FilterOption('Medical', 'medical'),
    FilterOption('Military', 'military'),
    FilterOption('Monster', 'monster'),
    FilterOption('Monster girls', 'monster-girls'),
    FilterOption('Monsters', 'monsters'),
    FilterOption('Murim', 'murim'),
    FilterOption('Music', 'music'),
    FilterOption('Mystery', 'mystery'),
    FilterOption('Office Workers', 'office-workers'),
    FilterOption('One Shot', 'one-shot'),
    FilterOption('Oneshot', 'oneshot'),
    FilterOption('Police', 'police'),
    FilterOption('Psychological', 'psychological'),
    FilterOption('Regression', 'regression'),
    FilterOption('Reincarnation', 'reincarnation'),
    FilterOption('Revenge', 'revenge'),
    FilterOption('Romance', 'romance'),
    FilterOption('School', 'school'),
    FilterOption('School life', 'school-life'),
    FilterOption('Sci-fi', 'sci-fi'),
    FilterOption('Seinen', 'seinen'),
    FilterOption('Sexual Violence', 'sexual-violence'),
    FilterOption('Shotacon', 'shotacon'),
    FilterOption('Shoujo', 'shoujo'),
    FilterOption('Shoujo Ai', 'shoujo-ai'),
    FilterOption('Shoujo(G)', 'shoujog'),
    FilterOption('Shounen', 'shounen'),
    FilterOption('Shounen Ai', 'shounen-ai'),
    FilterOption('Slice of Life', 'slice-of-life'),
    FilterOption('Slow Life', 'slow-life'),
    FilterOption('Smut', 'smut'),
    FilterOption('Sport', 'sport'),
    FilterOption('Sports', 'sports'),
    FilterOption('Strategy', 'strategy'),
    FilterOption('Super Power', 'super-power'),
    FilterOption('Supernatural', 'supernatural'),
    FilterOption('Survival', 'survival'),
    FilterOption('Sword Fight', 'sword-fight'),
    FilterOption('Sword Master', 'sword-master'),
    FilterOption('Swormanship', 'swormanship'),
    FilterOption('System', 'system'),
    FilterOption('Thriller', 'thriller'),
    FilterOption('Tragedy', 'tragedy'),
    FilterOption('Trauma', 'trauma'),
    FilterOption('Vampire', 'vampire'),
    FilterOption('Villainess', 'villainess'),
    FilterOption('Violence', 'violence'),
    FilterOption('Web Comic', 'web-comic'),
    FilterOption('Webtoon', 'webtoon'),
    FilterOption('Webtoons', 'webtoons'),
    FilterOption('Xianxia', 'xianxia'),
    FilterOption('Xuanhuan', 'xuanhuan'),
    FilterOption('Yuri', 'yuri'),
  ];

  Uri _mangaApiUrl(int page) =>
      Uri.parse(page > 1 ? '$apiUrl/manga/page/$page/' : '$apiUrl/manga/');

  Future<MangaPage> _list(Uri url) async {
    final res = await fetchHtml(url);
    return parseMangaList(res.document, res.url);
  }

  /// Link di API bisa berdomain api.komiku.org; seperti `setUrlWithoutDomain`
  /// di Kotlin, ambil path-nya lalu tempel ke [baseUrl].
  String? _onBaseUrl(String? url) {
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || uri.path.isEmpty) return null;
    return baseUri.replace(path: uri.path, query: uri.hasQuery ? uri.query : null).toString();
  }

  MangaPage parseMangaList(Document doc, Uri pageUrl) {
    final items = <SourceManga>[];
    for (final element in doc.querySelectorAll('div.bge')) {
      final title = clean(element.querySelector('h3')?.text);
      // Padanan `a:has(h3)`
      final link = element.querySelectorAll('a').where((a) => a.querySelector('h3') != null).firstOrNull ??
          element.querySelector('a');
      final url = _onBaseUrl(attrAbs(link, 'href', pageUrl));
      if (title.isEmpty || url == null) continue;
      final manga = SourceManga(
        url: url,
        title: title,
        thumbnailUrl: removeQuery(attrAbs(element.querySelector('img'), 'src', pageUrl)),
      );
      if (!items.contains(manga)) items.add(manga);
    }
    final hasNext = doc.querySelector('span[hx-get]') != null || items.length >= 10;
    return MangaPage(items, hasNextPage: hasNext);
  }

  // ---------------------------------------------------------------- detail

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    return parseDetails(res.document, res.url);
  }

  /// Padanan `table.inftable tr > td:contains(Label) + td`.
  String? _info(Document doc, List<String> labels) {
    final lower = labels.map((l) => l.toLowerCase()).toList();
    for (final tr in doc.querySelectorAll('table.inftable tr')) {
      final tds = tr.querySelectorAll('td');
      if (tds.length < 2) continue;
      final label = tds.first.text.toLowerCase();
      if (lower.any(label.contains)) return nonPlaceholder(tds[1].text);
    }
    return null;
  }

  SourceMangaDetails parseDetails(Document doc, Uri pageUrl) {
    final title = clean(doc.querySelector('#Judul h1, h1')?.text).isNotEmpty
        ? clean(doc.querySelector('#Judul h1, h1')!.text)
        : clean(doc.querySelector('meta[property="og:title"]')?.attributes['content']);
    if (title.isEmpty) {
      throw const SourceException(SourceErrorKind.parse, detail: 'Judul seri tidak ditemukan.');
    }

    final synopsis = nonPlaceholder(doc.querySelector('#Sinopsis > p, p.desc[itemprop=description]')?.text);
    final alt = _info(doc, ['Judul Indonesia', 'Judul Alternatif']);
    final description = [
      if (synopsis != null) synopsis,
      if (alt != null) 'Judul alternatif: $alt',
    ].join('\n\n');

    return SourceMangaDetails(
      url: pageUrl.toString(),
      title: title,
      thumbnailUrl: removeQuery(
        attrAbs(doc.querySelector('div.ims > img, img[itemprop=image]'), 'src', pageUrl),
      ),
      author: _info(doc, ['Pengarang', 'Komikus', 'Author']),
      description: description.isEmpty ? null : description,
      genres: doc
          .querySelectorAll('ul.genre li.genre a span')
          .map((e) => clean(e.text))
          .where((g) => g.isNotEmpty)
          .toList(),
      status: parseStatus(_info(doc, ['Status'])),
      chapters: parseChapters(doc, pageUrl),
    );
  }

  List<SourceChapter> parseChapters(Document doc, Uri pageUrl) {
    final chapters = <SourceChapter>[];
    // Padanan `#Daftar_Chapter tr:has(td.judulseries)`
    for (final tr in doc.querySelectorAll('#Daftar_Chapter tr')) {
      if (tr.querySelector('td.judulseries') == null) continue;
      final a = tr.querySelector('a');
      final url = attrAbs(a, 'href', pageUrl);
      if (url == null) continue;
      final name = clean(a!.text);
      chapters.add(SourceChapter(
        url: url,
        name: name.isEmpty ? 'Chapter' : name,
        number: parseChapterNumber(name),
        // "2 jam lalu" atau "dd/MM/yyyy"
        uploadedAt: parseLooseDate(tr.querySelector('td.tanggalseries')?.text),
      ));
    }
    return chapters;
  }

  // ------------------------------------------------------------- halaman

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    final pages = res.document
        .querySelectorAll('#Baca_Komik img')
        .where((img) => !(img.attributes['src'] ?? '').contains('komiku-promosi'))
        .map((img) => imgAttr(img, res.url))
        .whereType<String>()
        .toList();
    if (pages.isEmpty) {
      throw const SourceException(SourceErrorKind.parse, detail: 'Gambar bab tidak ditemukan.');
    }
    return pages;
  }
}
