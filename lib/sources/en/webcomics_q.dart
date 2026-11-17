// Situs katalog (bagian Q), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0): lolobun.

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import 'fn_source.dart';

const _loloCover = 'https://osrs.sfacg.com/web/comic/images/Logo';

Future<MangaPage> _loloHome(HttpSource s) async {
  final res = await s.fetchHtml(Uri.parse(s.baseUrl));
  final seen = <String>{};
  final out = <SourceManga>[];
  for (final el in res.document.querySelectorAll('.section-item')) {
    final a = el.querySelector('a.name[href^="/c/"]');
    if (a == null) continue;
    final id = a.attributes['href']!.split('/').last;
    if (!seen.add(id)) continue;
    out.add(SourceManga(url: id, title: clean(a.text), thumbnailUrl: attrAbs(el.querySelector('img.cover'), 'src', s.baseUri)));
  }
  return MangaPage(out, hasNextPage: false);
}

Object? _loloData(Object? json) {
  final m = json as Map;
  final data = m['data'];
  if (data == null) {
    final st = m['status'] as Map?;
    throw Exception('${st?['msg'] ?? 'Request failed with code ${st?['errorCode']}'}');
  }
  return data;
}

List<MangaSource> webcomicsQ() => [
      FnSource(
        id: 'en.lolobun',
        name: 'LoLoBun',
        baseUrl: 'https://www.lolobun.com',
        popularFn: (s, page) => _loloHome(s),
        searchFn: (s, page, q) async {
          final d = _loloData(await s.fetchJson(Uri.parse('${s.baseUrl}/ajax/Common.ashx').replace(queryParameters: {
            'op': 'searchWorks',
            'q': q,
            'type': 'comic',
            'pi': '${page - 1}',
          }))) as Map;
          return MangaPage([
            for (final i in (d['Items'] as List).cast<Map>())
              SourceManga(
                url: '${i['EntityId']}',
                title: '${i['Title']}',
                thumbnailUrl: i['Cover'] == null
                    ? null
                    : '${i['Cover']}'.startsWith('http')
                        ? '${i['Cover']}'
                        : '$_loloCover/${i['Cover']}',
              ),
          ], hasNextPage: d['HasMore'] == true);
        },
        detailsFn: (s, id) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/c/$id'));
          final doc = res.document;
          final info = clean(doc.querySelector('.header-item-info .info')?.text).split('·').map((e) => e.trim()).toList();
          final st = info.first.toLowerCase();
          final items = doc.querySelectorAll('.catalog-list .catalog-item');
          final latest = parseLooseDate(doc.querySelector('.lastest-update-time')?.text);
          var prev = 0.0;
          var extras = 0;
          final chapters = <SourceChapter>[];
          for (var i = 0; i < items.length; i++) {
            final a = items[i].querySelector('.title a');
            if (a == null) continue;
            final title = clean(a.text);
            final m = RegExp(r'^chapter\s*(\d+(?:\.\d+)?)$', caseSensitive: false).firstMatch(title);
            double n;
            if (m != null) {
              n = double.parse(m[1]!);
              prev = n;
              extras = 0;
            } else {
              extras++;
              n = prev + extras / 100;
            }
            final locked = items[i].querySelector('.icon-box img[src*="lock"]') != null;
            chapters.add(SourceChapter(
              url: a.attributes['href']!.split('/c/').last,
              name: locked ? '🔒 $title' : title,
              number: n,
              uploadedAt: i == items.length - 1 ? latest : null,
            ));
          }
          return SourceMangaDetails(
            url: id,
            title: clean(doc.querySelector('.header-item-info .name')?.text),
            thumbnailUrl: attrAbs(doc.querySelector('img.header-item-cover'), 'src', s.baseUri),
            description: doc.querySelector('#comic-desc')?.text.trim(),
            genres: info.skip(1).where((e) => e.isNotEmpty).toList(),
            status: parseStatus(st),
            chapters: chapters.reversed.toList(),
          );
        },
        pagesFn: (s, ch) async {
          final r = await s.postFormJson(
            Uri.parse('${s.baseUrl}/ajax/comic.ashx?op=getChapterPic'),
            {'chapId': ch.url.split('/').last},
          );
          return [for (final u in (_loloData(r) as List)) '$u'];
        },
      ),
    ];
