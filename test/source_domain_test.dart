import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/sources/catalog.dart';
import 'package:hub_reader/sources/id/shinigami.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/sources/source.dart';
import 'package:hub_reader/sources/templates/mangathemesia.dart';
import 'package:hub_reader/state/core_providers.dart';
import 'package:hub_reader/state/source_providers.dart';
import 'package:hub_reader/state/source_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('domain override', () {
    test('rewrites only hosts known to the source', () {
      final s = MangaThemesiaSource(id: 't', name: 'T', baseUrl: 'https://old.example.com')
        ..baseUrlOverride = 'https://new.example.com/'
        ..previousHosts = {'older.example.com'};
      expect(s.baseUrl, 'https://new.example.com');
      expect(s.rewriteToCurrentHost(Uri.parse('https://old.example.com/manga/a/')).toString(),
          'https://new.example.com/manga/a/');
      expect(s.rewriteToCurrentHost(Uri.parse('https://older.example.com/x')).host, 'new.example.com');
      expect(s.rewriteToCurrentHost(Uri.parse('https://cdn.other.com/1.jpg')).host, 'cdn.other.com');
    });

    test('settings apply to the registry, remember old hosts, and reset', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        sourceCatalogProvider.overrideWithValue(SourceCatalog.fromJsonString(
          '{"sources":[{"id":"id.komikstation","name":"Komik Station","lang":"id",'
          '"baseUrl":"https://komikstation.org","theme":"mangathemesia","contentWarning":"safe"}]}',
        )),
      ]);
      addTearDown(c.dispose);

      HttpSource src() => c.read(sourceProvider('id.komikstation'))! as HttpSource;
      expect(src().baseUrl, 'https://komikstation.org');

      await c.read(sourceBaseUrlProvider.notifier).set('id.komikstation', 'https://ks2.example/', currentUrl: src().baseUrl);
      expect(src().baseUrl, 'https://ks2.example');
      expect(src().previousHosts, contains('komikstation.org'));

      await c.read(sourceBaseUrlProvider.notifier).reset('id.komikstation',
          currentUrl: src().baseUrl, defaultUrl: src().defaultBaseUrl);
      expect(src().baseUrl, 'https://komikstation.org');
      expect(src().previousHosts, contains('ks2.example'));
    });
  });

  group('Shinigami', () {
    final s = ShinigamiSource();

    test('parses list JSON and pagination meta', () {
      final page = s.parseMangaList({
        'data': [
          {'manga_id': 'abc', 'title': 'Demonic Emperor', 'cover_portrait_url': '', 'cover_image_url': 'https://a/c.jpg'},
          {'manga_id': '', 'title': 'skip'},
        ],
        'meta': {'page': 1, 'total_page': 3},
      });
      expect(page.items.single.url, 'https://11.shinigami.asia/series/abc');
      expect(page.items.single.thumbnailUrl, 'https://a/c.jpg');
      expect(page.hasNextPage, isTrue);
    });

    test('parses detail + chapters', () {
      final d = s.parseDetails(
        'https://11.shinigami.asia/series/abc',
        {
          'title': 'Demonic Emperor',
          'status': 1,
          'description': 'Sinopsis.',
          'alternative_title': 'Mo Huang',
          'taxonomy': {
            'Author': [{'name': 'Netease'}],
            'Genre': [{'name': 'Action'}],
            'Format': [{'name': 'Manhua'}],
          },
        },
        {
          'data': [
            {'chapter_id': 'c2', 'chapter_number': 933.0, 'chapter_title': '', 'release_date': '2026-11-10T03:00:00Z'},
            {'chapter_id': 'c1', 'chapter_number': 932.5, 'chapter_title': 'Spesial'},
          ],
        },
      );
      expect(d.author, 'Netease');
      expect(d.status, SourceMangaStatus.ongoing);
      expect(d.genres, ['Action', 'Manhua']);
      expect(d.description, 'Sinopsis.\n\nJudul alternatif: Mo Huang');
      expect(d.chapters.map((c) => c.name), ['Chapter 933', 'Chapter 932.5 Spesial']);
      expect(d.chapters.first.url, 'https://11.shinigami.asia/chapter/c2');
      expect(d.chapters.first.uploadedAt, isNotNull);
    });

    test('search URL uses Filters.kt parameters', () {
      final url = s.searchUrl(2, 'emperor',
          FilterValues.empty.withSingle('status', 'ongoing').toggleMulti('genre', 'action').toggleMulti('genre', 'fantasy'));
      expect(url.queryParameters, {
        'page': '2',
        'page_size': '30',
        'q': 'emperor',
        'status': 'ongoing',
        'genre_include': 'action,fantasy',
        'genre_include_mode': 'and',
      });
    });
  });
}
