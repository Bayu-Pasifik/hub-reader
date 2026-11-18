// Situs katalog (bagian W: Tapas), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0).

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import 'fn_source.dart';

const _tapasHeaders = {
  'Referer': 'https://m.tapas.io',
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:105.0) Gecko/20100101 Firefox/105.0',
  'Cookie': 'birthDate=1990-01-01; adjustedBirthDate=1990-01-01',
};
const _tapasApi = 'https://story-api.tapas.io';

MangaPage _tapasItems(Object? json) {
  final m = json as Map;
  final items = ((m['data'] as Map)['items'] as List).cast<Map>();
  final meta = (m['meta'] as Map?)?['pagination'] as Map?;
  return MangaPage([
    for (final i in items)
      SourceManga(
        url: 'https://tapas.io/series/${i['seriesId']}',
        title: clean('${i['title']}'),
        thumbnailUrl: switch (((i['assetProperty'] as Map?)?['bookCoverImage'] as Map?)?.values.firstOrNull) {
          final u? => '$u.png',
          _ => null,
        },
      ),
  ], hasNextPage: !((meta?['last'] as bool?) ?? true));
}

FnSource _tapas() => FnSource(
      id: 'en.tapas',
      name: 'Tapas',
      baseUrl: 'https://tapas.io',
      contentWarning: ContentWarning.mixed,
      popularFn: (s, page) async => _tapasItems(await s.fetchJson(
          Uri.parse('$_tapasApi/cosmos/api/v1/landing/ranking').replace(queryParameters: {
            'category_type': 'COMIC',
            'subtab_id': '17',
            'size': '25',
            'page': '${page - 1}',
          }),
          headers: _tapasHeaders)),
      latestFn: (s, page) async => _tapasItems(await s.fetchJson(
          Uri.parse('$_tapasApi/cosmos/api/v1/landing/genre').replace(queryParameters: {
            'category_type': 'COMIC',
            'sort_option': 'NEWEST_EPISODE',
            'subtab_id': '17',
            'pageSize': '25',
            'page': '${page - 1}',
          }),
          headers: _tapasHeaders)),
      searchFn: (s, page, q) async {
        final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/search').replace(queryParameters: {'pageNumber': '$page', 'q': q, 't': 'COMICS'}),
            headers: _tapasHeaders);
        final out = <SourceManga>[];
        for (final el in res.document.querySelectorAll('.search-item-wrap')) {
          final id = el.querySelector('.item__thumb a, .title-section .title a')?.attributes['data-series-id'];
          if (id == null) continue;
          out.add(SourceManga(
            url: 'https://tapas.io/series/$id',
            title: clean(el.querySelector('.item__thumb img')?.attributes['alt'] ?? el.querySelector('.title-section .title a')?.text),
            thumbnailUrl: el.querySelector('.item__thumb img, .thumb-wrap img')?.attributes['src'],
          ));
        }
        return MangaPage(out, hasNextPage: res.document.querySelector('a[class*=paging__button--next]') != null);
      },
      detailsFn: (s, url) async {
        final res = await s.fetchHtml(Uri.parse('$url/info'), headers: _tapasHeaders);
        final doc = res.document;
        String? typeText;
        for (final a in doc.querySelectorAll('.stats > a')) {
          if ((a.attributes['href'] ?? '').startsWith('/static-landing/genre?category=')) typeText = clean(a.text);
        }
        String schedule = '';
        for (final l in doc.querySelectorAll('.schedule-label')) {
          final ico = l.previousElementSibling;
          if (ico != null && ico.querySelector('.sp-ico-updated-line-pwt') != null) schedule = clean(l.text).toLowerCase();
        }
        final chapters = <SourceChapter>[];
        var page = 1;
        while (true) {
          final j = await s.fetchJson(
              Uri.parse('$url/episodes').replace(queryParameters: {
                'page': '${page++}',
                'sort': 'NEWEST',
                'since': '${DateTime.now().millisecondsSinceEpoch}',
                'large': 'true',
                'last_access': '0',
              }),
              headers: {..._tapasHeaders, 'Accept': 'application/json'}) as Map;
          final data = j['data'] as Map;
          for (final e in (data['episodes'] as List).cast<Map>()) {
            final open = e['unlocked'] == true || e['free'] == true;
            chapters.add(SourceChapter(
              url: 'https://tapas.io/episode/${e['id']}',
              name: open ? '${e['title']}' : '🔒 ${e['title']}',
              number: (e['scene'] as num?)?.toDouble(),
              uploadedAt: DateTime.tryParse('${e['publish_date'] ?? ''}'),
            ));
          }
          if ((data['pagination'] as Map?)?['has_next'] != true) break;
        }
        return SourceMangaDetails(
          url: url,
          title: clean(doc.querySelector('.info__right .title')?.text),
          thumbnailUrl: attrAbs(doc.querySelector('.thumb.js-thumbnail img'), 'src', res.url),
          author: doc.querySelectorAll('.creator-section .name').map((e) => clean(e.text)).join(', '),
          description: [
            clean(doc.querySelector('.description__body')?.text),
            if (typeText != null) 'Type: $typeText',
          ].where((e) => e.isNotEmpty).join('\n\n'),
          genres: doc.querySelectorAll('.genre-btn').map((e) => clean(e.text)).toSet().toList(),
          status: schedule.contains('updates')
              ? SourceMangaStatus.ongoing
              : schedule.contains('completed')
                  ? SourceMangaStatus.completed
                  : SourceMangaStatus.unknown,
          chapters: chapters,
        );
      },
      pagesFn: (s, ch) async {
        final res = await s.fetchHtml(Uri.parse(ch.url), headers: _tapasHeaders);
        if (res.document.querySelectorAll('.toolbar a').any((a) => a.attributes['data-type'] == 'style')) {
          throw StateError('Ini bab novel, bukan komik.');
        }
        final out = [
          for (final img in res.document.querySelectorAll('img.content__img'))
            if (attrAbs(img, img.attributes.containsKey('data-src') ? 'data-src' : 'src', res.url) case final u?) u,
        ];
        if (out.isEmpty) throw StateError('Bab terkunci.');
        return out;
      },
    );

List<MangaSource> portsW() => [_tapas()];
