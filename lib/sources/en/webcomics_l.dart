// Situs katalog (bagian L), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0): luxmanga, aethonwebcomics,
// mangack.

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import 'fn_source.dart';

// -------------------------------------------------------------------- LuxManga

const _luxApi = 'https://api.luxmanga.net';

SourceManga _luxManga(Map w) {
  final cover = '${w['cover_url'] ?? ''}';
  return SourceManga(
    url: '${w['id']}',
    title: '${w['title']}',
    thumbnailUrl: cover.isEmpty ? null : Uri.parse(_luxApi).resolve(cover).toString(),
  );
}

Future<MangaPage> _luxRanking(HttpSource s, String path, int limit) async {
  final d = await s.fetchJson(Uri.parse('$_luxApi/works/$path?limit=$limit')) as Map;
  return MangaPage([for (final w in (d['data'] as List).cast<Map>()) _luxManga(w)], hasNextPage: false);
}

String _chNum(double n) => n == n.truncateToDouble() ? n.toInt().toString() : n.toString();

// --------------------------------------------------------------------- Aethon

String _aeApi(String route, Map<String, String> q) =>
    Uri.parse('https://aethonwebcomics.com/wp-json/wp/v2/$route').replace(queryParameters: q).toString();

const _aeSeriesFields = 'slug,title,_links,_embedded,meta.webcomic_status,meta.webcomic_series_card_image_id,'
    'meta.webcomic_series_description,meta.webcomic_logline,meta.webcomic_age_rating,'
    'meta.webcomic_update_cadence,meta.webcomic_update_day';

String _titleCase(String s) =>
    s.split('_').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

String? _aeTerms(Map s, String taxonomy) {
  final terms = ((s['_embedded'] as Map?)?['wp:term'] as List? ?? const []).expand((e) => e as List);
  final names = [for (final t in terms.cast<Map>()) if (t['taxonomy'] == taxonomy) '${t['name']}'];
  return names.isEmpty ? null : names.join(', ');
}

Future<List<(Map, String?)>> _aeSeries(HttpSource s, Map<String, String> q) async {
  final list = await s.fetchJson(Uri.parse(_aeApi('webcomic_series', {
    'per_page': '24',
    '_embed': 'wp:term',
    '_fields': _aeSeriesFields,
    ...q,
  }))) as List;
  final series = list.cast<Map>();
  final ids = {for (final x in series) (x['meta'] as Map)['webcomic_series_card_image_id']}.whereType<num>().toList();
  final covers = <int, String>{};
  if (ids.isNotEmpty) {
    final media = await s.fetchJson(Uri.parse(_aeApi('media', {
      'include': ids.join(','),
      'per_page': '100',
      '_fields': 'id,source_url',
    }))) as List;
    for (final m in media.cast<Map>()) {
      covers[(m['id'] as num).toInt()] = '${m['source_url']}';
    }
  }
  return [
    for (final x in series) (x, covers[((x['meta'] as Map)['webcomic_series_card_image_id'] as num?)?.toInt()]),
  ];
}

MangaPage _aePage(List<(Map, String?)> l) => MangaPage([
      for (final (x, cover) in l)
        SourceManga(
          url: '${x['slug']}',
          title: html_parser.parseFragment('${(x['title'] as Map)['rendered']}').text ?? '${x['slug']}',
          thumbnailUrl: cover,
        ),
    ], hasNextPage: l.length >= 24);

String? _aeDescription(Map meta) {
  final cadence = '${meta['webcomic_update_cadence'] ?? ''}';
  final day = '${meta['webcomic_update_day'] ?? ''}';
  final status = '${meta['webcomic_status'] ?? ''}';
  final schedule = [cadence, day].where((e) => e.isNotEmpty).map(_titleCase).join(' on ');
  final age = '${meta['webcomic_age_rating'] ?? ''}';
  final info = [
    if (status == 'coming_soon') 'Coming Soon',
    if (age.isNotEmpty) _titleCase(age),
    if (schedule.isNotEmpty) schedule,
  ].join(' · ');
  final paragraphs = [
    for (final p in html_parser.parseFragment('${meta['webcomic_series_description'] ?? ''}').querySelectorAll('p'))
      clean(p.text),
  ];
  final logline = '${meta['webcomic_logline'] ?? ''}';
  final out = [info, if (!paragraphs.contains(logline)) logline, ...paragraphs].where((e) => e.isNotEmpty).toList();
  return out.isEmpty ? null : out.join('\n\n');
}

// -------------------------------------------------------------------- Mangack

const _mkSkip =
    r'/wp-content/(?:themes|plugins)/|/(?:logo|icon|cropped|preroll|placeholder|loading|spinner|chainsaw)[^/]*\.(?:png|jpe?g|webp|gif|svg)';

