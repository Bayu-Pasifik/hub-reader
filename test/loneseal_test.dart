import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/sources/templates/loneseal.dart';

void main() {
  test('api URL derives from the top domain, or sits on baseUrl', () {
    expect(LoneSealSource(id: 'a', name: 'A', baseUrl: 'https://v3.ainzscans01.com', lang: 'id').apiUrl,
        'https://api.ainzscans01.com/api');
    expect(LoneSealSource(id: 'b', name: 'B', baseUrl: 'https://izanami.my.id', lang: 'id').apiUrl,
        'https://api.izanami.my.id/api');
    expect(LoneSealSource(id: 'c', name: 'C', baseUrl: 'https://v1.soulscans.asia', lang: 'id', apiOnBase: true).apiUrl,
        'https://v1.soulscans.asia/api');
  });

  test('details map units to chapters with the site URL layout', () {
    final s = LoneSealSource(id: 'a', name: 'A', baseUrl: 'https://x.com', lang: 'id', urlLayout: 'LEGACY_COMIC');
    final d = s.parseDetails({
      'title': ' Solo ',
      'slug': 'solo',
      'synopsis': '<p>Satu</p><p>Dua &amp; tiga</p>',
      'comic_status': 'ONGOING',
      'primary_genre': 'Action',
      'genres': [
        {'name': 'Action'},
        {'name': 'Fantasy'},
      ],
      'units': [
        {'slug': 'ch-2', 'number': '2.00', 'created_at': '2026-11-10T00:00:00Z'},
        {'slug': 'ch-1-5', 'number': '1.50'},
      ],
    }, 'https://x.com/comic/solo');
    expect(d.title, 'Solo');
    expect(d.description, 'Satu\n\nDua & tiga');
    expect(d.status, SourceMangaStatus.ongoing);
    expect(d.genres, ['Action', 'Fantasy']);
    expect(d.chapters.map((c) => c.name), ['Chapter 2', 'Chapter 1.50'.replaceFirst('.50', '.5')]);
    expect(d.chapters.first.url, 'https://x.com/comic/solo/chapter/ch-2');
  });

  test('blogger images upgrade to full resolution', () {
    expect(LoneSealSource.fullResolution('https://blogger.googleusercontent.com/img/a/x=w1200'),
        'https://blogger.googleusercontent.com/img/a/x=s0');
    expect(LoneSealSource.fullResolution('https://cdn.x.com/a.jpg'), 'https://cdn.x.com/a.jpg');
  });
}
