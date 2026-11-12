import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/sources/source_exception.dart';
import 'package:hub_reader/sources/templates/iken.dart';

// JSON disederhanakan dari api.vortexscans.org. Tes ini memeriksa parser saja.

IkenSource _source({bool byFilename = false}) => IkenSource(
      id: 'en.x',
      name: 'X',
      baseUrl: 'https://x.org',
      lang: 'en',
      sortPagesByFilename: byFilename,
    );

void main() {
  test('api lives on the api. subdomain', () {
    expect(_source().apiUrl, 'https://api.x.org');
  });

  test('query results skip novels and page by totalCount', () {
    final page = _source().parseList({
      'posts': [
        {'id': 94, 'slug': 'reality-quest-2', 'postTitle': 'Reality Quest', 'featuredImage': 'https://s.x.org/rq.png'},
        {'id': 95, 'slug': 'a-novel', 'postTitle': 'A Novel', 'seriesType': 'NOVEL'},
        {'id': 96, 'slug': 'b-novel', 'postTitle': 'B Novel', 'isNovel': true},
      ],
      'totalCount': 40,
    }, 2);
    expect(page.items.single.url, 'https://x.org/series/reality-quest-2');
    expect(page.hasNextPage, isTrue); // 40 > 2 * 18
  });

  test('details hide locked chapters, sort newest first and keep the chapter id', () {
    final d = _source().parseDetails(
      {
        'id': 94,
        'slug': 'reality-quest-2',
        'postTitle': 'Reality Quest',
        'postContent': '<p>Line one</p>',
        'alternativeTitles': 'RQ',
        'seriesType': 'MANHWA',
        'seriesStatus': 'MASS_RELEASED',
        'author': '',
        'genres': [
          {'id': 1, 'name': 'Comedy'},
        ],
      },
      [
        {'id': 10, 'slug': 'chapter-229', 'number': 229, 'title': '', 'createdAt': '2026-11-06T12:59:58.995Z'},
        {'id': 11, 'slug': 'chapter-241', 'number': 241, 'title': 'Finale', 'createdAt': '2026-11-07T00:00:00Z'},
        {'id': 12, 'slug': 'chapter-242', 'number': 242, 'price': 50, 'createdAt': '2026-11-08T00:00:00Z'},
        {'id': 13, 'slug': 'chapter-243', 'number': 243, 'isTimeLocked': true, 'createdAt': '2026-11-09T00:00:00Z'},
      ],
    );
    expect(d.status, SourceMangaStatus.ongoing);
    expect(d.genres, ['Manhwa', 'Comedy']);
    expect(d.author, isNull);
    expect(d.description, 'Line one\n\nAlternative Names: RQ');
    expect(d.chapters.map((c) => c.name), ['Chapter 241 - Finale', 'Chapter 229']);
    expect(d.chapters.first.url, 'https://x.org/series/reality-quest-2/chapter-241#11');
    expect(d.chapters.last.uploadedAt?.toUtc(), DateTime.utc(2026, 11, 6, 12, 59, 58, 995));
  });

  test('pages sort by order (or file number) and reject locked chapters', () {
    final images = [
      {'url': 'https://s.x.org/c/10.jpg', 'order': 0},
      {'url': 'https://s.x.org/c/2 a.jpg', 'order': 1},
    ];
    expect(_source().parsePages({'images': images}), ['https://s.x.org/c/10.jpg', 'https://s.x.org/c/2%20a.jpg']);
    expect(_source(byFilename: true).parsePages({'images': images}),
        ['https://s.x.org/c/2%20a.jpg', 'https://s.x.org/c/10.jpg']);
    expect(() => _source().parsePages({'images': images, 'isLockedByCoins': true}),
        throwsA(isA<SourceException>()));
  });
}
