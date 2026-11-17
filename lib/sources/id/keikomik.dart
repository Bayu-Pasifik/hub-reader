// Port Dart dari extension Keikomik milik keiyoushi/extensions-source
// (Apache-2.0): src/id/keikomik. Next.js: daftar dari /api/list, detail dan
// gambar dari JSON `__NEXT_DATA__`.

import '../../core/i18n/strings.dart';
import '../../core/utils/json.dart';
import '../filters.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';
import '../templates/mangak.dart' show MangaKSource;

class KeikomikSource extends HttpSource {
  KeikomikSource({super.dio});

  @override
  String get id => 'id.keikomik';
  @override
  String get name => 'Keikomik';
  @override
  String get lang => 'id';
  @override
  String get defaultBaseUrl => 'https://keikomik.net';
  @override
  ContentWarning get contentWarning => ContentWarning.mixed;

  SourceManga _manga(JsonMap m) => SourceManga(
        url: '$baseUrl/komik/${m['slug']}',
        title: clean(asString(m['name'])),
        thumbnailUrl: asString(m['image']),
      );

  Future<MangaPage> _list(int page, String sort) async {
    final json = asMap(await fetchJson(Uri.parse('$baseUrl/api/list').replace(queryParameters: {
      'page': '$page',
      'limit': '18',
      'sort': sort,
      'direction': 'desc',
    })));
    return MangaPage(
      [for (final m in asList(json['data'])) _manga(asMap(m))],
      hasNextPage: json['hasNextPage'] == true,
    );
  }

  @override
  Future<MangaPage> popular(int page) => _list(page, 'views');

  @override
  Future<MangaPage> latest(int page) => _list(page, 'UpdateAt');

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    final q = query.trim();
    if (q.isEmpty) return popular(page);
    // Pencarian situs tanpa halaman.
    if (page > 1) return const MangaPage([], hasNextPage: false);
    final list = asList(await fetchJson(Uri.parse('$baseUrl/api/search').replace(queryParameters: {'q': q})));
    return MangaPage([for (final m in list) _manga(asMap(m))], hasNextPage: false);
  }

  static String _num(Object? v) {
    final d = asDouble(v) ?? 0;
    return d == d.roundToDouble() ? '${d.toInt()}' : '$d';
  }

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    final props = MangaKSource.pageProps(res.body);
    final item = asMap(props['item']);
    final slug = asString(item['slug']);
    if (slug == null) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Judul seri tidak ditemukan.'));
    }
    final alts = (asString(item['name2']) ?? '').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
    final desc = asString(item['description'])?.trim();
    final chapters = <SourceChapter>[
      for (final c in asList(props['komikList']))
        SourceChapter(
          url: '$baseUrl/chapter/$slug-chapter-${_num(asMap(c)['id'])}',
          name: 'Chapter ${_num(asMap(c)['id'])}',
          number: asDouble(asMap(c)['id']),
          uploadedAt: asInt(asMap(c)['CreateAt']) == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(asInt(asMap(c)['CreateAt'])!),
        ),
    ];
    return SourceMangaDetails(
      url: mangaUrl,
      title: clean(asString(item['name'])),
      thumbnailUrl: asString(item['image']),
      author: nonPlaceholder(asString(item['author'])),
      description: [
        if (desc != null && desc.isNotEmpty) desc,
        if (alts.isNotEmpty) trp('Judul alternatif:\n{names}', {'names': alts.map((a) => '- $a').join('\n')}),
      ].join('\n\n'),
      genres: {
        for (final k in ['genre', 'themes', 'demographic']) ...asStringList(item[k]),
      }.toList(),
      status: switch (asString(item['status'])?.toLowerCase()) {
        'ongoing' => SourceMangaStatus.ongoing,
        'completed' => SourceMangaStatus.completed,
        'hiatus' => SourceMangaStatus.hiatus,
        _ => SourceMangaStatus.unknown,
      },
      chapters: chapters,
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    final props = MangaKSource.pageProps(res.body);
    final images = asStringList(asMap(props['subItem'])['img']).where((u) => u.isNotEmpty).toList();
    if (images.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    }
    return images;
  }
}
