// Sumber dewasa dinamis (bagian fn), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0): src/en/*.

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
    ];
