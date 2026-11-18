// Situs katalog (bagian R: keluarga MangaFox/MangaHere/MangaTown/MangaHome),
// port Dart dari extension keiyoushi/extensions-source (Apache-2.0).

import 'package:html/dom.dart';

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import 'fn_source.dart';
import 'ports_util.dart';

const _adultCookie = {'Cookie': 'isAdult=1'};

/// Daftar kartu gaya `ul.manga-list-1-list li` (MangaFox/MangaHere).
MangaPage _foxCards(Document doc, Uri base, {String items = 'ul.manga-list-1-list li, ul.manga-list-4-list > li', String nextSel = ''}) {
  final out = <SourceManga>[];
  for (final li in doc.querySelectorAll(items)) {
    final a = li.querySelector('a[title], a');
    final href = attrAbs(a, 'href', base);
    final title = clean(a?.attributes['title'] ?? a?.text);
    if (href == null || title.isEmpty) continue;
    out.add(SourceManga(url: href, title: title, thumbnailUrl: attrAbs(li.querySelector('img'), 'src', base)));
  }
  final next = nextSel.isNotEmpty && doc.querySelector(nextSel) != null;
  return MangaPage(out, hasNextPage: next);
}

SourceMangaDetails _foxDetails(Document doc, Uri base, String url) {
  final info = doc.querySelector('.detail-info-right');
  final chapters = <SourceChapter>[];
  for (final li in doc.querySelectorAll('ul.detail-main-list > li')) {
    final a = li.querySelector('a');
    final href = attrAbs(a, 'href', base);
    if (href == null) continue;
    final name = clean(li.querySelector('a p.title3')?.text ?? li.querySelector('.detail-main-list-main p')?.text ?? a!.text);
    final date = li.querySelector('a p.title2')?.text ?? li.querySelectorAll('.detail-main-list-main p').lastOrNull?.text;
    chapters.add(SourceChapter(url: href, name: name, number: parseChapterNumber(name), uploadedAt: looseDate(date)));
  }
  return SourceMangaDetails(
    url: url,
    title: clean(doc.querySelector('.detail-info-right-title-font')?.text ?? doc.querySelector('h1')?.text),
    thumbnailUrl: attrAbs(doc.querySelector('img.detail-info-cover-img'), 'src', base),
    author: clean(info?.querySelectorAll('.detail-info-right-say a').map((e) => e.text).join(', ')),
    description: clean(doc.querySelector('p.fullcontent, .fullcontent')?.text),
    genres: [for (final g in info?.querySelectorAll('.detail-info-right-tag-list a') ?? <Element>[]) clean(g.text)],
    status: parseStatus(info?.querySelector('.detail-info-right-title-tip')?.text),
    chapters: chapters,
  );
}

