// Sumber dewasa dinamis (bagian fn), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0): src/en/*.

import 'dart:convert';

import 'package:html/dom.dart';

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';
import 'fn_source.dart';

List<MangaSource> adultFn() => [
      FnSource(
        id: 'en.hentaikisu',
        name: 'HentaiKisu',
        baseUrl: 'https://hentaikisu.com',
        contentWarning: ContentWarning.nsfw,
        popularFn: (s, page) async {
          final json = await s.fetchJson(Uri.parse('${s.baseUrl}/backend/infinite.index.php?p=$page'));
          final items = <SourceManga>[
            for (final e in (json as List).cast<Map>())
              SourceManga(url: '${s.baseUrl}/g/${e['id']}', title: '${e['title']}', thumbnailUrl: '${e['img']}'),
          ];
          return MangaPage(items, hasNextPage: items.isNotEmpty);
        },
        searchFn: (s, page, q) async {
          if (page > 1) return const MangaPage([], hasNextPage: false);
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/search').replace(queryParameters: {'s': q}));
          final items = <SourceManga>[];
          for (final card in res.document.querySelectorAll('div.book-list')) {
            final a = card.querySelector('a[href]');
            final href = attrAbs(a, 'href', res.url);
            if (a == null || href == null) continue;
            items.add(SourceManga(
              url: href,
              title: clean(card.querySelector('.book-description p')?.text ?? a.attributes['title']),
              thumbnailUrl: imgAttr(card.querySelector('img'), res.url),
            ));
          }
          return MangaPage(items, hasNextPage: false);
        },
        detailsFn: (s, url) async {
          final res = await s.fetchHtml(Uri.parse(url));
          final doc = res.document;
          final h1s = doc.querySelectorAll('h1');
          final title = clean(h1s.length > 1 ? h1s.last.text : h1s.firstOrNull?.text);
          if (title.isEmpty) throw SourceException(SourceErrorKind.parse);
          final imgs = doc.querySelectorAll('img.thum_pre');
          return SourceMangaDetails(
            url: url,
            title: title,
            thumbnailUrl: imgAttr(doc.querySelector('img[src*="/covers/"], img[data-src*="/covers/"]'), res.url) ??
                (imgs.isEmpty ? null : imgAttr(imgs.first, res.url)),
            genres: [for (final a in doc.querySelectorAll('a.tag')) clean(a.text)].where((e) => e.isNotEmpty).toList(),
            status: SourceMangaStatus.completed,
            chapters: [SourceChapter(url: url, name: 'Oneshot', number: 1)],
          );
        },
        pagesFn: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse(ch.url));
          final out = [
            for (final img in res.document.querySelectorAll('img.thum_pre'))
              if (attrAbs(img, 'data-src', res.url) case final u?) u,
          ];
          if (out.isEmpty) throw SourceException(SourceErrorKind.parse);
          return out;
        },
      ),
      FnSource(
        id: 'en.revivalscans',
        name: 'Revival Scans',
        baseUrl: 'https://www.revivalscans.com',
        contentWarning: ContentWarning.nsfw,
        popularFn: (s, page) async {
          if (page > 1) return const MangaPage([], hasNextPage: false);
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/series'));
          final items = <SourceManga>[];
          final seen = <String>{};
          for (final card in res.document.querySelectorAll('.manhwa-card')) {
            final a = card.querySelector('a.manhwa-card-title[href]');
            final href = attrAbs(a, 'href', res.url);
            if (a == null || href == null || !seen.add(href)) continue;
            items.add(SourceManga(
                url: href, title: clean(a.text), thumbnailUrl: imgAttr(card.querySelector('img'), res.url)));
          }
          return MangaPage(items, hasNextPage: false);
        },
        searchFn: (s, page, q) async {
          final all = await s.popular(1);
          final lq = q.toLowerCase();
          return MangaPage([for (final m in all.items) if (m.title.toLowerCase().contains(lq)) m], hasNextPage: false);
        },
        detailsFn: (s, url) async {
          final res = await s.fetchHtml(Uri.parse(url));
          final body = res.body.replaceAll(r'\"', '"');
          final title = RegExp(r'"title":"([^"]+)"').firstMatch(body)?[1];
          if (title == null) throw SourceException(SourceErrorKind.parse);
          final slug = Uri.parse(url).pathSegments.last;
          final chapters = <SourceChapter>[];
          final seen = <String>{};
          // Bab terbaru hanya untuk supporter; yang bisa dibaca bebas punya peran "reader".
          for (final m in RegExp(r'\{"id":"(\d+)","number":([\d.]+),"title":"([^"]*)"[^}]*?"accessRoles":\[([^\]]*)\]')
              .allMatches(body)) {
            if (!m[4]!.contains('"reader"') || !seen.add(m[1]!)) continue;
            chapters.add(SourceChapter(
                url: '${s.baseUrl}/read/$slug/${m[1]}', name: m[3]!, number: double.tryParse(m[2]!)));
          }
          chapters.sort((a, b) => (b.number ?? 0).compareTo(a.number ?? 0));
          final cover = RegExp(r'"coverImage":"([^"]+)"').firstMatch(body)?[1];
          final status = RegExp(r'"status":"([^"]+)"').firstMatch(body)?[1]?.toLowerCase();
          return SourceMangaDetails(
            url: url,
            title: title,
            thumbnailUrl: absUrl(res.url, cover),
            status: status == 'completed'
                ? SourceMangaStatus.completed
                : status == 'ongoing'
                    ? SourceMangaStatus.ongoing
                    : SourceMangaStatus.unknown,
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse(ch.url));
          final body = res.body.replaceAll(r'\"', '"');
          final out = [
            for (final m in RegExp(r'"url":"(/api/images/chapters/[^"]+)"').allMatches(body))
              absUrl(res.url, m[1])!,
          ];
          if (out.isEmpty) throw SourceException(SourceErrorKind.parse);
          return out.toSet().toList();
        },
      ),
      FnSource(
        id: 'en.webtoonhentai',
        name: 'Webtoon Hentai (unoriginal)',
        baseUrl: 'https://webtoonhentai.org',
        contentWarning: ContentWarning.nsfw,
        popularFn: (s, page) async {
          if (page > 1) return const MangaPage([], hasNextPage: false);
          final res = await s.fetchHtml(Uri.parse(s.baseUrl));
          final items = <SourceManga>[];
          final seen = <String>{};
          for (final a in res.document.querySelectorAll('a.card[href^="/webtoon/"]')) {
            final href = attrAbs(a, 'href', res.url);
            if (href == null || !seen.add(href)) continue;
            final alt = a.querySelector('img')?.attributes['alt'] ?? '';
            items.add(SourceManga(
              url: href,
              title: clean(alt.replaceFirst(RegExp(r'\s+[–-]\s+read on .*$'), '')),
              thumbnailUrl: _whCover(a.querySelector('img'), res.url),
            ));
          }
          return MangaPage(items, hasNextPage: false);
        },
        searchFn: (s, page, q) async {
          if (page > 1) return const MangaPage([], hasNextPage: false);
          final json = await s.fetchJson(Uri.parse('${s.baseUrl}/api-proxy/v1/search').replace(queryParameters: {'q': q}));
          return MangaPage([
            for (final e in ((json as Map)['data'] as List).cast<Map>())
              SourceManga(url: '${s.baseUrl}${e['href']}', title: '${e['title']}', thumbnailUrl: '${e['cover']}'),
          ], hasNextPage: false);
        },
        detailsFn: (s, url) async {
          final res = await s.fetchHtml(Uri.parse(url));
          final doc = res.document;
          final title = clean(doc.querySelector('h1')?.text).replaceFirst(RegExp(r'^18\+\s*'), '');
          if (title.isEmpty) throw SourceException(SourceErrorKind.parse);
          final chapters = <SourceChapter>[];
          final seen = <String>{};
          for (final a in doc.querySelectorAll('a[href*="/read/"]')) {
            final href = attrAbs(a, 'href', res.url);
            if (href == null || !seen.add(href)) continue;
            final n = RegExp(r'chapter-([\d.]+)').firstMatch(href)?[1];
            chapters.add(SourceChapter(url: href, name: 'Chapter ${n ?? ''}'.trim(), number: n == null ? null : double.tryParse(n)));
          }
          chapters.sort((a, b) => (b.number ?? 0).compareTo(a.number ?? 0));
          return SourceMangaDetails(
            url: url,
            title: title,
            thumbnailUrl: _whCover(doc.querySelector('.cover img, img'), res.url),
            description: clean(doc.querySelector('meta[name=description]')?.attributes['content']),
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          // /read/<slug>/chapter-N  ->  sumber asli manhwa18.cc/webtoon/<slug>/chapter-N
          final seg = Uri.parse(ch.url).pathSegments;
          final src = 'https://manhwa18.cc/webtoon/${seg[seg.length - 2]}/${seg.last}';
          final json = await s.fetchJson(Uri.parse('${s.baseUrl}/api-proxy/v1/chapter').replace(queryParameters: {'url': src}));
          final pages = [for (final p in ((json as Map)['pages'] as List)) '$p'];
          if (pages.isEmpty) throw SourceException(SourceErrorKind.parse);
          return pages;
        },
      ),
      FnSource(
        id: 'en.milftoon',
        name: 'Milftoon',
        baseUrl: 'https://milftoon.xxx',
        contentWarning: ContentWarning.nsfw,
        popularFn: (s, page) => _milfList(s, '${s.baseUrl}/manga_list/all?page=$page'),
        searchFn: (s, page, q) => _milfList(
            s, '${s.baseUrl}/search_result?keyword=${Uri.encodeQueryComponent(q)}&page=$page'),
        detailsFn: (s, url) async {
          final data = await _milfData(s, url);
          final comic = data['comic'] as Map?;
          if (comic == null) throw SourceException(SourceErrorKind.parse);
          final slug = '${comic['slug']}';
          final chapters = [
            for (final c in (((data['_aux'] as Map?)?['chapters']) as List? ?? const []).cast<Map>())
              SourceChapter(
                url: '${s.baseUrl}/comics/$slug/${c['slug']}',
                name: clean('${c['name']} ${c['nameExtend'] ?? ''}'),
                number: (c['position'] as num?)?.toDouble(),
                uploadedAt: DateTime.tryParse('${c['publishedAt']}'),
              ),
          ]..sort((a, b) => (b.number ?? 0).compareTo(a.number ?? 0));
          return SourceMangaDetails(
            url: url,
            title: '${comic['title']}',
            thumbnailUrl: _milfCover(comic['coverPath']),
            genres: [for (final t in (((data['_aux'] as Map?)?['tags']) as List? ?? const []).cast<Map>()) '${t['name']}'],
            status: SourceMangaStatus.completed,
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final data = await _milfData(s, ch.url);
          final pages = [for (final p in ((data['pages'] as List?) ?? const []).cast<Map>()) '${p['src']}'];
          if (pages.isEmpty) throw SourceException(SourceErrorKind.parse);
          return pages;
        },
      ),
      FnSource(
        id: 'en.8musesxxx',
        name: '8Muses (unoriginal)',
        baseUrl: 'https://8muses.xxx',
        contentWarning: ContentWarning.nsfw,
        popularFn: (s, page) => _m8List(s, '${s.baseUrl}/comics', page),
        searchFn: (s, page, q) =>
            _m8List(s, '${s.baseUrl}/search?q=${Uri.encodeQueryComponent(q)}', page),
        detailsFn: (s, url) async {
          final res = await s.fetchHtml(Uri.parse(url));
          final doc = res.document;
          final title = clean(doc.querySelector('h1')?.text);
          if (title.isEmpty) throw SourceException(SourceErrorKind.parse);
          final chapters = <SourceChapter>[];
          final seen = <String>{};
          for (final a in doc.querySelectorAll(r'a[href$="/read"]')) {
            final href = attrAbs(a, 'href', res.url);
            if (href == null || !seen.add(href)) continue;
            final seg = Uri.parse(href).pathSegments;
            final label = clean(a.text);
            chapters.add(SourceChapter(
              url: href,
              name: label.isEmpty || label.toLowerCase() == 'read' ? seg[seg.length - 2] : label,
              number: double.tryParse(RegExp(r'(\d+(?:\.\d+)?)$').firstMatch(seg[seg.length - 2])?[1] ?? ''),
            ));
          }
          chapters.sort((a, b) => (b.number ?? 0).compareTo(a.number ?? 0));
          return SourceMangaDetails(
            url: url,
            title: title,
            thumbnailUrl: _m8Thumb(doc.querySelector(r'img[srcset*="/thumbnail"], img[alt$="cover"]')),
            genres: [for (final a in doc.querySelectorAll('a[href^="/tags/"], a[href^="/genres/"]')) clean(a.text)]
                .where((e) => e.isNotEmpty)
                .toSet()
                .toList(),
            status: SourceMangaStatus.completed,
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse(ch.url));
          final body = res.body.replaceAll(r'\"', '"');
          final out = [
            for (final m in RegExp(r'"image_url":"([^"]+)"').allMatches(body)) m[1]!.replaceAll(r'\/', '/'),
          ];
          if (out.isEmpty) throw SourceException(SourceErrorKind.parse);
          return out.toSet().toList();
        },
      ),
    ];

/// Sampul lewat /api-proxy/v1/imgproxy?url=<asli>: pakai URL asli langsung.
String? _whCover(Element? img, Uri base) {
  final src = img?.attributes['src'];
  if (src == null) return null;
  final u = Uri.tryParse(src)?.queryParameters['url'];
  return u ?? absUrl(base, src);
}

String? _milfCover(Object? path) => path == null ? null : 'https://fdc1.azhentai.com/$path';

/// Data rute situs Nuxt/Vue yang ditanam di `window.__INITIAL_ROUTE_DATA__={...}`.
Future<Map> _milfData(HttpSource s, String url) async {
  final res = await s.fetchHtml(Uri.parse(url));
  const marker = '__INITIAL_ROUTE_DATA__=';
  final start = res.body.indexOf(marker);
  if (start < 0) throw SourceException(SourceErrorKind.parse);
  final text = res.body.substring(start + marker.length);
  var depth = 0, i = 0, inStr = false, esc = false;
  for (; i < text.length; i++) {
    final c = text[i];
    if (inStr) {
      if (esc) {
        esc = false;
      } else if (c == r'\') {
        esc = true;
      } else if (c == '"') {
        inStr = false;
      }
    } else if (c == '"') {
      inStr = true;
    } else if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) {
        i++;
        break;
      }
    }
  }
  final root = jsonDecode(text.substring(0, i)) as Map;
  // Detail seri ada di 'auxiliary' (bab, tag, sinopsis); halaman bab/daftar di 'data'.
  return {...(root['data'] as Map), if (root['auxiliary'] is Map) '_aux': root['auxiliary']};
}

