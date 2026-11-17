// Webcomic dewasa satu-seri, port Dart dari extension keiyoushi/extensions-source
// (Apache-2.0): src/en/{vixenlogic,oglaf,irovedout,mahouirexnohentaikarte}.

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import 'single_series.dart';

List<SourceChapter> _numbered(List<SourceChapter> newestFirst) => newestFirst;

List<MangaSource> adultWebcomics() => [
      SingleSeriesSource(
        id: 'en.vixenlogic',
        name: 'Vixen Logic',
        baseUrl: 'https://www.vixenlogic.com',
        seriesTitle: 'Vixen Logic',
        author: 'tootaloo and foxboy83',
        cover: 'https://www.vixenlogic.com/wp-content/uploads/2026/06/VL_Cover_Toocheke.png',
        loadChapters: (s) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/archives/'));
          final out = <SourceChapter>[];
          for (final item in res.document.querySelectorAll('.comic-item')) {
            final href = attrAbs(item.parent, 'href', res.url);
            if (href == null) continue;
            out.add(SourceChapter(
              url: href,
              name: clean(item.querySelector('.comic-title')?.text),
              uploadedAt: parseLooseDate(clean(item.querySelector('.comic-post-date')?.text)),
            ));
          }
          return _numbered(out);
        },
        loadPages: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse(ch.url));
          return [
            for (final img in res.document.querySelectorAll('#comic p a img'))
              if (imgAttr(img, res.url) case final u?) u,
          ];
        },
      ),
      SingleSeriesSource(
        id: 'en.oglaf',
        name: 'Oglaf',
        baseUrl: 'https://www.oglaf.com',
        seriesTitle: 'Oglaf',
        author: 'Trudy Cooper & Doug Bayne',
        description: 'Filth and other Fantastical Things in handy webcomic form.',
        cover: 'https://i.ibb.co/tzY0VQ9/oglaf.png',
        loadChapters: (s) async {
          final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/archive/'));
          final seen = <String>{};
          final out = <SourceChapter>[];
          for (final a in res.document.querySelectorAll('a')) {
            if (a.querySelector('img[width="400"]') == null) continue;
            final href = a.attributes['href'] ?? '';
            final m = RegExp(r'^/([^/]+)/').firstMatch(href);
            if (m == null || !seen.add(href)) continue;
            out.add(SourceChapter(url: '${s.baseUrl}$href', name: m[1]!));
          }
          return out;
        },
        loadPages: (s, ch) async {
          final pages = <String>[];
          var url = Uri.parse(ch.url);
          for (var i = 0; i < 60; i++) {
            final res = await s.fetchHtml(url);
            final img = attrAbs(res.document.querySelector('img#strip'), 'src', res.url);
            if (img == null) break;
            pages.add(img);
            final next = res.document.querySelector('a[rel=next]')?.attributes['href'];
            if (next == null || !RegExp(r'^/.*/\d*/$').hasMatch(next)) break;
            url = res.url.resolve(next);
          }
          return pages;
        },
      ),
      SingleSeriesSource(
        id: 'en.irovedout',
        name: 'I Roved Out',
        baseUrl: 'https://www.irovedout.com',
        seriesTitle: 'I Roved Out in Search of Truth and Love',
        author: 'Alexis Flower',
        genres: const ['Fantasy'],
        cover: 'https://i.ibb.co/2g7Htwq/irovedout.png',
        description: 'I ROVED OUT IN SEARCH OF TRUTH AND LOVE is written & illustrated by Alexis Flower. '
            'It updates in chunks anywhere between 3 and 30 pages long at least once a month.',
        loadChapters: (s) async {
          final main = await s.fetchHtml(Uri.parse(s.baseUrl));
          final books = [
            for (final a in main.document.querySelectorAll('#menu-menu > li > a'))
              if ((a.attributes['href'] ?? '').startsWith('${s.baseUrl}/archive')) a.attributes['href']!,
          ];
          final out = <SourceChapter>[];
          for (var i = 0; i < books.length; i++) {
            final page = await s.fetchHtml(Uri.parse(books[i]));
            for (final wrap in page.document.querySelectorAll('.comic-archive-chapter-wrap')) {
              final title = clean(wrap.querySelector('.comic-archive-chapter')?.text);
              final href = wrap.querySelector('.comic-archive-title > a')?.attributes['href'];
              if (href == null) continue;
              out.add(SourceChapter(
                url: '${books[i]}#${Uri.encodeComponent(title)}',
                name: 'Book ${i + 1}: $title',
                number: out.length + 1.0,
              ));
            }
          }
          return out.reversed.toList();
        },
        loadPages: (s, ch) async {
          final hash = ch.url.indexOf('#');
          final title = Uri.decodeComponent(ch.url.substring(hash + 1));
          final res = await s.fetchHtml(Uri.parse(ch.url.substring(0, hash)));
          final urls = <String>[];
          for (final wrap in res.document.querySelectorAll('.comic-archive-chapter-wrap')) {
            if (clean(wrap.querySelector('.comic-archive-chapter')?.text) != title) continue;
            for (final a in wrap.querySelectorAll('.comic-archive-list-wrap .comic-archive-title > a')) {
              final h = a.attributes['href'];
              if (h != null) urls.add(h);
            }
            break;
          }
          final pages = <String>[];
          for (final u in urls) {
            final p = await s.fetchHtml(Uri.parse(u));
            final img = imgAttr(p.document.querySelector('#comic img'), p.url);
            if (img != null) pages.add(img);
          }
          return pages;
        },
      ),
      SingleSeriesSource(
        id: 'en.mahouirexnohentaikarte',
        name: 'Mahouirexnohentaikarte',
        baseUrl: 'https://mahouirexnohentaikarte.com',
        seriesTitle: 'Mahoui Rex no Hentai Karte',
        cover: 'https://mahouirexnohentaikarte.com/storage/manga/cover.webp',
        loadChapters: (s) async {
          final res = await s.fetchHtml(Uri.parse(s.baseUrl));
          final out = <SourceChapter>[];
          for (final a in res.document.querySelectorAll('#chapters ol > li > a')) {
            final href = attrAbs(a, 'href', res.url);
            if (href == null) continue;
            final name = clean(a.attributes['title']).isNotEmpty
                ? clean(a.attributes['title'])
                : clean(a.querySelector('span span')?.text);
            out.add(SourceChapter(
              url: href,
              name: name,
              number: parseChapterNumber(name),
              uploadedAt: DateTime.tryParse(a.querySelector('time')?.attributes['datetime'] ?? ''),
            ));
          }
          return out;
        },
        loadPages: (s, ch) async {
          final res = await s.fetchHtml(Uri.parse(ch.url));
          return [
            for (final img in res.document.querySelectorAll('img[src*="/storage/manga/chapter-"]'))
              if (attrAbs(img, 'src', res.url) case final u?) u,
          ];
        },
      ),
    ];
