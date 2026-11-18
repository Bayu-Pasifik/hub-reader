// Situs katalog (bagian S: situs Next.js WebtoonClub / ToonHub dan
// HentaiFC), port Dart dari extension keiyoushi/extensions-source (Apache-2.0).

import 'dart:convert';

import 'package:html/dom.dart';

import '../html_utils.dart';
import '../models.dart';
import '../next_rsc.dart';
import '../source.dart';
import 'fn_source.dart';
import 'ports_util.dart';

SourceMangaStatus _statusOf(String? s) => parseStatus(s);

List<MangaSource> portsS() => [
      FnSource(
        id: 'en.webtoonclub',
        name: 'WebtoonClub',
        baseUrl: 'https://webtoonclub.com',
        contentWarning: ContentWarning.mixed,
        popularFn: (s, page) => _wtcList(s, {'sort': 'popular'}, page),
        latestFn: (s, page) => _wtcList(s, {'sort': 'latest'}, page),
        searchFn: (s, page, q) => _wtcList(s, {'search': q}, page),
        detailsFn: (s, url) async {
          final res = await s.fetchHtml(Uri.parse(url));
          final doc = res.document;
          final body = res.document.outerHtml;
          final ld = doc.querySelector('script[type="application/ld+json"]')?.text;
          Map? book;
          if (ld != null) {
            try {
              final g = (jsonDecode(ld) as Map)['@graph'] as List?;
              book = g?.cast<Map>().firstWhere((e) => e['@type'] == 'Book', orElse: () => const {});
            } catch (_) {}
          }
          String? fact(String name) {
            for (final dt in doc.querySelectorAll('dt')) {
              if (clean(dt.text) == name) return clean(dt.nextElementSibling?.text);
            }
            return null;
          }

          final comicId = doc.querySelector('[data-comic-id]')?.attributes['data-comic-id'] ??
              RegExp(r'comicId\\?"?:\s*(\d+)').firstMatch(body)?[1];
          final slug = Uri.parse(url).pathSegments.last;
          final chapters = <SourceChapter>[];
          if (comicId != null) {
            final json = await s.fetchJson(Uri.parse('${s.baseUrl}/api/comics/$comicId/chapters'), headers: {'Accept': 'application/json'});
            for (final c in ((json as Map)['chapters'] as List? ?? const []).cast<Map>()) {
              final n = '${c['slug']}'.replaceFirst('chapter-', '');
              final title = clean('${c['title'] ?? ''}');
              chapters.add(SourceChapter(
                url: '${s.baseUrl}/webtoon/$slug/chapter/$n',
                name: title.isEmpty || title == 'null' ? 'Chapter $n' : 'Chapter $n: $title',
                number: double.tryParse('${c['chapterNumber']}'),
                uploadedAt: DateTime.tryParse('${c['date'] ?? ''}'),
              ));
            }
          }
          final genres = <String>{
            if (fact('Type') != null) fact('Type')!,
            for (final g in (book?['genre'] as List? ?? const [])) '$g',
          };
          return SourceMangaDetails(
            url: url,
            title: clean(doc.querySelector('h1')?.text),
            thumbnailUrl: book?['image'] as String?,
            author: [for (final a in (book?['author'] as List? ?? const []).cast<Map>()) '${a['name']}'].join(', '),
            description: clean(doc.querySelector('p.whitespace-pre-line')?.text),
            genres: genres.toList(),
            status: _statusOf(fact('Status')),
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final page = await s.fetchText(Uri.parse(ch.url));
          final obj = findRscObject(nextFlightBody(page), (o) => o['images'] is List && o.containsKey('comicId'));
          final imgs = (obj?['images'] as List? ?? const []).cast<Map>().toList()
            ..sort((a, b) => ((a['sortOrder'] as num?) ?? 0).compareTo((b['sortOrder'] as num?) ?? 0));
          return [for (final i in imgs) '${s.baseUrl}/uploads/${i['filename']}'];
        },
      ),
      FnSource(
        id: 'en.toonhub',
        name: 'Toon Hub',
        baseUrl: 'https://toon-hub.com',
        contentWarning: ContentWarning.mixed,
        popularFn: (s, page) => _toonHubList(s, '/popular/', page),
        latestFn: (s, page) => _toonHubList(s, '/new/', page),
        searchFn: (s, page, q) async {
          final all = await _toonHubList(s, '/comics/', 1);
          final needle = q.toLowerCase();
          return MangaPage([for (final m in all.items) if (m.title.toLowerCase().contains(needle)) m], hasNextPage: false);
        },
        detailsFn: (s, url) async {
          final body = nextFlightBody(await s.fetchText(Uri.parse(url)));
          final c = findRscObject(body, (o) => o['episodes'] is List && o.containsKey('slug'));
          if (c == null) throw StateError('Komik tidak ditemukan');
          final slug = '${c['slug']}';
          final eps = (c['episodes'] as List).cast<Map>().where((e) => e['comingSoon'] != true).toList();
          final purchased = c['isComicPurchased'] == true;
          final chapters = <SourceChapter>[];
          for (final e in eps.reversed) {
            final locked = e['accessType'] != 'free' && e['isPurchased'] != true && !purchased;
            final epName = clean('${e['episodeName'] ?? ''}');
            final full = [clean('${e['title']}'), if (epName.isNotEmpty && epName != 'null') epName].join(': ');
            chapters.add(SourceChapter(
              url: '${s.baseUrl}/comics/$slug/${e['slug']}/',
              name: locked ? '🔒 $full' : full,
              number: (e['episodeNumber'] as num?)?.toDouble(),
              uploadedAt: DateTime.tryParse('${e['scheduledPublishAt'] ?? e['createdAt'] ?? ''}'),
            ));
          }
          return SourceMangaDetails(
            url: url,
            title: clean('${c['title']}'),
            thumbnailUrl: _toonHubThumb(c),
            description: c['description'] as String?,
            genres: [for (final g in (c['genres'] as List? ?? const []).cast<Map>()) '${g['name']}'],
            status: _statusOf(c['status'] as String?),
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final body = nextFlightBody(await s.fetchText(Uri.parse(ch.url)));
          final ep = findRscObject(body, (o) => o['panels'] is List);
          final panels = ((ep?['panels'] as List?) ?? const []).cast<Map>().toList()
            ..sort((a, b) => ((a['index'] as num?) ?? 0).compareTo((b['index'] as num?) ?? 0));
          return [for (final p in panels) '${p['url']}'];
        },
      ),
      _hentaiFc(),
    ];

Future<MangaPage> _wtcList(FnSource s, Map<String, String> params, int page) async {
  final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/webtoons').replace(queryParameters: {...params, if (page > 1) 'page': '$page'}));
  final items = <SourceManga>[];
  for (final a in res.document.querySelectorAll('a[href^="/webtoon/"]')) {
    final img = a.querySelector('img[data-cover]');
    final title = clean(a.querySelector('h3')?.text);
    if (img == null || title.isEmpty) continue;
    final srcset = img.attributes['srcset'] ?? img.attributes['srcSet'];
    final thumb = srcset?.split(', ').last.split(' ').first ?? img.attributes['src'];
    items.add(SourceManga(url: absUrl(res.url, a.attributes['href'])!, title: title, thumbnailUrl: absUrl(res.url, thumb)));
  }
  return MangaPage(items.toSet().toList(), hasNextPage: res.document.querySelector('a[aria-label="Go to next page"]') != null);
}

String? _toonHubThumb(Map c) {
  for (final i in (c['images'] as List? ?? const []).cast<Map>()) {
    if (i['kind'] == 'thumbnail' && i['size'] == 'original') return '${i['url']}';
  }
  return null;
}

Future<MangaPage> _toonHubList(FnSource s, String path, int page) async {
  if (page > 1) return const MangaPage([], hasNextPage: false);
  final body = nextFlightBody(await s.fetchText(Uri.parse('${s.baseUrl}$path')));
  final list = findRscObject(body, (o) => o['data'] is List && o.containsKey('totalPages'));
  return MangaPage([
    for (final c in (list?['data'] as List? ?? const []).cast<Map>())
      SourceManga(url: '${s.baseUrl}/comics/${c['slug']}/', title: clean('${c['title']}'), thumbnailUrl: _toonHubThumb(c)),
  ], hasNextPage: false);
}

FnSource _hentaiFc() {
  List<SourceManga> entries(Document doc, Uri base) {
    final out = <SourceManga>[];
    for (final el in doc.querySelectorAll('#book_list .wrap_item')) {
      final a = el.querySelector('h3.title a');
      final href = attrAbs(a, 'href', base);
      final title = clean(a?.text);
      if (href == null || title.isEmpty) continue;
      out.add(SourceManga(url: href, title: title, thumbnailUrl: nonPlaceholder(el.querySelector('.wrap_img img')?.attributes['src'])));
    }
    return out;
  }

  return FnSource(
    id: 'en.hentaifc',
    name: 'HentaiFC',
    baseUrl: 'https://hentaifc.com',
    contentWarning: ContentWarning.nsfw,
    popularFn: (s, page) async {
      final res = await s.fetchHtml(Uri.parse(page == 1 ? s.baseUrl : '${s.baseUrl}/page/$page'));
      return MangaPage(entries(res.document, res.url), hasNextPage: res.document.querySelector('a.next.page-numbers') != null);
    },
    searchFn: (s, page, q) async {
      if (page > 1) return const MangaPage([], hasNextPage: false);
      final res = await s.fetchHtml(Uri.parse(s.baseUrl).replace(queryParameters: {'search': q, 'search_by': 'title'}));
      return MangaPage(entries(res.document, res.url), hasNextPage: false);
    },
    detailsFn: (s, url) async {
      final res = await s.fetchHtml(Uri.parse(url));
      final doc = res.document;
      final galleryId = Uri.parse(url).pathSegments.last;
      final date = parseLooseDate(doc.querySelector('.d-cell.value.updateAt')?.text);
      final numbers = <String, double>{};
      for (final a in doc.querySelectorAll('.thumbs .wrap_item a[href]')) {
        final href = absUrl(res.url, a.attributes['href'])?.split('#').first.split('?').first;
        if (href == null) continue;
        final m = RegExp('/e/$galleryId/c(\\d+)').firstMatch(href);
        if (m == null) continue;
        numbers[href] = double.parse(m[1]!);
      }
      final chapters = [
        for (final e in numbers.entries)
          SourceChapter(url: e.key, name: 'Chapter ${e.value.toInt()}', number: e.value, uploadedAt: date),
      ]..sort((a, b) => b.number!.compareTo(a.number!));
      final thumb = doc.querySelector('.thumbs .wrap_item img');
      return SourceMangaDetails(
        url: url,
        title: clean(doc.querySelector('h1.heading')?.text),
        thumbnailUrl: nonPlaceholder(thumb?.attributes['data-src']) ?? nonPlaceholder(thumb?.attributes['src']),
        author: doc.querySelectorAll('.d-cell.value.authors a.author').map((e) => clean(e.text)).join(', '),
        genres: [for (final g in doc.querySelectorAll('.genres a[href*="/tag/"]')) clean(g.text)],
        status: SourceMangaStatus.completed,
        chapters: chapters,
      );
    },
    pagesFn: (s, ch) async {
      final n = ch.url.split('/c').last;
      // Halaman bab dirender JS; daftar gambar ada di grid thumbnail halaman galeri.
      final res = await s.fetchHtml(Uri.parse(ch.url.substring(0, ch.url.lastIndexOf('/c'))));
      final out = <String>[];
      for (final item in res.document.querySelectorAll('.thumbs .wrap_item')) {
        final href = attrAbs(item.querySelector('a[href]'), 'href', res.url)?.split('#').first.split('?').first;
        if (href == null || href.split('/c').last != n) continue;
        final img = item.querySelector('img');
        final src = nonPlaceholder(img?.attributes['data-src']) ?? nonPlaceholder(img?.attributes['src']);
        if (src != null) out.add(absUrl(res.url, src)!);
      }
      return out;
    },
  );
}

