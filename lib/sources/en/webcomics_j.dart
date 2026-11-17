// Situs katalog (bagian J), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0): stonescape, otranslations,
// ninkocomics.

import 'dart:convert';

import 'package:html/dom.dart';

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import 'fn_source.dart';

// ---------------------------------------------------------------- StoneScape

MangaPage _stonePage(Object? json, String base) {
  final m = json as Map;
  final items = [
    for (final s in (m['data'] as List).cast<Map>())
      SourceManga(
        url: '/series/${s['slug']}',
        title: '${s['title']}',
        thumbnailUrl: s['coverUrl'] == null ? null : '$base${s['coverUrl']}',
      ),
  ];
  final p = m['pagination'] as Map?;
  final cur = (p?['page'] as num?)?.toInt() ?? 1;
  final total = (p?['totalPages'] as num?)?.toInt() ?? 1;
  return MangaPage(items, hasNextPage: cur < total);
}

String _stoneNum(String raw) {
  final f = double.tryParse(raw);
  if (f == null) return raw;
  return f == f.truncateToDouble() ? f.toInt().toString() : f.toString();
}

// ------------------------------------------------------------- O Translations

class _OtlEntry {
  _OtlEntry(this.m);
  final Map m;
  String get title => '${m['title']}';
  String get slug => '${m['slug']}';

  static final _sep = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
  static List<String> words(String s) => s.toLowerCase().split(_sep).where((e) => e.isNotEmpty).toList();

  List<String> _list(String k) => [for (final e in (m[k] as List? ?? const [])) '$e'.toLowerCase()];

  int score(String word) {
    final t = title.toLowerCase();
    if (t == word) return 100;
    if (t.startsWith(word)) return 60;
    if (words(t).contains(word)) return 50;
    if (t.contains(word)) return 30;
    if ('${m['subtitle'] ?? ''}'.toLowerCase().contains(word)) return 20;
    if ([..._list('authors'), ..._list('artists')].any((e) => e.contains(word))) return 15;
    if ([..._list('genres'), ..._list('tags'), ..._list('origin')].any((e) => e.contains(word))) return 10;
    return 0;
  }

  SourceManga toManga(String base) => SourceManga(
        url: slug,
        title: title,
        thumbnailUrl: m['cover'] == null ? null : Uri.parse(base).resolve('${m['cover']}').toString(),
      );
}

Future<List<_OtlEntry>> _otlCatalogue(HttpSource s) async {
  final l = await s.fetchJson(Uri.parse('${s.baseUrl}/search-index.json')) as List;
  return [for (final e in l) _OtlEntry(e as Map)];
}

MangaPage _otlRank(HttpSource s, List<_OtlEntry> all, List<String> order) {
  int rank(_OtlEntry e) {
    final i = order.indexOf(e.slug);
    return i >= 0 ? i : order.length;
  }

  final sorted = [...all]..sort((a, b) => rank(a).compareTo(rank(b)));
  return MangaPage([for (final e in sorted) e.toManga(s.baseUrl)], hasNextPage: false);
}

// Props pulau Astro: tiap nilai berupa [tipe, nilai]; [0] = undefined.
Object? _unwrapAstro(Object? v) {
  if (v is List) {
    if (v.length == 1 && v[0] is int) return null;
    if (v.length == 2 && v[0] is int) return _unwrapAstro(v[1]);
    return [for (final e in v) _unwrapAstro(e)];
  }
  if (v is Map) return {for (final e in v.entries) e.key: _unwrapAstro(e.value)};
  return v;
}

String? _text(Element? e) {
  final t = clean(e?.text);
  return t.isEmpty ? null : t;
}

// -------------------------------------------------------------- Ninko Comics

List<SourceManga> _ninkoComics(Document doc, Uri base) => [
      for (final a in doc.querySelectorAll('a.rk-poster[href^="/comic/"]'))
        SourceManga(
          url: Uri.parse(a.attributes['href']!).path,
          title: clean(a.querySelector('span.line-clamp-2')?.text),
          thumbnailUrl: attrAbs(a.querySelector('img'), 'src', base),
        ),
    ];

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

DateTime? _ninkoDate(String? raw) {
  final m = RegExp(r'([A-Za-z]{3})[a-z]*\.? (\d{1,2}), (\d{4})').firstMatch(raw ?? '');
  if (m == null) return null;
  final mo = _months[m[1]!.toLowerCase()];
  return mo == null ? null : DateTime(int.parse(m[3]!), mo, int.parse(m[2]!));
}

Future<MangaPage> _ninkoList(HttpSource s, String sort) async {
  final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/comics/').replace(queryParameters: {'sort': sort}));
  return MangaPage(_ninkoComics(res.document, s.baseUri), hasNextPage: false);
}

