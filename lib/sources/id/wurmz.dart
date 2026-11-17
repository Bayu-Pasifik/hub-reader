// Port Dart dari extension Wurmz milik keiyoushi/extensions-source
// (Apache-2.0): src/id/wurmz. Daftar dari HTML; detail, bab, dan gambar dari
// respons RSC Next.js.

import 'dart:convert';

import '../../core/i18n/strings.dart';
import '../../core/utils/json.dart';
import '../filters.dart';
import '../html_utils.dart';
import '../models.dart';
import '../next_rsc.dart';
import '../source.dart';
import '../source_exception.dart';

class WurmzSource extends HttpSource {
  WurmzSource({super.dio});

  @override
  String get id => 'id.wurmz';
  @override
  String get name => 'Wurmz';
  @override
  String get lang => 'id';
  @override
  String get defaultBaseUrl => 'https://wurmz.net';
  @override
  ContentWarning get contentWarning => ContentWarning.mixed;

  static const _rsc = {'Rsc': '1'};

  Future<MangaPage> _list(Map<String, String> query) async {
    final res = await fetchHtml(baseUri.replace(path: '/semua-komik', queryParameters: query));
    final items = <SourceManga>[];
    for (final card in res.document.querySelectorAll('article.comic-card')) {
      final link = card.querySelector('a[href*="/detail/"]');
      final href = attrAbs(link, 'href', res.url);
      if (href == null) continue;
      final h2 = clean(card.querySelector('h2')?.text);
      final title = h2.isNotEmpty ? h2 : clean(link!.attributes['aria-label']);
      if (title.isEmpty) continue;
      items.add(SourceManga(url: href, title: title, thumbnailUrl: attrAbs(card.querySelector('img'), 'src', res.url)));
    }
    final next = res.document.querySelectorAll('a').any((a) => a.text.contains('Berikutnya'));
    return MangaPage(items, hasNextPage: next);
  }

  @override
  Future<MangaPage> popular(int page) => _list({'sort': 'popular_all', 'page': '$page'});

  @override
  Future<MangaPage> latest(int page) => _list({'sort': 'update', 'page': '$page'});

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) =>
      _list({if (query.trim().isNotEmpty) 'q': query.trim(), if (page > 1) 'page': '$page'});

  static final _statusBadge = RegExp(r'"className":"status-badge","children":"([^"]+)"');
  static final _updated = RegExp(r'"Diperbarui\s*",\s*"([^"]+)"');

  JsonMap? _series(String body) {
    final direct = findRscObject(body, (o) => o['@type'] == 'ComicSeries');
    if (direct != null) return direct;
    final wrapper = findRscObject(body, (o) {
      final html = asMap(o['dangerouslySetInnerHTML'])['__html'];
      return html is String && html.contains('ComicSeries');
    });
    if (wrapper != null) {
      try {
        return asMap(jsonDecode(asString(asMap(wrapper['dangerouslySetInnerHTML'])['__html'])!));
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final text = await fetchText(Uri.parse(mangaUrl).replace(queryParameters: {'_rsc': ''}), headers: _rsc);
    final series = _series(text);
    if (series == null) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Gagal memproses detail komik.'));
    }
    final chapterObj = findRscObject(text, (o) => o['chapters'] is List);
    final path = Uri.parse(mangaUrl).path;
    final slug = asString(chapterObj?['sourceSlug']) ?? path.replaceFirst('/detail/', '').split('/chapter').first;
    final updated = parseLooseDate(_updated.firstMatch(text)?.group(1));
    final chapters = <SourceChapter>[];
    var first = true;
    for (final c in asList(chapterObj?['chapters'])) {
      final ch = asMap(c);
      final label = asString(ch['chapter_label']);
      if (label == null) continue;
      chapters.add(SourceChapter(
        url: '$baseUrl/detail/$slug/chapter/$label',
        name: 'Chapter $label',
        number: asDouble(ch['chapter_sort']),
        uploadedAt: first ? updated : null,
      ));
      first = false;
    }
    final alt = asString(series['alternateName'])?.trim();
    final desc = asString(series['description'])?.trim();
    return SourceMangaDetails(
      url: mangaUrl,
      title: clean(asString(series['name'])),
      thumbnailUrl: asString(series['image']),
      author: asString(asMap(series['author'])['name']),
      description: [
        if (desc != null && desc.isNotEmpty) desc,
        if (alt != null && alt.isNotEmpty) trp('Judul alternatif:\n- {alt}', {'alt': alt}),
      ].join('\n\n'),
      genres: asStringList(series['genre']),
      status: switch (_statusBadge.firstMatch(text)?.group(1)?.toLowerCase()) {
        'ongoing' || 'hiatus' => SourceMangaStatus.ongoing,
        'tamat' || 'completed' => SourceMangaStatus.completed,
        _ => SourceMangaStatus.unknown,
      },
      chapters: chapters,
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final text = await fetchText(Uri.parse(chapter.url).replace(queryParameters: {'_rsc': ''}), headers: _rsc);
    final obj = findRscObject(text, (o) => o['images'] is List);
    final images = asStringList(obj?['images']);
    if (images.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    }
    return images;
  }
}
