// Port Dart dari template MangaBox milik keiyoushi/extensions-source
// (Apache-2.0): lib-multisrc/mangabox (Mangabat, Mangakakalot, Manganelo).
//
// Daftar dan detail dari HTML, daftar bab dari `/api/manga/<slug>/chapters`,
// gambar dari `chapterImages` + `cdns` di skrip halaman bab. Fitur Kotlin yang
// tidak dibawa: penggabung gambar terpotong (butuh decode bitmap) dan
// pergantian CDN otomatis saat gambar gagal.

import 'package:html/dom.dart';

import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';
import '../../core/i18n/strings.dart';

class MangaBoxSource extends HttpSource {
  MangaBoxSource({
    required this.id,
    required this.name,
    required String baseUrl,
    required this.lang,
    this.contentWarning = ContentWarning.safe,
    this.titleSlugForIdSlugs = false,
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

  /// Mangakakalot: slug berbentuk id (`ab123`) diganti slug dari judul.
  final bool titleSlugForIdSlugs;

  static final _idSlug = RegExp(r'^[a-z]{2}\d+$');

  static String titleToSlug(String title) => title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
      .trim()
      .replaceAll(RegExp(r'[\s-]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  String slugOf(String url, [String title = '']) {
    final segments = Uri.parse(url).pathSegments.where((s) => s.isNotEmpty).toList();
    final slug = segments.isEmpty ? '' : segments.last;
    if (titleSlugForIdSlugs && _idSlug.hasMatch(slug) && title.isNotEmpty) return titleToSlug(title);
    return slug;
  }

  String mangaUrlFor(String slug) => '$baseUrl/manga/$slug';

  // =========================== Daftar ===========================

  @override
  Future<MangaPage> popular(int page) => _fetchList(Uri.parse('$baseUrl/manga-list/hot-manga?page=$page'));

  @override
  Future<MangaPage> latest(int page) => _fetchList(Uri.parse('$baseUrl/manga-list/latest-manga?page=$page'));

  static const _filterIds = {
    ('newest', 'all'): '1',
    ('newest', 'completed'): '2',
    ('newest', 'ongoing'): '3',
    ('latest', 'all'): '4',
    ('latest', 'completed'): '5',
    ('latest', 'ongoing'): '6',
    ('topview', 'all'): '7',
    ('topview', 'completed'): '8',
    ('topview', 'ongoing'): '9',
  };

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) {
    final text = query.trim();
    if (text.isNotEmpty) {
      return _fetchList(Uri.parse('$baseUrl/search/story/${normalizeSearchQuery(text)}?page=$page'));
    }
    final sort = filters.single('sort');
    final status = filters.single('status');
    final genre = filters.single('genre');
    final id = sort != null && status != null ? _filterIds[(sort, status)] : null;
    return _fetchList(Uri.parse('$baseUrl/genre${genre == null ? '' : '/$genre'}')
        .replace(queryParameters: {if (id != null) 'filter': id, 'page': '$page'}));
  }

  Future<MangaPage> _fetchList(Uri url) async {
    final res = await fetchHtml(url);
    return parseList(res.document, res.url);
  }

  MangaPage parseList(Document doc, Uri base) {
    final items = <SourceManga>[];
    for (final el in doc.querySelectorAll(
        'div.truyen-list > div.list-truyen-item-wrap, div.comic-list > .list-comic-item-wrap, '
        '.panel_story_list .story_item')) {
      final link = el.querySelector('h3 a');
      final href = absUrl(base, link?.attributes['href']);
      final title = clean(link?.text);
      if (href == null || title.isEmpty) continue;
      items.add(SourceManga(
        url: mangaUrlFor(slugOf(href, title)),
        title: title,
        thumbnailUrl: attrAbs(el.querySelector('img'), 'src', base),
      ));
    }
    final hasNext = doc.querySelector('div.group_page, div.group-page') != null &&
        _hasNextLink(doc.querySelectorAll('div.group_page a, div.group-page a'));
    return MangaPage(items, hasNextPage: hasNext || _hasSearchNext(doc));
  }

  /// "div.group-page a:not([href]) + a:not(:contains(Last))": tautan sesudah halaman aktif.
  bool _hasNextLink(List<Element> links) {
    for (var i = 0; i < links.length - 1; i++) {
      if (!links[i].attributes.containsKey('href') && !clean(links[i + 1].text).contains('Last')) return true;
    }
    return false;
  }

  /// "a.page_select + a:not(.page_last)" (halaman cari).
  bool _hasSearchNext(Document doc) {
    for (final cls in const ['page_select', 'page-select']) {
      for (final cur in doc.querySelectorAll('a.$cls')) {
        final next = cur.nextElementSibling;
        if (next != null && next.localName == 'a' && !next.classes.contains('page_last') && !next.classes.contains('page-last')) {
          return true;
        }
      }
    }
    return false;
  }

  /// Padanan fungsi `change_alias` di situs Mangakakalot.
  static String normalizeSearchQuery(String query) {
    var s = query.toLowerCase();
    s = s.replaceAll(RegExp('[àáạảãâầấậẩẫăằắặẳẵ]'), 'a');
    s = s.replaceAll(RegExp('[èéẹẻẽêềếệểễ]'), 'e');
    s = s.replaceAll(RegExp('[ìíịỉĩ]'), 'i');
    s = s.replaceAll(RegExp('[òóọỏõôồốộổỗơờớợởỡ]'), 'o');
    s = s.replaceAll(RegExp('[ùúụủũưừứựửữ]'), 'u');
    s = s.replaceAll(RegExp('[ỳýỵỷỹ]'), 'y');
    s = s.replaceAll('đ', 'd');
    s = s.replaceAll(RegExp(r'''[!@%^*()+=<>?/,.:;' "&#\[\]~$_-]'''), '_');
    s = s.replaceAll(RegExp('_+'), '_');
    return s.replaceAll(RegExp(r'^_+|_+$'), '');
  }

  // =========================== Filter ===========================

  @override
  Future<List<FilterDef>> filters() async => [
        const SelectFilterDef('sort', 'Order by', [
          FilterOption('Latest', 'latest'),
          FilterOption('Newest', 'newest'),
          FilterOption('Top read', 'topview'),
        ]),
        const SelectFilterDef('status', 'Status', [
          FilterOption('ALL', 'all'),
          FilterOption('Completed', 'completed'),
          FilterOption('Ongoing', 'ongoing'),
        ]),
        SelectFilterDef('genre', 'Category', [
          const FilterOption('ALL', ''),
          for (final (slug, label) in _genres) FilterOption(label, slug),
        ]),
      ];

  // =========================== Detail ===========================

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    final slug = slugOf(res.url.toString());
    final chapters = await _chapters(slug, mangaUrl);
    return parseDetails(res.document, res.url, slug, chapters);
  }

  Future<List<SourceChapter>> _chapters(String slug, String mangaUrl) async {
    final Object? json;
    try {
      json = await fetchJson(Uri.parse('$baseUrl/api/manga/$slug/chapters?limit=-1'),
          headers: {'X-Requested-With': 'XMLHttpRequest', 'Referer': mangaUrl});
    } on SourceException {
      return const [];
    }
    final root = asMap(json);
    if (root['success'] != true) return const [];
    return parseApiChapters(asMap(asMap(root['data']))['chapters'], slug);
  }

  List<SourceChapter> parseApiChapters(Object? raw, String slug) {
    final out = <SourceChapter>[];
    for (final c in asList(raw)) {
      final m = asMap(c);
      final chapterSlug = asString(m['chapter_slug']);
      if (chapterSlug == null) continue;
      final name = asString(m['chapter_name']) ?? 'Chapter';
      out.add(SourceChapter(
        url: '$baseUrl/manga/$slug/$chapterSlug',
        name: name,
        number: asDouble(m['chapter_num']) ?? parseChapterNumber(name),
        uploadedAt: DateTime.tryParse(asString(m['updated_at']) ?? '')?.toLocal(),
        scanlator: baseUrl.replaceFirst('https://', ''),
      ));
    }
    return out;
  }

  SourceMangaDetails parseDetails(Document doc, Uri base, String slug, List<SourceChapter> chapters) {
    final info = doc.querySelector('div.manga-info-top, div.panel-story-info');
    if (info == null && clean(doc.body?.text).startsWith('REDIRECT :')) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Alamat sumber sudah berubah.'));
    }
    final title = clean(info?.querySelector('h1, h2')?.text);
    if (title.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Judul seri tidak ditemukan.'));

    List<Element> lis(String word) => [
          for (final li in info!.querySelectorAll('li'))
            if (li.text.toLowerCase().contains(word)) li,
        ];
    Element? cell(String word) {
      for (final td in info!.querySelectorAll('td')) {
        if (ownText(td).toLowerCase().contains(word)) return td.nextElementSibling;
      }
      return null;
    }

    final authors = [
      for (final li in lis('author')) ...li.querySelectorAll('a').map((a) => clean(a.text)),
      ...?cell('author')?.querySelectorAll('a').map((a) => clean(a.text)),
    ].where((a) => a.isNotEmpty).toList();
    final statusText = [
      ...lis('status').map((li) => li.text),
      if (cell('status') != null) cell('status')!.text,
    ].join(' ');
    final kakalotGenres = lis('genres').firstOrNull?.querySelectorAll('a').map((a) => clean(a.text)).toList() ?? const [];
    final neloGenres = cell('genres')?.querySelectorAll('a').map((a) => clean(a.text)).toList() ?? const [];
    final genres = (kakalotGenres.isNotEmpty ? kakalotGenres : neloGenres).where((g) => g.isNotEmpty).toList();

    var description = ownText(doc.querySelector('div#noidungm, div#panel-story-info-description, div#contentBox') ?? Element.tag('div'))
        .replaceAll(RegExp('^${RegExp.escape(title)} summary:\\s'), '')
        .trim();
    final alt = clean(ownText(doc.querySelector('.story-alternative, tr .info-alternative h2, .info-alternative h2') ?? Element.tag('div')));
    if (alt.isNotEmpty) description = description.isEmpty ? 'Alternative Name: $alt' : '$description\n\nAlternative Name: $alt';

    return SourceMangaDetails(
      url: mangaUrlFor(slug),
      title: title,
      thumbnailUrl: attrAbs(doc.querySelector('div.manga-info-pic img, span.info-image img'), 'src', base),
      author: authors.isEmpty ? null : authors.join(', '),
      description: description.isEmpty ? null : description,
      genres: genres,
      status: statusText.contains('Ongoing')
          ? SourceMangaStatus.ongoing
          : statusText.contains('Completed')
              ? SourceMangaStatus.completed
              : SourceMangaStatus.unknown,
      chapters: chapters,
    );
  }

  // =========================== Halaman ===========================

  static final _cdns = RegExp(r'cdns\s*=\s*\[([^\]]+)\]');
  static final _backup = RegExp(r'backupImage\s*=\s*\[([^\]]+)\]');
  static final _images = RegExp(r'chapterImages\s*=\s*\[([^\]]+)\]');

  static List<String> _array(String script, RegExp re) {
    final match = re.firstMatch(script);
    if (match == null) return const [];
    return match
        .group(1)!
        .split(',')
        .map((s) {
          var t = s.trim();
          if (t.length >= 2 && t.startsWith('"') && t.endsWith('"')) t = t.substring(1, t.length - 1);
          t = t.replaceAll(r'\/', '/');
          return t.endsWith('/') ? t.substring(0, t.length - 1) : t;
        })
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    return parsePages(res.document, res.url);
  }

  List<String> parsePages(Document doc, Uri base) {
    final script = doc.querySelectorAll('script').map((s) => s.text).where((t) => t.contains('cdns =')).join('\n');
    final cdns = [..._array(script, _cdns), ..._array(script, _backup)];
    final images = _array(script, _images);
    if (images.isNotEmpty && cdns.isNotEmpty) {
      final cdn = Uri.parse(cdns.first);
      return [
        for (final path in images) cdn.replace(path: '/$path'.replaceAll('//', '/')).toString(),
      ];
    }
    return [
      for (final img in doc.querySelectorAll('div.container-chapter-reader > img'))
        if (attrAbs(img, 'src', base) case final url?) url,
    ];
  }

  static const _genres = <(String, String)>[
    ('4-koma', '4-Koma'),
    ('action', 'Action'),
    ('adaptation', 'Adaptation'),
    ('adult', 'Adult'),
    ('adventure', 'Adventure'),
    ('age-gap', 'Age gap'),
    ('ai-art', 'Ai art'),
    ('aliens', 'Aliens'),
    ('animals', 'Animals'),
    ('anthology', 'Anthology'),
    ('artbook', 'Artbook'),
    ('avant-garde', 'Avant garde'),
    ('award-winning', 'Award winning'),
    ('beasts', 'Beasts'),
    ('boys-love', 'Boys love'),
    ('blackmail', 'Blackmail'),
    ('bloody', 'Bloody'),
    ('bodyswap', 'Bodyswap'),
    ('brocon-siscon', 'Brocon/Siscon'),
    ('cars', 'Cars'),
    ('cartoon', 'Cartoon'),
    ('cheating-infidelity', 'Cheating infidelity'),
    ('childhood-friends', 'Childhood friends'),
    ('college-life', 'College life'),
    ('comedy', 'Comedy'),
    ('comic', 'Comic'),
    ('contest-winning', 'Contest winning'),
    ('cooking', 'Cooking'),
    ('creators', 'Creators'),
    ('crime', 'Crime'),
    ('crossdressing', 'Crossdressing'),
    ('cultivation', 'Cultivation'),
    ('death-game', 'Death game'),
    ('degeneratemc', 'Degeneratemc'),
    ('delinquents', 'Delinquents'),
    ('dementia', 'Dementia'),
    ('demons', 'Demons'),
    ('doujinshi', 'Doujinshi'),
    ('drama', 'Drama'),
    ('ecchi', 'Ecchi'),
    ('employee', 'Employee'),
    ('erotica', 'Erotica'),
    ('fan-colored', 'Fan colored'),
    ('fantasy', 'Fantasy'),
    ('female-protagonists', 'Female protagonists'),
    ('fetish', 'Fetish'),
    ('full-color', 'Full color'),
    ('game', 'Game'),
    ('gender-bender', 'Gender bender'),
    ('genderswap', 'Genderswap'),
    ('ghosts', 'Ghosts'),
    ('girls-love', 'Girls love'),
    ('gore', 'Gore'),
    ('gourmet', 'Gourmet'),
    ('graphic-novel', 'Graphic novel'),
    ('gyaru', 'Gyaru'),
    ('harem', 'Harem'),
    ('heartwarming', 'Heartwarming'),
    ('hentai', 'Hentai'),
    ('historical', 'Historical'),
    ('horror', 'Horror'),
    ('imageset', 'Imageset'),
    ('incest', 'Incest'),
    ('informative', 'Informative'),
    ('isekai', 'Isekai'),
    ('iyashikei', 'Iyashikei'),
    ('josei', 'Josei'),
    ('kids', 'Kids'),
    ('korean', 'Korean'),
    ('liexing', 'Liexing'),
    ('loli', 'Loli'),
    ('long-strip', 'Long strip'),
    ('mafia', 'Mafia'),
    ('magic', 'Magic'),
    ('magical-girls', 'Magical girls'),
    ('mahou-shoujo', 'Mahou shoujo'),
    ('male-protagonists', 'Male protagonists'),
    ('manga', 'Manga'),
    ('mangatoon', 'Mangatoon'),
    ('manhua', 'Manhua'),
    ('manhwa', 'Manhwa'),
    ('martial-arts', 'Martial arts'),
    ('master-servant', 'Master servant'),
    ('mature', 'Mature'),
    ('mecha', 'Mecha'),
    ('medical', 'Medical'),
    ('military', 'Military'),
    ('monsters', 'Monsters'),
    ('monster-girls', 'Monster girls'),
    ('murim', 'Murim'),
    ('music', 'Music'),
    ('mystery', 'Mystery'),
    ('netorare', 'Netorare'),
    ('netori', 'Netori'),
    ('ninja', 'Ninja'),
    ('non-human', 'Non human'),
    ('office', 'Office'),
    ('office-workers', 'Office workers'),
    ('official-colored', 'Official colored'),
    ('old-people', 'Old people'),
    ('omegaverse', 'Omegaverse'),
    ('one-shot', 'One shot'),
    ('others', 'Others'),
    ('overpowered', 'Overpowered'),
    ('parody', 'Parody'),
    ('philosophical', 'Philosophical'),
    ('ping-ping-jun', 'Ping ping jun'),
    ('police', 'Police'),
    ('pornographic', 'Pornographic'),
    ('post-apocalyptic', 'Post apocalyptic'),
    ('psychological', 'Psychological'),
    ('reincarnation', 'Reincarnation'),
    ('revenge', 'Revenge'),
    ('reverse', 'Reverse'),
    ('reverse-harem', 'Reverse harem'),
    ('romance', 'Romance'),
    ('royal-family', 'Royal family'),
    ('royalty', 'Royalty'),
    ('samurai', 'Samurai'),
    ('school', 'School'),
    ('school-life', 'School life'),
    ('sci-fi', 'Sci fi'),
    ('science-fiction', 'Science fiction'),
    ('seinen', 'Seinen'),
    ('self-published', 'Self published'),
    ('sexual-violence', 'Sexual violence'),
    ('shota', 'Shota'),
    ('shoujo', 'Shoujo'),
    ('shoujo-ai', 'Shoujo ai'),
    ('shounen', 'Shounen'),
    ('shounen-ai', 'Shounen ai'),
    ('showbiz', 'Showbiz'),
    ('slice-of-life', 'Slice of life'),
    ('smut', 'Smut'),
    ('sm-bdsm', 'Sm bdsm'),
    ('soft-yaoi', 'Soft yaoi'),
    ('space', 'Space'),
    ('sports', 'Sports'),
    ('spy', 'Spy'),
    ('step-family', 'Step family'),
    ('super-power', 'Super power'),
    ('superhero', 'Superhero'),
    ('supernatural', 'Supernatural'),
    ('survival', 'Survival'),
    ('suspense', 'Suspense'),
    ('system', 'System'),
    ('teacher-student', 'Teacher student'),
    ('thriller', 'Thriller'),
    ('time-travel', 'Time travel'),
    ('traditional-games', 'Traditional games'),
    ('tragedy', 'Tragedy'),
    ('vampires', 'Vampires'),
    ('video-games', 'Video games'),
    ('villainess', 'Villainess'),
    ('violence', 'Violence'),
    ('virtual-reality', 'Virtual reality'),
    ('web-comic', 'Web comic'),
    ('webtoons', 'Webtoons'),
    ('western', 'Western'),
    ('wuxia', 'Wuxia'),
    ('xianxia', 'Xianxia'),
    ('yaoi', 'Yaoi'),
    ('yuri', 'Yuri'),
    ('zombies', 'Zombies'),
  ];
}
