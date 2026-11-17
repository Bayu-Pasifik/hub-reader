// Port Dart dari extension Ikiru milik keiyoushi/extensions-source
// (Apache-2.0): src/id/ikiru. API publik `/api/public/...`; gambar dari HTML bab.

import 'package:html/parser.dart' show parseFragment;

import '../../core/i18n/strings.dart';
import '../../core/utils/json.dart';
import '../filters.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class IkiruSource extends HttpSource {
  IkiruSource({super.dio});

  @override
  String get id => 'id.ikiru';
  @override
  String get name => 'Ikiru';
  @override
  String get lang => 'id';
  @override
  String get defaultBaseUrl => 'https://11.ikiru.wtf';
  @override
  ContentWarning get contentWarning => ContentWarning.safe;

  /// Respons selalu HTTP 200 dengan amplop `success`.
  Future<JsonMap> _data(Uri url) async {
    final json = asMap(await fetchJson(url));
    final data = json['data'];
    if (json['success'] != true || data == null) {
      throw SourceException(
        SourceErrorKind.parse,
        detail: asString(json['message']) ?? tr('Permintaan gagal.'),
      );
    }
    return asMap(data);
  }

  SourceManga _manga(JsonMap m) => SourceManga(
        url: '$baseUrl/manga/${Uri.encodeComponent(asString(m['slug']) ?? '')}',
        title: clean(asString(m['title'])),
        thumbnailUrl: asString(m['featuredImage']),
      );

  Future<MangaPage> _search(int page, {required String sortBy, String? query}) async {
    final data = await _data(baseUri.replace(path: '/api/public/library/search', queryParameters: {
      if (query != null && query.isNotEmpty) 'query': query else ...{'sortBy': sortBy, 'sort': 'desc'},
      'page': '$page',
    }));
    final items = [for (final m in asList(data['mangas'])) _manga(asMap(m))];
    final total = asInt(data['total']) ?? 0;
    return MangaPage(items, hasNextPage: items.isNotEmpty && page * items.length < total);
  }

  @override
  Future<MangaPage> popular(int page) => _search(page, sortBy: 'popular');

  @override
  Future<MangaPage> latest(int page) => _search(page, sortBy: 'updated');

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) =>
      _search(page, sortBy: 'popular', query: query.trim());

  static String _fmt(double n) => n == n.roundToDouble() ? '${n.toInt()}' : '$n';

  static final _chapterTitle = RegExp(r'(Chapter\s*[\d.]+(?:\s*[:\-].*)?)', caseSensitive: false);

  static String? _plain(String? html) {
    if (html == null) return null;
    final frag = parseFragment(html);
    final paras = frag.querySelectorAll('p').map((p) => p.text.trim()).where((t) => t.isNotEmpty).toList();
    final text = paras.isNotEmpty ? paras.join('\n\n') : frag.text?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static List<String> _names(Object? list) => [
        for (final e in asList(list))
          if (asString(asMap(e)['name']) case final n?) n,
      ];

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final slug = Uri.decodeComponent(Uri.parse(mangaUrl).pathSegments.where((s) => s.isNotEmpty).last);
    final m = await _data(baseUri.replace(pathSegments: ['api', 'public', 'manga', slug]));
    final title = clean(asString(m['title']));
    final meta = asMap(m['metadata']);
    final alts = {
      for (final a in asStringList(meta['alternateTitles']))
        if (a.trim().isNotEmpty && a.trim().toLowerCase() != title.toLowerCase()) a.trim(),
    };
    final desc = _plain(asString(m['description']));
    final chapters = <SourceChapter>[];
    for (final c in asList(asMap(m['chapters'])['chapters'])) {
      final ch = asMap(c);
      final n = asDouble(ch['number']);
      if (n == null) continue;
      final raw = asString(ch['title']) ?? '';
      final match = _chapterTitle.allMatches(raw).lastOrNull;
      final name = match != null ? match[0]! : 'Chapter ${_fmt(n)}';
      chapters.add(SourceChapter(
        url: '$baseUrl/manga/${Uri.encodeComponent(slug)}/chapter-${_fmt(n)}',
        name: name,
        number: n,
        uploadedAt: DateTime.tryParse(asString(ch['createdAt']) ?? '')?.toLocal(),
      ));
    }
    return SourceMangaDetails(
      url: mangaUrl,
      title: title,
      thumbnailUrl: asString(m['featuredImage']),
      author: _names(meta['author']).join(', '),
      artist: _names(meta['artist']).join(', '),
      description: [
        if (desc != null) desc,
        if (alts.isNotEmpty) trp('Judul alternatif:\n{names}', {'names': alts.map((a) => '- $a').join('\n')}),
      ].join('\n\n'),
      genres: _names(meta['genre']),
      status: switch (asString(m['status'])?.toUpperCase()) {
        'ONGOING' => SourceMangaStatus.ongoing,
        'COMPLETED' => SourceMangaStatus.completed,
        'HIATUS' => SourceMangaStatus.hiatus,
        _ => SourceMangaStatus.unknown,
      },
      chapters: chapters,
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    final pages = [
      for (final img in res.document.querySelectorAll("img[src*='cdn.ikiru.id']"))
        if (img.attributes['src'] case final u? when u.isNotEmpty) u,
    ];
    if (pages.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    }
    return pages;
  }
}