List<MangaSource> webcomicsJ() => [
      // StoneScape
      FnSource(
        id: 'en.stonescape',
        name: 'StoneScape',
        baseUrl: 'https://stonescape.xyz',
        popularFn: (s, page) async => _stonePage(
          await s.fetchJson(Uri.parse('${s.baseUrl}/api/series/popular?page=$page&period=week&contentType=manhwa&limit=24')),
          s.baseUrl,
        ),
        latestFn: (s, page) async => _stonePage(
          await s.fetchJson(Uri.parse('${s.baseUrl}/api/series?page=$page&limit=24&contentType=manhwa')),
          s.baseUrl,
        ),
        searchFn: (s, page, q) async => _stonePage(
          await s.fetchJson(Uri.parse('${s.baseUrl}/api/series').replace(queryParameters: {
            'page': '$page',
            'limit': '24',
            'contentType': 'manhwa',
            'search': q,
          })),
          s.baseUrl,
        ),
        detailsFn: (s, url) async {
          final slug = url.split('/').last;
          final d = await s.fetchJson(Uri.parse('${s.baseUrl}/api/series/by-slug/$slug')) as Map;
          final cl = await s.fetchJson(Uri.parse('${s.baseUrl}/api/series/by-slug/$slug/chapters')) as Map;
          final status = '${d['publicationStatus']}'.toLowerCase();
          return SourceMangaDetails(
            url: url,
            title: '${d['title']}',
            thumbnailUrl: d['coverUrl'] == null ? null : '${s.baseUrl}${d['coverUrl']}',
            description: d['description'] as String?,
            author: d['author'] as String?,
            artist: d['artist'] as String?,
            genres: [for (final g in (d['genres'] as List? ?? const [])) '$g'],
            status: parseStatus(status == 'cancelled' ? 'dropped' : status),
            chapters: [
              for (final c in (cl['chapters'] as List).cast<Map>())
                SourceChapter(
                  url: '/series/$slug/ch-${_stoneNum('${c['chapterNumber']}')}#${c['chapterId']}',
                  name: 'Chapter ${_stoneNum('${c['chapterNumber']}')}'
                      '${('${c['title'] ?? ''}').isNotEmpty ? ' - ${c['title']}' : ''}',
                  number: double.tryParse('${c['chapterNumber']}'),
                  uploadedAt: DateTime.tryParse('${c['createdAt']}'),
                ),
            ].reversed.toList(),
          );
        },
        pagesFn: (s, ch) async {
          final id = ch.url.split('#').last;
          final d = await s.fetchJson(Uri.parse('${s.baseUrl}/api/chapters/$id/pages')) as Map;
          var pages = (d['pages'] as List? ?? const []).cast<Map>();
          if (pages.isEmpty) pages = (d['images'] as List? ?? const []).cast<Map>();
          return [for (final p in pages) '${s.baseUrl}${p['url']}'];
        },
      ),
      // O Translations
      FnSource(
        id: 'en.otranslations',
        name: 'O Translations',
        baseUrl: 'https://otl.moe',
        popularFn: (s, page) async {
          final t = await s.fetchJson(Uri.parse('${s.baseUrl}/api/trending?window=today')) as Map;
          final order = [for (final e in (t['series'] as List).cast<Map>()) '${e['series']}'];
          return _otlRank(s, await _otlCatalogue(s), order);
        },
        latestFn: (s, page) async {
          final res = await s.fetchHtml(Uri.parse(s.baseUrl));
          final order = <String>[];
          for (final a in res.document.querySelectorAll('[data-latest-item] a[href*="/series/"]')) {
            final seg = Uri.parse(a.attributes['href']!).pathSegments;
            final i = seg.indexOf('series');
            if (i >= 0 && i + 1 < seg.length && !order.contains(seg[i + 1])) order.add(seg[i + 1]);
          }
          return _otlRank(s, await _otlCatalogue(s), order);
        },
        searchFn: (s, page, q) async {
          final words = _OtlEntry.words(q);
          final all = await _otlCatalogue(s);
          if (words.isEmpty) return _otlRank(s, all, const []);
          final scored = <MapEntry<_OtlEntry, int>>[];
          for (final e in all) {
            final sc = [for (final w in words) e.score(w)];
            if (!sc.contains(0)) scored.add(MapEntry(e, sc.fold(0, (a, b) => a + b)));
          }
          scored.sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.title.compareTo(b.key.title));
          return MangaPage([for (final e in scored) e.key.toManga(s.baseUrl)], hasNextPage: false);
        },
        detailsFn: (s, url) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/series/$url/'));
          final doc = res.document;
          Element? info(String label) {
            for (final div in doc.querySelectorAll('dl div')) {
              final dt = div.children.where((c) => c.localName == 'dt').firstOrNull;
              if (dt != null && ownText(dt).contains(label)) {
                return div.children.where((c) => c.localName == 'dd').firstOrNull;
              }
            }
            return null;
          }

          final h1 = doc.querySelector('main h1');
          final genres = <String>{
            if (_text(info('Type')) != null) _text(info('Type'))!,
            for (final li in doc.querySelectorAll('main h1 ~ ul > li')) clean(li.text),
            for (final sp in info('Tags')?.querySelectorAll('span') ?? const <Element>[]) clean(sp.text),
          }.where((e) => e.isNotEmpty).toList();
          final desc = <String>[];
          final meta = [_text(info('Year')), _text(info('Content Rating'))].whereType<String>().toList();
          if (meta.isNotEmpty) desc.add(meta.join(' · '));
          final syn = doc.querySelector('[data-synopsis]')?.text.trim();
          if (syn != null && syn.isNotEmpty) desc.add(syn);
          final alt = _text(h1?.previousElementSibling);
          if (alt != null) desc.add('Alternative title: $alt');
          final chapters = <SourceChapter>[];
          for (final li in doc.querySelectorAll('li[data-chapter-number]')) {
            final number = li.attributes['data-chapter-number'] ?? '';
            final title = li.attributes['data-chapter-title'] ?? '';
            final href = li.querySelector('a[href]')?.attributes['href'];
            if (href == null) continue;
            final segs = Uri.parse(href).pathSegments.where((e) => e.isNotEmpty).toList();
            chapters.add(SourceChapter(
              url: segs.skip(1).join('/'),
              name: title.isEmpty
                  ? 'Chapter $number'
                  : title.startsWith('Chapter ')
                      ? title
                      : 'Chapter $number: $title',
              number: double.tryParse(number),
            ));
          }
          return SourceMangaDetails(
            url: url,
            title: clean(h1?.text),
            thumbnailUrl: attrAbs(doc.querySelector('[data-cover-open] img'), 'src', s.baseUri),
            author: _text(info('Authors')),
            artist: _text(info('Artists')),
            genres: genres,
            description: desc.isEmpty ? null : desc.join('\n\n'),
            status: parseStatus(_text(info('Status'))?.toLowerCase()),
            chapters: chapters.reversed.toList(),
          );
        },
        pagesFn: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/read/${ch.url}/'));
          final island = res.document.querySelector('astro-island[component-url*="/Reader"]');
          final props = _unwrapAstro(jsonDecode(island!.attributes['props']!)) as Map;
          final pages = ((props['chapter'] as Map)['pages'] as List).cast<String>();
          return [for (final p in pages) s.baseUri.resolve(p).toString()];
        },
      ),
      // Ninko Comics
      FnSource(
        id: 'en.ninkocomics',
        name: 'Ninko Comics',
        baseUrl: 'https://ninkocomics.com',
        popularFn: (s, page) => _ninkoList(s, 'popular'),
        latestFn: (s, page) => _ninkoList(s, 'latest'),
        searchFn: (s, page, q) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/search/').replace(queryParameters: {'q': q}));
          return MangaPage(_ninkoComics(res.document, s.baseUri), hasNextPage: false);
        },
        detailsFn: (s, url) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}$url'));
          final doc = res.document;
          Map? series;
          for (final sc in doc.querySelectorAll('script[type="application/ld+json"]')) {
            if (sc.text.contains('ComicSeries')) {
              series = jsonDecode(sc.text) as Map;
              break;
            }
          }
          final badges = [for (final c in doc.querySelector('h1')?.previousElementSibling?.children ?? const <Element>[]) clean(c.text)];
          final status = badges.contains('Ongoing')
              ? SourceMangaStatus.ongoing
              : badges.contains('Completed')
                  ? SourceMangaStatus.completed
                  : badges.contains('Hiatus')
                      ? SourceMangaStatus.hiatus
                      : badges.contains('Dropped')
                          ? SourceMangaStatus.cancelled
                          : SourceMangaStatus.unknown;
          final schedule = badges.where((e) => e.startsWith('New chapter')).firstOrNull;
          final desc = [
            if (schedule != null) schedule,
            if (_text(doc.querySelector('[data-clamp]')) != null) _text(doc.querySelector('[data-clamp]'))!,
            if ((series?['alternateName'] as List?)?.isNotEmpty ?? false)
              'Alternative titles: ${(series!['alternateName'] as List).join(', ')}',
          ];
          final chapters = <SourceChapter>[];
          for (final a in doc.querySelectorAll('li[data-chapter-id] > a')) {
            final title = clean(a.querySelector('span.min-w-0 > span')?.text);
            chapters.add(SourceChapter(
              url: Uri.parse(a.attributes['href']!).path,
              name: a.attributes.containsKey('data-unlock') ? '🔒 $title' : title,
              number: parseChapterNumber(title),
              uploadedAt: _ninkoDate(a.querySelector('[data-percent-label]')?.attributes['title']),
            ));
          }
          return SourceMangaDetails(
            url: url,
            title: '${series?['name'] ?? clean(doc.querySelector('h1')?.text)}',
            thumbnailUrl: series?['image'] as String?,
            author: (series?['author'] as Map?)?['name'] as String?,
            genres: [for (final g in (series?['genre'] as List? ?? const [])) '$g'],
            description: desc.isEmpty ? null : desc.join('\n\n'),
            status: status,
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}${ch.url}'));
          return [
            for (final img in res.document.querySelectorAll('img[src*="/media/pages/"]'))
              s.baseUri.resolve(img.attributes['src']!).toString(),
          ];
        },
      ),
    ];
