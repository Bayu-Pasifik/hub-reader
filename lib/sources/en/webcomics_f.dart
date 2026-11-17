// Situs katalog dinamis kecil, port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0): honkaiimpact, mlbblore, toongrab,
// vgperson.

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import 'fn_source.dart';

SourceMangaStatus _status(String? raw) => parseStatus(raw);

List<MangaSource> webcomicsF() => [
      // HonkaiImpact3
      FnSource(
        id: 'en.honkaiimpact',
        name: 'HonkaiImpact3',
        baseUrl: 'https://manga.honkaiimpact3.com',
        popularFn: (s, page) async {
          if (page > 1) return const MangaPage([], hasNextPage: false);
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/book'));
          final seen = <String>{};
          final items = <SourceManga>[];
          for (final a in res.document.querySelectorAll('a[href*=book]')) {
            final href = attrAbs(a, 'href', res.url);
            final title = clean(a.querySelector('.container-title')?.text);
            if (href == null || title.isEmpty || !seen.add(href)) continue;
            items.add(SourceManga(
              url: href,
              title: title,
              thumbnailUrl: attrAbs(a.querySelector('.container-cover img'), 'src', res.url),
            ));
          }
          return MangaPage(items, hasNextPage: false);
        },
        searchFn: (s, page, q) async {
          final all = await s.popular(page);
          return MangaPage([
            for (final m in all.items)
              if (m.title.toLowerCase().contains(q.toLowerCase())) m,
          ], hasNextPage: false);
        },
        detailsFn: (s, url) async {
          final res = await s.fetchHtml(Uri.parse(url));
          final list = await s.fetchJson(Uri.parse('$url/get_chapter')) as List;
          final out = <SourceChapter>[];
          for (final c in list) {
            final m = c as Map;
            final cn = double.tryParse('${m['chapterid']}') ?? 0;
            final id = cn.toInt();
            out.add(SourceChapter(
              url: '${s.baseUrl}/book/${m['bookid']}/$id',
              name: '${m['title']}',
              number: cn,
              uploadedAt: DateTime.tryParse('${m['timestamp']}'.replaceFirst(' ', 'T')),
            ));
          }
          out.sort((a, b) => (b.number ?? 0).compareTo(a.number ?? 0));
          return SourceMangaDetails(
            url: url,
            title: clean(res.document.querySelector('div.title')?.text),
            thumbnailUrl: attrAbs(res.document.querySelector('img.cover'), 'src', res.url),
            chapters: out,
          );
        },
        pagesFn: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse(ch.url));
          return [
            for (final img in res.document.querySelectorAll('img.lazy.comic_img'))
              if (absUrl(res.url, img.attributes['data-original']) case final u?) u,
          ];
        },
      ),
      // MLBB Lore
      FnSource(
        id: 'en.mlbblore',
        name: 'MLBB Lore',
        baseUrl: 'https://play.mobilelegends.com',
        popularFn: (s, page) async {
          final json = await s.postFormJson(Uri.parse('https://api.mobilelegends.com/lore/album/list'), {
            'type': '3',
            'sort': '3',
            'page': '$page',
            'page_size': '5',
            'lang': 'en',
            'token': '',
          }) as Map;
          final data = (json['data'] as List?) ?? const [];
          return MangaPage([
            for (final e in data)
              if ((e as Map)['type'] == 3)
                SourceManga(
                  url: '${e['id']}',
                  title: '${e['title']}',
                  thumbnailUrl: _abs('${e['thumb']}'),
                ),
          ], hasNextPage: data.length >= 5);
        },
        searchFn: (s, page, q) async => const MangaPage([], hasNextPage: false),
        detailsFn: (s, url) async {
          final d = await _mlbbDetail(s, url);
          return SourceMangaDetails(
            url: url,
            title: '${d['title']}',
            thumbnailUrl: _abs('${d['thumb']}'),
            author: '${d['hero_name'] ?? ''}'.trim(),
            chapters: [SourceChapter(url: url, name: 'Chapter 1', number: 1)],
          );
        },
        pagesFn: (s, ch) async {
          final d = await _mlbbDetail(s, ch.url);
          return [for (final r in (d['comic_content'] as List? ?? const [])) _abs('$r')];
        },
      ),
      // ToonGrab
      FnSource(
        id: 'en.toongrab',
        name: 'ToonGrab',
        baseUrl: 'https://toongrab.com',
        popularFn: (s, page) => _toonBrowse(s, {'page': '$page', 'sort': 'Most Popular'}),
        searchFn: (s, page, q) => _toonBrowse(s, {'page': '$page', 'search': q}),
        detailsFn: (s, url) async {
          final slug = url;
          final d = await s.fetchJson(Uri.parse('${s.baseUrl}/api/manga/$slug')) as Map;
          final chapters = <SourceChapter>[];
          var total = 1;
          for (var p = 1; p <= total && p <= 60; p++) {
            final r = await s.fetchJson(Uri.parse('${s.baseUrl}/api/manga/$slug/chapters?limit=100&page=$p')) as Map;
            total = (r['totalPages'] as num?)?.toInt() ?? 1;
            for (final c in (r['chapters'] as List)) {
              final m = c as Map;
              final n = (m['chapterNumber'] as num).toDouble();
              final ns = n.toString().replaceFirst(RegExp(r'\.0$'), '');
              final title = m['title'] as String?;
              chapters.add(SourceChapter(
                url: '/manga/$slug/chapter-$ns',
                name: 'Chapter $ns${title == null || title.isEmpty ? '' : ' - $title'}',
                number: n,
                uploadedAt: DateTime.tryParse('${m['createdAt'] ?? ''}'),
              ));
            }
          }
          chapters.sort((a, b) => (b.number ?? 0).compareTo(a.number ?? 0));
          return SourceMangaDetails(
            url: slug,
            title: '${d['title']}',
            thumbnailUrl: d['coverUrl'] as String?,
            author: d['author'] as String?,
            artist: d['artist'] as String?,
            description: d['description'] as String?,
            genres: [for (final g in (d['genres'] as List? ?? const [])) '$g', if (d['type'] != null) '${d['type']}'],
            status: _status(d['status'] as String?),
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final seg = ch.url.replaceFirst(RegExp(r'^/'), '').split('/');
          final r = await s.fetchJson(
                  Uri.parse('${s.baseUrl}/api/manga/${seg[1]}/chapter/${seg[2].replaceFirst('chapter-', '')}'))
              as Map;
          return [for (final i in (r['images'] as List)) '$i'];
        },
      ),
      // vgperson
      FnSource(
        id: 'en.vgperson',
        name: 'vgperson',
        baseUrl: 'https://vgperson.com',
        popularFn: (s, page) async {
          if (page > 1) return const MangaPage([], hasNextPage: false);
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/other/mangaviewer.php'));
          return MangaPage([
            for (final a in res.document.querySelectorAll('.content a'))
              if ((a.attributes['href'] ?? '').startsWith('?m'))
                SourceManga(url: a.attributes['href']!, title: clean(a.text)),
          ], hasNextPage: false);
        },
        searchFn: (s, page, q) async {
          final all = await s.popular(1);
          return MangaPage([
            for (final m in all.items)
              if (m.title.toLowerCase().contains(q.toLowerCase())) m,
          ], hasNextPage: false);
        },
        detailsFn: (s, url) async {
          final home = '${s.baseUrl}/other/mangaviewer.php';
          final res = await s.fetchHtml(Uri.parse('$home$url'));
          final chapters = <SourceChapter>[];
          for (final tr in res.document.querySelectorAll('.chaptertable tr')) {
            final a = tr.querySelector('td > a');
            final href = a?.attributes['href'];
            if (a == null || href == null) continue;
            var name = clean(a.text);
            final last = tr.querySelector('td:last-child');
            if (last != null && last != tr.querySelector('td')) {
              final t = clean(last.text);
              if (t.contains('- ')) name += ' - ${t.substring(t.indexOf('- ') + 2)}';
            }
            final q = Uri.parse('$home$href').queryParameters;
            chapters.add(SourceChapter(
              url: '$home$href',
              name: name,
              number: double.tryParse(q['c'] ?? '') ?? (16.5 + (double.tryParse(q['b'] ?? '') ?? 0) / 10),
              scanlator: 'vgperson',
            ));
          }
          return SourceMangaDetails(
            url: url,
            title: clean(res.document.querySelector('.title')?.text),
            chapters: chapters.reversed.toList(),
          );
        },
        pagesFn: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse(ch.url));
          return [
            for (final img in res.document.querySelectorAll('img'))
              if (attrAbs(img, 'src', res.url) case final u?) u,
          ];
        },
      ),
    ];

String _abs(String u) => u.startsWith('//') ? 'https:$u' : u;

Future<Map> _mlbbDetail(FnSource s, String id) async {
  final json = await s.postFormJson(
    Uri.parse('https://api.mobilelegends.com/lore/album/detail'),
    {'id': id, 'lang': 'en', 'token': ''},
  ) as Map;
  return (json['data'] as Map?) ?? const {};
}

Future<MangaPage> _toonBrowse(FnSource s, Map<String, String> params) async {
  final r = await s.fetchJson(Uri.parse('${s.baseUrl}/api/manga/browse').replace(queryParameters: params)) as Map;
  final page = int.tryParse(params['page'] ?? '1') ?? 1;
  return MangaPage([
    for (final m in (r['data'] as List))
      SourceManga(url: '${(m as Map)['slug']}', title: '${m['title']}', thumbnailUrl: m['coverUrl'] as String?),
  ], hasNextPage: page < ((r['totalPages'] as num?)?.toInt() ?? 1));
}
