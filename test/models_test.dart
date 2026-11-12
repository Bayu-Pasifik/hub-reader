import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/core/network/api_exception.dart';
import 'package:hub_reader/core/utils/formatters.dart';
import 'package:hub_reader/core/utils/media_url.dart';
import 'package:hub_reader/data/models/chapter.dart';
import 'package:hub_reader/data/models/home_sections.dart';
import 'package:hub_reader/data/models/paginated.dart';
import 'package:hub_reader/data/models/series.dart';

/// Contoh JSON disalin dari bentuk SeriesResource / ChapterResource /
/// paginator Laravel di scraper-hub.
const _seriesJson = {
  'id': 7,
  'type': 'comic',
  'source': 'comix',
  'external_id': 'abc',
  'title': 'Sword Emperor',
  'slug': 'sword-emperor',
  'author': 'Someone',
  'genres': ['Action', 'Fantasy'],
  'tags': [],
  'status': 'ongoing',
  'description': '<p>A long story.</p>',
  'cover': {'thumbnail': 'http://localhost:8000/storage/covers/7.webp', 'original': 'https://img.example.com/c.jpg'},
  'source_url': 'https://comix.to/title/abc',
  'chapter_count': 2,
  'scraped_at': '2026-11-10T12:00:00+00:00',
  'latest_chapters': [
    {'number': 2.0, 'title': 'Chapter 2', 'url': 'https://comix.to/abc/2', 'is_locked': false, 'published_at': null},
    {'number': 1.5, 'title': null, 'url': 'https://comix.to/abc/1.5', 'is_locked': true, 'published_at': null},
  ],
  'links': {'self': 'http://localhost/api/v1/comics/7', 'chapters': 'http://localhost/api/v1/comics/7/chapters'},
};

void main() {
  test('Series parses SeriesResource', () {
    final series = Series.fromJson(_seriesJson);
    expect(series.type, SeriesType.comic);
    expect(series.genres, ['Action', 'Fantasy']);
    expect(series.coverUrl, contains('/storage/covers/7.webp'));
    expect(series.latestChapters.length, 2);
    expect(series.latestChapters[1].isLocked, isTrue);
  });

  test('Paginated reads Laravel meta and skips broken items', () {
    final page = Paginated.fromJson({
      'data': [_seriesJson, {'title': 'no id'}],
      'links': {},
      'meta': {'current_page': 1, 'last_page': 3, 'per_page': 24, 'total': 60},
    }, Series.tryParse);
    expect(page.items.length, 1);
    expect(page.hasMore, isTrue);
    expect(page.total, 60);
  });

  test('HomeSections keeps known order and ignores continue_reading', () {
    final home = HomeSections.fromJson({
      'data': {
        'comics_recently_updated': [_seriesJson],
        'novels_recently_updated': [_seriesJson],
        'continue_reading': [{'in_library': true}],
      },
    });
    expect(home.sections.map((s) => s.key), ['novels_recently_updated', 'comics_recently_updated']);
  });

  test('Chapter number formatting', () {
    expect(formatChapterNumber(12), '12');
    expect(formatChapterNumber(12.5), '12.5');
    expect(Chapter.tryParse({'number': '3.00', 'url': 'https://x/3'})?.label, 'Bab 3');
  });

  test('Loopback cover URLs are rewritten to the API host', () {
    final origin = Uri.parse('http://10.0.2.2:8000');
    expect(
      resolveMediaUrl('http://localhost/storage/covers/1.webp', origin),
      'http://10.0.2.2:8000/storage/covers/1.webp',
    );
    expect(resolveMediaUrl('https://img.example.com/a.jpg', origin), 'https://img.example.com/a.jpg');
  });

  test('HTTP status maps to error kind', () {
    expect(ApiException.fromStatus(401, {'message': 'Missing or invalid API key.'}).kind,
        ApiErrorKind.unauthorized);
    expect(ApiException.fromStatus(429, null).kind, ApiErrorKind.rateLimited);
    expect(ApiException.fromStatus(503, null).canFallBackToCache, isTrue);
    expect(ApiException.fromStatus(404, null).canFallBackToCache, isFalse);
  });
}