List<MangaSource> portsR() => [
      FnSource(
        id: 'en.mangafox',
        name: 'MangaFox',
        baseUrl: 'https://fanfox.net',
        contentWarning: ContentWarning.mixed,
        popularFn: (s, page) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/directory/${page == 1 ? '' : '$page.html'}'), headers: _adultCookie);
          return _foxCards(res.document, res.url, nextSel: '.pager-list-left a.active + a + a');
        },
        latestFn: (s, page) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/directory/${page == 1 ? '' : '$page.html'}?latest'), headers: _adultCookie);
          return _foxCards(res.document, res.url, nextSel: '.pager-list-left a.active + a + a');
        },
        searchFn: (s, page, q) async {
          final res = await s.fetchHtml(
            Uri.parse('${s.baseUrl}/search').replace(queryParameters: {
              'title': q,
              'genres': '',
              'nogenres': '',
              'sort': '',
              'stype': '1',
              'page': '$page',
            }),
            headers: _adultCookie,
          );
          return _foxCards(res.document, res.url, nextSel: '.pager-list-left a.active + a + a');
        },
        detailsFn: (s, url) async {
          final res = await s.fetchHtml(Uri.parse(url), headers: _adultCookie);
          final doc = res.document;
          final d = _foxDetails(doc, res.url, url);
          return SourceMangaDetails(
            url: url,
            title: clean(doc.querySelector('.detail-info-right-title-font')?.text).isNotEmpty
                ? clean(doc.querySelector('.detail-info-right-title-font')?.text)
                : d.title,
            thumbnailUrl: d.thumbnailUrl,
            author: d.author,
            description: d.description,
            genres: d.genres,
            status: d.status,
            chapters: d.chapters,
          );
        },
        pagesFn: (s, ch) async {
          // Versi mobile menyajikan semua halaman sekaligus (cookie readway=2).
          final path = Uri.parse(ch.url).path.replaceFirst('/manga/', '/roll_manga/');
          final mobile = Uri.parse(s.baseUrl).replace(host: 'm.${Uri.parse(s.baseUrl).host}', path: path);
          final res = await s.fetchHtml(mobile, headers: {'Cookie': 'readway=2; isAdult=1', 'Referer': '${mobile.scheme}://${mobile.host}/'});
          return [
            for (final i in res.document.querySelectorAll('#viewer img'))
              if (attrAbs(i, 'data-original', res.url) case final u?) u,
          ];
        },
      ),
      FnSource(
        id: 'en.mangatown',
        name: 'Mangatown',
        baseUrl: 'https://www.mangatown.com',
        contentWarning: ContentWarning.mixed,
        popularFn: (s, page) async => _townList(await s.fetchHtml(Uri.parse('${s.baseUrl}/directory/0-0-0-0-0-0/$page.htm'))),
        latestFn: (s, page) async => _townList(await s.fetchHtml(Uri.parse('${s.baseUrl}/latest/$page.htm'))),
        searchFn: (s, page, q) async => _townList(await s.fetchHtml(
          Uri.parse('${s.baseUrl}/search').replace(queryParameters: {'page': '$page', 'name': q}),
        )),
        detailsFn: (s, url) async {
          final res = await s.fetchHtml(Uri.parse(url));
          final doc = res.document;
          final info = doc.querySelector('div.article_content');
          String? field(String label) {
            for (final li in info?.querySelectorAll('li') ?? <Element>[]) {
              if (clean(li.querySelector('b')?.text).toLowerCase().startsWith(label)) {
                return li.querySelectorAll('a').map((e) => clean(e.text)).where((e) => e.isNotEmpty).join(', ');
              }
            }
            return null;
          }

          String? statusText;
          for (final li in info?.querySelectorAll('li') ?? <Element>[]) {
            if (clean(li.querySelector('b')?.text).toLowerCase().startsWith('status')) statusText = li.text;
          }
          final chapters = <SourceChapter>[];
          for (final li in doc.querySelectorAll('ul.chapter_list li')) {
            final a = li.querySelector('a');
            final href = attrAbs(a, 'href', res.url);
            if (href == null) continue;
            final extra = li.querySelectorAll('span').where((e) => !e.classes.contains('time') && !e.classes.contains('new')).map((e) => clean(e.text)).where((e) => e.isNotEmpty).join(' ');
            final name = clean('${a!.text} $extra');
            chapters.add(SourceChapter(
              url: href,
              name: name,
              number: parseChapterNumber(name),
              uploadedAt: looseDate(li.querySelector('span.time')?.text),
            ));
          }
          return SourceMangaDetails(
            url: url,
            title: clean(info?.querySelector('h1')?.text),
            thumbnailUrl: attrAbs(doc.querySelector('div.detail_info img'), 'src', res.url),
            author: field('author'),
            artist: field('artist'),
            description: clean(doc.querySelector('span#show')?.text).replaceFirst(RegExp(r'HIDE$'), '').trim(),
            genres: (field('genre') ?? '').split(', ').where((e) => e.isNotEmpty).toList(),
            status: parseStatus(statusText),
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse(ch.url));
          final opts = res.document.querySelectorAll('select#top_chapter_list ~ div.page_select option').where((o) => !o.text.contains('featured')).toList();
          if (opts.isEmpty) {
            return [
              for (final i in res.document.querySelectorAll('div#viewer img'))
                if (attrAbs(i, 'src', res.url) case final u?) u,
            ];
          }
          final urls = [for (final o in opts) if (absUrl(res.url, o.attributes['value']) case final u?) u];
          final imgs = await pooled<String?>([
            for (final u in urls)
              () async {
                final p = await s.fetchHtml(Uri.parse(u), headers: {'Referer': ch.url});
                return attrAbs(p.document.querySelector('div#viewer img'), 'src', p.url);
              },
          ]);
          return imgs.whereType<String>().toList();
        },
      ),
      FnSource(
        id: 'en.mangahome',
        name: 'MangaHome',
        baseUrl: 'https://www.mangahome.com',
        contentWarning: ContentWarning.mixed,
        popularFn: (s, page) async => _homeList(await s.fetchHtml(Uri.parse('${s.baseUrl}/directory/$page.htm'))),
        latestFn: (s, page) async => _homeList(await s.fetchHtml(Uri.parse('${s.baseUrl}/latest/$page.html'))),
        searchFn: (s, page, q) async => _homeList(await s.fetchHtml(
          Uri.parse('${s.baseUrl}/search').replace(queryParameters: {'page': '$page', 'name_method': 'cw', 'name': q, 'advopts': '1'}),
        )),
        detailsFn: (s, url) async {
          final res = await s.fetchHtml(Uri.parse(url));
          final doc = res.document;
          final detail = doc.querySelector('.manga-detail');
          final info = detail?.querySelector('.detail-info');
          final middle = detail?.querySelector('.manga-detailmiddle');
          String? field(Element? root, String label) {
            for (final p in root?.querySelectorAll('p') ?? <Element>[]) {
              if (clean(p.querySelector('span')?.text).toLowerCase().startsWith(label)) {
                final links = p.querySelectorAll('a').map((e) => clean(e.text)).where((e) => e.isNotEmpty).toList();
                return links.isEmpty ? clean(ownText(p)) : links.join(', ');
              }
            }
            return null;
          }

          final chapters = <SourceChapter>[];
          for (final li in doc.querySelectorAll('ul.detail-chlist > li')) {
            final a = li.querySelector('a');
            final href = attrAbs(a, 'href', res.url);
            if (href == null) continue;
            final num = clean(li.querySelector('span.pc-none')?.text);
            final vol = clean(li.querySelector('span.vol') == null ? '' : ownText(li.querySelector('span.vol')!));
            final name = [if (num.isNotEmpty && num != 'Ch') num, if (vol.isNotEmpty) vol].join(' - ');
            final time = clean(li.querySelector('span.time')?.text);
            chapters.add(SourceChapter(
              url: href,
              name: name.isEmpty ? 'Ch 0' : name,
              number: parseChapterNumber(name),
              uploadedAt: looseDate(time.contains('day ') ? time.substring(time.indexOf('day ') + 4) : time),
            ));
          }
          final desc = middle?.querySelector('p.hide.mobile-none');
          return SourceMangaDetails(
            url: url,
            title: clean(detail?.querySelector('h1')?.text),
            thumbnailUrl: attrAbs(detail?.querySelector('img.detail-cover'), 'src', res.url),
            author: field(info, 'author'),
            artist: field(info, 'artist'),
            description: desc == null ? null : clean(desc.text),
            genres: (field(middle, 'genre') ?? '').split(', ').where((e) => e.isNotEmpty).toList(),
            status: parseStatus(field(info, 'status')),
            chapters: chapters,
          );
        },
        pagesFn: (s, ch) async {
          final res = await s.fetchText(Uri.parse(ch.url));
          final id = RegExp(r'var chapter_id\s*=\s*(\d+)').firstMatch(res)?[1];
          final count = int.tryParse(RegExp(r'var imagecount\s*=\s*(\d+)').firstMatch(res)?[1] ?? '');
          if (id == null || count == null) return const [];
          final urls = await pooled<String?>([
            for (var i = 1; i <= count; i++)
              () async {
                final base = ch.url.endsWith('/') ? ch.url : '${ch.url}/';
                final text = await s.fetchText(
                  Uri.parse('${base}chapterfun.ashx').replace(queryParameters: {'cid': id, 'page': '$i', 'key': ''}),
                  headers: {'Referer': ch.url, 'X-Requested-With': 'XMLHttpRequest'},
                );
                return _packedImage(text);
              },
          ]);
          return urls.whereType<String>().toList();
        },
      ),
      FnSource(
        id: 'en.mangahere',
        name: 'Mangahere',
        baseUrl: 'https://www.mangahere.cc',
        contentWarning: ContentWarning.mixed,
        popularFn: (s, page) async => _foxCards(
            (await s.fetchHtml(Uri.parse('${s.baseUrl}/directory/$page.htm'), headers: _adultCookie)).document, s.baseUri,
            nextSel: 'div.pager-list-left a:last-child:not(.active)'),
        latestFn: (s, page) async => _foxCards(
            (await s.fetchHtml(Uri.parse('${s.baseUrl}/directory/$page.htm?latest'), headers: _adultCookie)).document, s.baseUri,
            nextSel: 'div.pager-list-left a:last-child:not(.active)'),
        searchFn: (s, page, q) async => _foxCards(
            (await s.fetchHtml(
              Uri.parse('${s.baseUrl}/search').replace(queryParameters: {'page': '$page', 'title': q, 'sort': '', 'stype': '1', 'name': ''}),
              headers: _adultCookie,
            ))
                .document,
            s.baseUri,
            nextSel: 'div.pager-list-left a:last-child:not(.active)'),
        detailsFn: (s, url) async {
          final res = await s.fetchHtml(Uri.parse(url), headers: _adultCookie);
          return _foxDetails(res.document, res.url, url);
        },
        pagesFn: (s, ch) async {
          final html = await s.fetchText(Uri.parse(ch.url), headers: _adultCookie);
          // Mode webtoon: seluruh gambar ada di skrip terbungkus.
          if (html.contains('chapter_bar')) {
            for (final m in RegExp(r'eval\(function\(p,a,c,k,e,d\).*?</script>', dotAll: true).allMatches(html)) {
              final un = unpackPacker(m[0]!);
              if (un != null && un.contains('newImgs')) {
                final list = un.split("newImgs=['").last.split("'];").first.split("','");
                return [for (final u in list) 'https:$u'];
              }
            }
          }
          final keyStart = html.indexOf('eval(function(p,a,c,k,e,d)');
          var key = '';
          if (keyStart >= 0) {
            final un = unpackPacker(html.substring(keyStart, html.indexOf('</script>', keyStart)));
            if (un != null) {
              final expr = un.substring(un.indexOf("'"), un.indexOf(';'));
              key = RegExp(r"'([^']*)'").allMatches(expr).map((e) => e[1]).join();
            }
          }
          final cidAt = html.indexOf('chapterid');
          final cid = html.substring(cidAt + 11, html.indexOf(';', cidAt)).trim();
          final nums = RegExp(r'data-page="(\d+)"').allMatches(html).map((e) => int.parse(e[1]!)).toList();
          final total = nums.isEmpty ? 0 : nums.reduce((a, b) => a > b ? a : b);
          final base = ch.url.substring(0, ch.url.lastIndexOf('/'));
          final urls = await pooled<String?>([
            for (var i = 1; i <= total; i++)
              () async {
                for (final k in [key, '']) {
                  final text = await s.fetchText(
                    Uri.parse('$base/chapterfun.ashx').replace(queryParameters: {'cid': cid, 'page': '$i', 'key': k}),
                    headers: {'Referer': ch.url, 'X-Requested-With': 'XMLHttpRequest', ..._adultCookie},
                  );
                  if (text.trim().isNotEmpty) return _packedImage(text);
                }
                return null;
              },
          ], size: 4);
          return urls.whereType<String>().toList();
        },
      ),
    ];

