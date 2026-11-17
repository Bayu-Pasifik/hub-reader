// Situs katalog (bagian I), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0): readvagabondmanga,
// thegirlfromrandomchattingmangaonline.

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import 'fn_source.dart';
import 'multi_series.dart';

SourceManga _vagabondManga(Map m) =>
    SourceManga(url: '/#${m['id']}', title: '${m['title']}', thumbnailUrl: m['cover'] as String?);

List<MangaSource> webcomicsI() => [
      // Read Vagabond Manga
      FnSource(
        id: 'en.readvagabondmanga',
        name: 'Read Vagabond Manga',
        baseUrl: 'https://readbagabondo.com',
        popularFn: (s, page) async {
          final l = await s.fetchJson(Uri.parse('${s.baseUrl}/api/mihon/mangas')) as List;
          return MangaPage([for (final m in l) _vagabondManga(m as Map)], hasNextPage: false);
        },
        searchFn: (s, page, q) async {
          final l = await s.fetchJson(Uri.parse('${s.baseUrl}/api/mihon/mangas').replace(queryParameters: {'search': q})) as List;
          return MangaPage([
            for (final m in l)
              if ('${(m as Map)['title']}'.toLowerCase().contains(q.toLowerCase())) _vagabondManga(m),
          ], hasNextPage: false);
        },
        detailsFn: (s, url) async {
          final id = url.split('#').last;
          final m = await s.fetchJson(Uri.parse('${s.baseUrl}/api/mihon/mangas/$id')) as Map;
          final chs = await s.fetchJson(Uri.parse('${s.baseUrl}/api/mihon/mangas/$id/chapters')) as List;
          return SourceMangaDetails(
            url: url,
            title: '${m['title']}',
            thumbnailUrl: m['cover'] as String?,
            author: m['author'] as String?,
            artist: m['artist'] as String?,
            description: m['description'] as String?,
            status: parseStatus('${m['status']}'),
            chapters: [
              for (final c in chs.cast<Map>())
                SourceChapter(
                  url: '/volume-${c['volume']}/chapter-${c['number']}/#$id',
                  name: '${c['title']}',
                  number: (c['number'] as num).toDouble(),
                  uploadedAt: DateTime.tryParse('${c['releaseDate']}'),
                  scanlator: 'Read Vagabond Manga',
                ),
            ].reversed.toList(),
          );
        },
        pagesFn: (s, ch) async {
          final id = ch.url.split('#').last;
          final n = ch.number?.toInt() ?? 0;
          final c = await s.fetchJson(Uri.parse('${s.baseUrl}/api/mihon/mangas/$id/chapters/$n')) as Map;
          final count = (c['pageCount'] as num).toInt();
          return [for (var p = 1; p <= count; p++) 'https://pub.moleve.net/chapter-${c['number']}/page-$p.png'];
        },
      ),
      // The Girl from Random Chatting
      MultiSeriesSource(
        id: 'en.thegirlfromrandomchatting',
        name: 'The Girl from Random Chatting Manga Online',
        baseUrl: 'https://thegirlfromrandomchatting.com',
        series: [
          SeriesDef(
            key: 'main',
            title: 'The Girl from Random Chatting',
            author: 'Eun Hyuk, Park',
            genres: const ['Action', 'Drama', 'Comedy', 'Romance', 'Slice of Life', 'Shounen', 'Harem'],
            loadCover: wcOgImage,
            loadChapters: (s) async {
              final l = await s.fetchJson(wcUri(s, '/wp-json/mg/v1/chapters-list')) as List;
              return [
                for (final c in l.cast<Map>())
                  SourceChapter(
                    url: '${s.baseUrl}/manga/${Uri.parse('${c['url']}').pathSegments.lastWhere((e) => e.isNotEmpty)}',
                    name: '${c['title']}'.split(', ').last,
                    number: parseChapterNumber('${c['title']}'.split(', ').last),
                    uploadedAt: DateTime.tryParse('${c['date']}'),
                  ),
              ];
            },
            loadPages: (s, ch) async {
              final res = await wcGet(s, ch.url);
              final urls = <String>[];
              // Gambar dibungkus <noscript>; isinya berupa teks mentah.
              for (final m in RegExp(r'<noscript>\s*<img[^>]*?src="([^"]+)"').allMatches(res.body)) {
                urls.add(m[1]!);
              }
              if (urls.isEmpty) {
                for (final n in res.document.querySelectorAll('p > noscript')) {
                  final m = RegExp(r'src="([^"]+)"').firstMatch(n.text);
                  if (m != null) urls.add(m[1]!);
                }
              }
              return urls;
            },
          ),
        ],
      ),
    ];

