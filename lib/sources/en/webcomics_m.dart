// Situs katalog (bagian M), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0): nuviatoon, rinkocomics.

import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import 'fn_source.dart';

// ------------------------------------------------------------------- NuviaToon

String _titleWords(String s) =>
    s.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

MangaPage _nuviaPage(Object? json) {
  final d = json as Map;
  final meta = d['meta'] as Map?;
  final page = (meta?['page'] as num?)?.toInt() ?? 1;
  final total = (meta?['totalPages'] as num?)?.toInt() ?? 1;
  return MangaPage([
    for (final c in (d['data'] as List).cast<Map>())
      SourceManga(
        url: '${c['slug']}',
        title: '${c['title']}',
        thumbnailUrl: (c['coverUrl'] ?? c['coverThumbUrl']) as String?,
      ),
  ], hasNextPage: page < total);
}

Future<MangaPage> _nuviaList(HttpSource s, int page, String sort, [String? q]) async => _nuviaPage(
      await s.fetchJson(
        Uri.parse('${s.baseUrl}/api/comics').replace(queryParameters: {
          'page': '$page',
          'pageSize': '18',
          if (q != null && q.isNotEmpty) 'q': q,
          'sort': sort,
        }),
        headers: const {'Accept': 'application/json'},
      ),
    );

// ----------------------------------------------------------------- RinkoComics

String? _rinkoImg(Element? e, Uri base) {
  if (e == null) return null;
  for (final k in const ['data-src', 'data-lazy-src', 'src']) {
    final v = e.attributes[k];
    if (v != null && v.trim().isNotEmpty) return absUrl(base, v.trim());
  }
  return null;
}

MangaPage _rinkoPage(Document doc, Uri base) {
  final items = <SourceManga>[];
  for (final card in doc.querySelectorAll('article.ac-card')) {
    final a = card.querySelector('.ac-title a');
    final href = absUrl(base, a?.attributes['href']?.trim());
    if (a == null || href == null) continue;
    items.add(SourceManga(
      url: Uri.parse(href).path,
      title: clean(a.text),
      thumbnailUrl: _rinkoImg(card.querySelector('.ac-thumb img'), base),
    ));
  }
  return MangaPage(items, hasNextPage: doc.querySelector('.ac-pagination a.next') != null);
}

bool _rinkoLocked(Element el) {
  final reason = (el.attributes['data-reason'] ?? '').toLowerCase();
  if (reason.isNotEmpty && reason != 'free') return true;
  if (el.classes.contains('locked-chapter')) return true;
  final href = el.querySelector('a')?.attributes['href'] ?? '';
  if (href.isEmpty || href == '#') return true;
  return el.querySelector('.chapter_price') != null;
}

List<SourceChapter> _rinkoChapters(Iterable<Element> els, Uri base) {
  final out = <SourceChapter>[];
  for (final el in els) {
    final permalink = (el.attributes['data-permalink'] ?? '').trim();
    final href = absUrl(base, el.querySelector('a')?.attributes['href']) ?? '';
    final url = permalink.isNotEmpty ? permalink : href;
    if (url.isEmpty) continue;
    var name = clean(el.querySelector('.chapter-number')?.text);
    if (name.isEmpty) name = clean(el.attributes['data-title']);
    final locked = _rinkoLocked(el);
    final path = Uri.parse(absUrl(base, url) ?? url).path;
    out.add(SourceChapter(
      url: locked ? '$path#lock' : path,
      name: locked ? '🔒 $name' : name,
      number: parseChapterNumber(name),
      uploadedAt: parseLooseDate(el.querySelector('.chapter-date')?.text),
    ));
  }
  return out;
}