Future<MangaPage> _milfList(HttpSource s, String url) async {
  final data = await _milfData(s, url);
  final items = [
    for (final e in (data['items'] as List).cast<Map>())
      SourceManga(
          url: '${s.baseUrl}/comics/${e['slug']}', title: '${e['title']}', thumbnailUrl: _milfCover(e['coverPath'])),
  ];
  final total = (data['total'] as num?)?.toInt() ?? 0;
  final size = (data['pageSize'] as num?)?.toInt() ?? 36;
  final page = (data['page'] as num?)?.toInt() ?? 1;
  return MangaPage(items, hasNextPage: page * size < total);
}

String? _m8Thumb(Element? img) {
  if (img == null) return null;
  final m = RegExp(r'url=([^&"\s]+)').firstMatch(img.attributes['srcset'] ?? img.attributes['src'] ?? '');
  return m == null ? null : Uri.decodeComponent(m[1]!);
}

Future<MangaPage> _m8List(HttpSource s, String url, int page) async {
  if (page > 1) return const MangaPage([], hasNextPage: false);
  final res = await s.fetchHtml(Uri.parse(url));
  final items = <SourceManga>[];
  final seen = <String>{};
  for (final card in res.document.querySelectorAll('article.comic-card')) {
    final a = card.querySelector('a[href^="/comics/"]');
    final href = attrAbs(a, 'href', res.url);
    if (href == null || !seen.add(href)) continue;
    final titleEl = card.querySelector('.card-details a, h2, h3');
    final alt = card.querySelector('img')?.attributes['alt'] ?? '';
    items.add(SourceManga(
      url: href,
      title: clean(titleEl?.text ?? alt.replaceFirst(RegExp(r'\s+cover$'), '')),
      thumbnailUrl: _m8Thumb(card.querySelector('img')),
    ));
  }
  return MangaPage(items, hasNextPage: false);
}
