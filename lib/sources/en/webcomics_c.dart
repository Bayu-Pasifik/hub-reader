// Situs penggemar satu-judul "Read X Manga Online" (daftar bab di beranda),
// port Dart dari extension keiyoushi/extensions-source (Apache-2.0):
// kaijimangaonline, ruridragonmangaonline,
// maidsamamangaonline, thebeginningaftertheendmangaonline,
// theexiledheavyknightmangaonline, readhorimiyaonline.

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import 'multi_series.dart';

final _chNum = RegExp(r'chapter-(\d+(?:[.-]\d+)?)');

/// Satu judul; bab = tautan di beranda yang href-nya cocok [chapterHref].
MangaSource _fanSite({
  required String id,
  required String name,
  required String baseUrl,
  String? description,
  String? author,
  String? genres,
  String? cover,
  required String chapterSel,
  String pagesSel = '.entry-content img',
}) =>
    MultiSeriesSource(
      id: id,
      name: name,
      baseUrl: baseUrl,
      series: [
        SeriesDef(
          key: 'main',
          title: name
              .replaceFirst(RegExp(r'^Read '), '')
              .replaceFirst(RegExp(r' (Manga )?Online$'), ''),
          author: author,
          description: description,
          genres: genres == null ? const [] : genres.split(', '),
          cover: cover,
          loadCover: wcOgImage,
          loadChapters: (s) async {
            final res = await wcGet(s, '/');
            final seen = <String>{};
            final out = <SourceChapter>[];
            for (final a in res.document.querySelectorAll(chapterSel)) {
              final href = attrAbs(a, 'href', res.url);
              if (href == null || !seen.add(href)) continue;
              final num = _chNum.firstMatch(href)?[1]?.replaceAll('-', '.');
              final text = clean(a.text);
              out.add(SourceChapter(
                url: href,
                name: text.isEmpty ? 'Chapter ${num ?? ''}'.trim() : text,
                number: num == null ? null : double.tryParse(num),
              ));
            }
            out.sort((a, b) => (b.number ?? -1).compareTo(a.number ?? -1));
            return out;
          },
          loadPages: (s, ch) async {
            final res = await wcGet(s, ch.url);
            final out = <String>[];
            for (final img in res.document.querySelectorAll(pagesSel)) {
              final u = imgAttr(img, res.url);
              if (u == null || u.contains('cropped-') || out.contains(u))
                continue;
              out.add(u);
            }
            return out;
          },
        ),
      ],
    );

List<MangaSource> webcomicsC() => [
      _fanSite(
        id: 'en.kaijimangaonline',
        name: 'Kaiji Manga Online',
        baseUrl: 'https://w9.kaijimanga.com',
        chapterSel: "a[href*='-chapter-']",
      ),
      _fanSite(
        id: 'en.ruridragonmangaonline',
        name: 'RuriDragon Manga Online',
        baseUrl: 'https://w2.ruridragon.com',
        chapterSel: "a[href*='ruridragon-chapter-']",
      ),
      _fanSite(
        id: 'en.maidsamamangaonline',
        name: 'Read Maid Sama Manga Online',
        baseUrl: 'https://w14.maid-sama.com',
        chapterSel: "a[href*='maid-sama-chapter-']",
      ),
      _fanSite(
        id: 'en.thebeginningaftertheendmangaonline',
        name: 'Read The Beginning After The End Manga Online',
        baseUrl: 'https://w22.thebeginningaftertheendmanga.com',
        chapterSel: "a[href*='chapter-']",
      ),
      _fanSite(
        id: 'en.theexiledheavyknightmangaonline',
        name: 'Read The Exiled Heavy Knight Manga Online',
        baseUrl: 'https://w3.theexiledheavyknight.com',
        chapterSel: "a[href*='chapter-']",
        pagesSel: 'img[alt*="Chapter"]',
      ),
      MultiSeriesSource(
        id: 'en.readhorimiyaonline',
        name: 'Read Horimiya Online',
        baseUrl: 'https://read-horimiya.online',
        series: [
          SeriesDef(
            key: 'main',
            title: 'Horimiya',
            loadChapters: (s) async {
              final res = await wcGet(s, '/');
              return [
                for (final a in res.document
                    .querySelectorAll('div#chapter-list a.chapter-list-item'))
                  if (attrAbs(a, 'href', res.url) case final href?)
                    SourceChapter(
                      url: href,
                      name: clean(
                          a.querySelector('span.chapter-name')?.text ?? a.text),
                      uploadedAt: parseLooseDate(
                          clean(a.querySelector('span.chapter-date')?.text)),
                    ),
              ];
            },
            loadPages: wcImgs('div.images-container img'),
          ),
        ],
      ),
    ];