List<MangaSource> webcomicsM() => [
      // NuviaToon
      FnSource(
        id: 'en.nuviatoon',
        name: 'Nuvia Toon',
        baseUrl: 'https://nuviatoon.org',
        popularFn: (s, page) => _nuviaList(s, page, 'popular'),
        latestFn: (s, page) => _nuviaList(s, page, 'newest'),
        searchFn: (s, page, q) => _nuviaList(s, page, 'popular', q),
        detailsFn: (s, slug) async {
          final d = (await s.fetchJson(Uri.parse('${s.baseUrl}/api/comics/$slug'),
              headers: const {'Accept': 'application/json'}) as Map)['data'] as Map;
          final avg = (d['ratingAvg'] as num?)?.toDouble();
          final count = (d['ratingCount'] as num?)?.toInt() ?? 0;
          final alt = [for (final a in (d['altTitles'] as List? ?? const [])) '$a'];
          final desc = [
            if (count > 0 && avg != null) 'Rating: ${avg.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')}/5 ($count ratings)',
            if ('${d['description'] ?? ''}'.isNotEmpty) '${d['description']}',
            if (alt.isNotEmpty) 'Associated Name(s):\n${alt.map((e) => '- $e').join('\n')}',
          ];
          final st = '${d['seriesStatus'] ?? ''}'.toLowerCase();
          return SourceMangaDetails(
            url: slug,
            title: '${d['title']}',
            thumbnailUrl: (d['coverUrl'] ?? d['coverThumbUrl']) as String?,
            author: d['author'] as String?,
            artist: d['artist'] as String?,
            genres: [
              if (d['type'] != null) _titleWords('${d['type']}'.toLowerCase()),
              for (final g in (d['genres'] as List? ?? const []).cast<Map>()) _titleWords('${g['name']}'),
            ],
            description: desc.isEmpty ? null : desc.join('\n\n'),
            status: parseStatus(st == 'dropped' ? 'cancelled' : st),
            chapters: [
              for (final c in (d['chapters'] as List? ?? const []).cast<Map>())
                if (((c['priceCoins'] as num?) ?? 0) == 0)
                  () {
                    final n = (c['number'] as num?)?.toDouble();
                    final ns = n == null ? '' : (n == n.truncateToDouble() ? n.toInt().toString() : n.toString());
                    final title = '${c['title'] ?? ''}'.trim();
                    return SourceChapter(
                      url: '$slug/chapter/$ns#${c['id']}',
                      name: title.isNotEmpty ? title : 'Chapter $ns'.trim(),
                      number: n,
                      uploadedAt: DateTime.tryParse('${c['publishedAt']}'),
                    );
                  }(),
            ],
          );
        },
        pagesFn: (s, ch) async {
          final id = ch.url.split('#').last;
          final d = (await s.fetchJson(Uri.parse('${s.baseUrl}/api/comic-chapters/$id/content'),
              headers: const {'Accept': 'application/json'}) as Map)['data'] as Map;
          final pages = (d['pages'] as List).cast<Map>()
            ..sort((a, b) => (a['index'] as num).compareTo(b['index'] as num));
          return [for (final p in pages) '${p['url']}'];
        },
      ),
      // Rinko Comics
      FnSource(
        id: 'en.rinkocomics',
        name: 'Rinko Comics',
        baseUrl: 'https://rinkocomics.com',
        popularFn: (s, page) async {
          final doc = (await s.fetchHtml(Uri.parse(s.baseUrl))).document;
          final items = <SourceManga>[];
          for (final card in doc.querySelectorAll('.comics-flex-pinned a.pinned-comic-card')) {
            final href = absUrl(s.baseUri, card.attributes['href']?.trim());
            final title = clean(card.querySelector('.pinned-comic-title')?.text);
            if (href == null || title.isEmpty) continue;
            items.add(SourceManga(
              url: Uri.parse(href).path,
              title: title,
              thumbnailUrl: _rinkoImg(card.querySelector('.comic-thumbnail img'), s.baseUri),
            ));
          }
          return MangaPage(items, hasNextPage: false);
        },
        latestFn: (s, page) async {
          final path = page <= 1 ? '/comic/' : '/comic/page/$page/';
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}$path').replace(queryParameters: {'sort': 'newest'}));
          return _rinkoPage(res.document, s.baseUri);
        },
        searchFn: (s, page, q) async {
          final path = page <= 1 ? '/comic/' : '/comic/page/$page/';
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}$path').replace(queryParameters: {'post_type': 'comic', 's': q}));
          return _rinkoPage(res.document, s.baseUri);
        },
        detailsFn: (s, url) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}$url'));
          final doc = res.document;
          final authors = <String>[];
          for (final e in doc.querySelectorAll('.comic-graph > span')) {
            final t = clean(e.text);
            if (t.isNotEmpty && t != '•' && !authors.contains(t)) authors.add(t);
          }
          final chapters = <String, SourceChapter>{};
          void add(Iterable<SourceChapter> l) {
            for (final c in l) {
              chapters.putIfAbsent(c.url, () => c);
            }
          }

          add(_rinkoChapters(doc.querySelectorAll('li.chapter'), s.baseUri));
          final btn = doc.querySelector('#loadMoreChaptersBtn');
          final comicId = btn?.attributes['data-comic-id'] ?? '';
          final nonce = RegExp(r'comicworld_ajax\s*=\s*\{[^}]*"nonce"\s*:\s*"([^"]+)"').firstMatch(res.body)?.group(1) ?? '';
          var offset = int.tryParse(btn?.attributes['data-offset'] ?? '') ?? 0;
          if (offset <= 0 || (chapters.isNotEmpty && offset > chapters.length)) offset = chapters.length;
          if (comicId.isNotEmpty && nonce.isNotEmpty) {
            for (var guard = 0; guard < 500; guard++) {
              final r = await s.postFormJson(Uri.parse('${s.baseUrl}/wp-admin/admin-ajax.php'), {
                'action': 'load_more_chapters',
                'nonce': nonce,
                'comic_id': comicId,
                'offset': '$offset',
              });
              final html = (r is Map && r['success'] == true) ? '${(r['data'] as Map?)?['html'] ?? ''}' : '';
              if (html.trim().isEmpty) break;
              final items = _rinkoChapters(html_parser.parseFragment(html).querySelectorAll('li.chapter'), s.baseUri);
              if (items.isEmpty) break;
              add(items);
              offset += 10;
            }
          }
          final title = clean(doc.querySelector('.comic-info-upper h1')?.text ?? doc.querySelector('h1')?.text);
          return SourceMangaDetails(
            url: url,
            title: title,
            thumbnailUrl: doc.querySelector('meta[property="og:image"]')?.attributes['content'],
            author: authors.firstOrNull,
            artist: authors.length > 1 ? authors[1] : null,
            genres: [for (final g in doc.querySelectorAll('.comic-genres .genres .genre')) clean(g.text)],
            description: _nonEmpty(clean(doc.querySelector('.comic-synopsis')?.text)),
            status: parseStatus(clean(doc.querySelector('.comic-status span:last-child')?.text).toLowerCase()),
            chapters: chapters.values.where((c) => !c.url.endsWith('#lock')).toList(),
          );
        },
        pagesFn: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}${ch.url}'));
          final payload = res.document.querySelector('script#cwPages')?.text.trim();
          if (payload == null || payload.isEmpty) return const [];
          final raw = base64.decode(base64.normalize(payload));
          final out = List<int>.generate(raw.length - 16, (i) => (raw[i + 16] & 0xFF) ^ (raw[i % 16] & 0xFF));
          return (jsonDecode(utf8.decode(out)) as List).cast<String>();
        },
      ),
    ];

String? _nonEmpty(String s) => s.isEmpty ? null : s;