String? _packedImage(String text) {
  final un = unpackPacker(text);
  if (un == null) return null;
  final host = RegExp(r'pix="([^"]+)"').firstMatch(un)?[1];
  final path = RegExp(r'pvalue=\["([^"]+)"').firstMatch(un)?[1];
  if (host == null || path == null) return null;
  return 'https:$host$path';
}

MangaPage _townList(HtmlResponse res) {
  final out = <SourceManga>[];
  for (final li in res.document.querySelectorAll('li')) {
    final cover = li.querySelector('a.manga_cover');
    final a = li.querySelector('p.title a');
    final href = attrAbs(a, 'href', res.url);
    if (cover == null || href == null) continue;
    out.add(SourceManga(url: href, title: clean(a!.text), thumbnailUrl: attrAbs(li.querySelector('img'), 'src', res.url)));
  }
  final next = res.document
      .querySelectorAll('div.next-page a.next, .page-nav a')
      .any((a) => (a.attributes['href'] ?? '').isNotEmpty && !(a.attributes['href'] ?? '').startsWith('javascript') && (a.classes.contains('next') || a.text.toLowerCase().contains('next')));
  return MangaPage(out, hasNextPage: next);
}

MangaPage _homeList(HtmlResponse res) {
  final out = <SourceManga>[];
  for (final post in res.document.querySelectorAll('ul.manga-list .post')) {
    final a = post.querySelector('p.title a');
    final href = attrAbs(a, 'href', res.url);
    if (href == null) continue;
    var title = clean(a!.text);
    if (title.endsWith('...')) title = clean(a.attributes['title']);
    out.add(SourceManga(url: href, title: title, thumbnailUrl: attrAbs(post.querySelector('img'), 'src', res.url)));
  }
  return MangaPage(out, hasNextPage: res.document.querySelector('.page-nav a.next') != null);
}