Future<MangaPage> _mkList(HttpSource s, Map<String, String> q, int page) async {
  final list = await s.fetchJson(Uri.parse('${s.baseUrl}/wp-json/wp/v2/manga').replace(queryParameters: {
    'page': '$page',
    'per_page': '24',
    '_embed': 'wp:featuredmedia',
    ...q,
  })) as List;
  return MangaPage([
    for (final m in list.cast<Map>())
      SourceManga(
        url: Uri.parse('${m['link']}').path,
        title: html_parser.parseFragment('${(m['title'] as Map)['rendered']}').text ?? '',
        thumbnailUrl: (((m['_embedded'] as Map?)?['wp:featuredmedia'] as List?)?.firstOrNull as Map?)?['source_url'] as String?,
      ),
  ], hasNextPage: list.length >= 24);
}

String _humanize(String slug) => slug
    .split('-')
    .where((e) => e.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1))
    .join(' ');

String? _mkImg(Element? e, Uri base) {
  if (e == null) return null;
  for (final k in const ['data-src', 'data-lazy-src', 'src']) {
    final v = e.attributes[k];
    if (v != null && v.isNotEmpty) return absUrl(base, v);
  }
  return null;
}

List<MangaSource> webcomicsL() => [
      // LuxManga
      FnSource(
        id: 'en.luxmanga',
        name: 'LuxManga',
        baseUrl: 'https://luxmanga.net',
        popularFn: (s, page) => _luxRanking(s, 'most-read', 20),
        latestFn: (s, page) => _luxRanking(s, 'latest-updates', 24),
        searchFn: (s, page, q) async {
          final d = await s.fetchJson(Uri.parse('$_luxApi/works').replace(queryParameters: {
            'search': q,
            'limit': '24',
            'page': '$page',
          })) as Map;
          final total = ((d['meta'] as Map?)?['total_pages'] as num?)?.toInt() ?? 1;
          return MangaPage([for (final w in (d['data'] as List).cast<Map>()) _luxManga(w)], hasNextPage: page < total);
        },
        detailsFn: (s, id) async {
          final w = await s.fetchJson(Uri.parse('$_luxApi/works/$id')) as Map;
          final meta = await s.fetchJson(Uri.parse('$_luxApi/works/$id/metadata')) as Map;
          final g = await s.fetchJson(Uri.parse('$_luxApi/works/$id/genres')) as Map;
          Uri chUri(int p) => Uri.parse('$_luxApi/works/$id/chapters')
              .replace(queryParameters: {'page': '$p', 'limit': '100', 'order': 'desc'});
          final first = await s.fetchJson(chUri(1)) as Map;
          final all = <Map>[...(first['data'] as List).cast<Map>()];
          final pages = ((first['meta'] as Map?)?['total_pages'] as num?)?.toInt() ?? 1;
          for (var p = 2; p <= pages; p++) {
            all.addAll(((await s.fetchJson(chUri(p)) as Map)['data'] as List).cast<Map>());
          }
          final title = '${w['title']}';
          final seen = <String>{};
          final tags = <String>[
            for (final x in (g['data'] as List).cast<Map>()) '${x['name_en']}',
            for (final t in (meta['tags'] as List? ?? const [])) '$t',
          ].map((t) => t.isEmpty ? t : t[0].toUpperCase() + t.substring(1)).where((t) => seen.add(t.toLowerCase())).toList();
          final alt = [for (final a in (meta['alternative_titles'] as List? ?? const [])) '$a']
              .where((a) => a.toLowerCase() != title.toLowerCase())
              .toList();
          final desc = [
            if ('${w['description'] ?? ''}'.trim().isNotEmpty) '${w['description']}',
            if (alt.isNotEmpty) 'Also known as: ${alt.join(' · ')}',
          ];
          final author = '${w['author'] ?? ''}';
          return SourceMangaDetails(
            url: id,
            title: title,
            thumbnailUrl: _luxManga(w).thumbnailUrl,
            author: author.trim().isEmpty || author == 'n/a' ? null : author.replaceAll(' / ', ', '),
            genres: tags,
            description: desc.isEmpty ? null : desc.join('\n\n'),
            status: parseStatus('${w['status']}'),
            chapters: [
              for (final c in all)
                if (((c['coins'] as num?) ?? 0) == 0)
                  SourceChapter(
                    url: '${c['id']}',
                    name: () {
                      final n = (c['chapter_number'] as num).toDouble();
                      final ns = _chNum(n);
                      final t = '${c['title'] ?? ''}'.trim();
                      final dup = t.isEmpty || t.toLowerCase() == ns || t.toLowerCase() == 'chapter $ns';
                      return 'Chapter $ns${dup ? '' : ' — $t'}';
                    }(),
                    number: (c['chapter_number'] as num).toDouble(),
                    uploadedAt: DateTime.tryParse('${c['created_at']}'),
                  ),
            ],
          );
        },
        pagesFn: (s, ch) async {
          final d = await s.fetchJson(Uri.parse('$_luxApi/chapters/${ch.url}')) as Map;
          return [for (final p in (d['images'] as List)) Uri.parse(_luxApi).resolve('$p').toString()];
        },
      ),
      // Aethon Webcomics
      FnSource(
        id: 'en.aethonwebcomics',
        name: 'Aethon Webcomics',
        baseUrl: 'https://aethonwebcomics.com',
        popularFn: (s, page) async => _aePage(await _aeSeries(s, {'page': '$page', 'orderby': 'title', 'order': 'asc'})),
        latestFn: (s, page) async {
          final eps = await s.fetchJson(Uri.parse(_aeApi('webcomic_episode', {
            'per_page': '100',
            '_fields': 'meta.webcomic_series_id',
          }))) as List;
          final ids = <String>[];
          for (final e in eps.cast<Map>()) {
            final id = '${(e['meta'] as Map)['webcomic_series_id']}';
            if (!ids.contains(id)) ids.add(id);
          }
          if (ids.isEmpty) return const MangaPage([], hasNextPage: false);
          return _aePage(await _aeSeries(s, {
            'page': '$page',
            'include': ids.join(','),
            'orderby': 'include',
            'order': 'asc',
          }));
        },
        searchFn: (s, page, q) async => _aePage(await _aeSeries(s, {
          'page': '$page',
          'search': q,
          'orderby': 'title',
          'order': 'asc',
        })),
        detailsFn: (s, slug) async {
          final l = await _aeSeries(s, {'slug': slug});
          final (x, cover) = l.first;
          final meta = x['meta'] as Map;
          final st = '${meta['webcomic_status']}';
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/webcomics/$slug/'));
          final cards = [
            for (final c in res.document.querySelectorAll('[data-webcomic-episode-page] .modfarm-webcomic-episode-card'))
              if (c.querySelector('.modfarm-webcomic-episode-card-meta') == null ||
                  !c.querySelectorAll('.modfarm-webcomic-episode-card-meta').any((m) => m.text.contains('Premium')))
                c,
          ];
          final ids = [
            for (final c in cards) int.tryParse((c.id).replaceFirst('webcomic-episode-', '')),
          ].whereType<int>().toList();
          final dates = <int, DateTime>{};
          for (var i = 0; i < ids.length; i += 100) {
            final chunk = ids.skip(i).take(100).toList();
            final d = await s.fetchJson(Uri.parse(_aeApi('webcomic_episode', {
              'include': chunk.join(','),
              'per_page': '100',
              '_fields': 'id,date_gmt',
            }))) as List;
            for (final e in d.cast<Map>()) {
              final dt = DateTime.tryParse('${e['date_gmt']}Z');
              if (dt != null) dates[(e['id'] as num).toInt()] = dt;
            }
          }
          final chapters = <SourceChapter>[];
          for (final c in cards) {
            final href = c.querySelector('a')?.attributes['href'];
            if (href == null) continue;
            final segs = Uri.parse(href).pathSegments.where((e) => e.isNotEmpty).toList();
            if (segs.length < 2) continue;
            final eid = int.tryParse(c.id.replaceFirst('webcomic-episode-', ''));
            chapters.add(SourceChapter(
              url: segs[1],
              name: clean(c.querySelector('.modfarm-webcomic-episode-card-title')?.text),
              number: double.tryParse(clean(c.querySelector('.modfarm-webcomic-episode-number')?.text).replaceFirst('#', '')),
              uploadedAt: eid == null ? null : dates[eid],
            ));
          }
          return SourceMangaDetails(
            url: slug,
            title: html_parser.parseFragment('${(x['title'] as Map)['rendered']}').text ?? slug,
            thumbnailUrl: cover,
            author: _aeTerms(x, 'webcomic_writer'),
            artist: _aeTerms(x, 'webcomic_artist'),
            genres: _aeTerms(x, 'webcomic_genre')?.split(', ') ?? const [],
            description: _aeDescription(meta),
            status: st == 'ongoing'
                ? SourceMangaStatus.ongoing
                : st == 'hiatus' || st == 'between_seasons'
                    ? SourceMangaStatus.hiatus
                    : st == 'complete'
                        ? SourceMangaStatus.completed
                        : SourceMangaStatus.unknown,
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/comic-episode/${ch.url}/'));
          if (res.document.querySelector('.mf-member-lock') != null) {
            throw Exception('Premium episode: log in via WebView with an account that has Premium');
          }
          return [
            for (final img in res.document.querySelectorAll('[data-webcomic-reader] img[data-panel-img]'))
              absUrl(s.baseUri, img.attributes['src'])!,
          ];
        },
      ),
      // Mangack
      FnSource(
        id: 'en.mangack',
        name: 'Mangack',
        baseUrl: 'https://mangack.com',
        popularFn: (s, page) => _mkList(s, {'orderby': 'date', 'order': 'desc'}, page),
        latestFn: (s, page) async {
          final path = page <= 1 ? '/updates/' : '/updates/page/$page/';
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}$path'));
          final items = <SourceManga>[];
          for (final card in res.document.querySelectorAll('.latestmanga .Latest_chapter_update')) {
            final a = card.querySelector('a[href*="/manga/"]');
            if (a == null) continue;
            final t = a.attributes['title'] ?? '';
            items.add(SourceManga(
              url: Uri.parse(absUrl(s.baseUri, a.attributes['href'])!).path,
              title: t.isEmpty ? clean(a.text) : t,
              thumbnailUrl: _mkImg(card.querySelector('img'), s.baseUri),
            ));
          }
          return MangaPage(items,
              hasNextPage: res.document.querySelector('.pagination a.next, a.next.page-numbers') != null);
        },
        searchFn: (s, page, q) => _mkList(s, {'search': q}, page),
        detailsFn: (s, url) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}$url'));
          final doc = res.document;
          final article = doc.querySelector('article');
          final classes = article?.classes.toList() ?? const <String>[];
          String? cls(String prefix) {
            final c = classes.where((e) => e.startsWith(prefix)).firstOrNull;
            return c?.substring(prefix.length);
          }

          final type = cls('comic-type-');
          final genres = [
            for (final c in classes)
              if (c.startsWith('Genres-')) _humanize(c.substring(7)),
            if (type != null) _humanize(type),
          ].where((e) => e.isNotEmpty).toList();
          final synopsis = clean(doc.querySelector('meta[property="og:description"]')?.attributes['content']);
          final info = <String, String>{};
          for (final tr in (article ?? doc.documentElement!).querySelectorAll('table.infobox tr')) {
            final cells = tr.children;
            if (cells.length < 2) continue;
            final v = clean(cells[1].text);
            info[clean(cells[0].text)] = v.contains('Warning') ? '' : v;
          }
          String? follow(String label) => doc
              .querySelectorAll('.follow-text')
              .map((e) => clean(e.text))
              .where((e) => e.toLowerCase().startsWith(label))
              .firstOrNull;
          final desc = [
            if (synopsis.isNotEmpty) synopsis,
            if ((info['Alternative'] ?? '').isNotEmpty) 'Alternative: ${info['Alternative']}',
            if ((info['Realized in'] ?? '').isNotEmpty) 'Year: ${info['Realized in']}',
            if (follow('followers') != null) follow('followers')!,
            if (follow('views') != null) follow('views')!,
          ];
          final title = clean(doc.querySelector('h1.entry-title')?.text);
          final chapters = <SourceChapter>[];
          for (final li in doc.querySelectorAll('ul.chapterslist li')) {
            final a = li.querySelector('a.title, a[href*="/chapter/"]');
            if (a == null) continue;
            final own = a.nodes.whereType<Text>().map((e) => e.text).join().trim();
            final name = own.isEmpty ? clean(a.text) : own;
            chapters.add(SourceChapter(
              url: Uri.parse(absUrl(s.baseUri, a.attributes['href'])!).path,
              name: name,
              number: parseChapterNumber(name),
              uploadedAt: parseLooseDate(li.querySelector('.entry-date')?.text),
            ));
          }
          return SourceMangaDetails(
            url: url,
            title: title.isEmpty
                ? clean(doc.querySelector('meta[property="og:title"]')?.attributes['content']).replaceFirst(RegExp(r' mangack$'), '')
                : title,
            thumbnailUrl: doc.querySelector('meta[property="og:image"]')?.attributes['content'] ??
                _mkImg(article?.querySelector('figure img, .mediumthumbnail1 img'), s.baseUri),
            genres: genres,
            description: desc.isEmpty ? null : desc.join('\n\n'),
            status: parseStatus(cls('manga-status-')),
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final slug = ch.url.split('/').where((e) => e.isNotEmpty).last;
          final l = await s.fetchJson(Uri.parse('${s.baseUrl}/wp-json/wp/v2/chapter')
              .replace(queryParameters: {'slug': slug, '_fields': 'id,content'})) as List;
          if (l.isEmpty) return const [];
          final html = '${((l.first as Map)['content'] as Map?)?['rendered'] ?? ''}';
          final skip = RegExp(_mkSkip, caseSensitive: false);
          return [
            for (final m in RegExp(r'''<img[^>]+src=["']([^"']+)["']''').allMatches(html))
              if (!skip.hasMatch(m[1]!)) m[1]!,
          ];
        },
      ),
    ];
