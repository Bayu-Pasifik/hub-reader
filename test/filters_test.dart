import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:hub_reader/sources/id/komiku.dart';
import 'package:hub_reader/sources/source.dart';
import 'package:hub_reader/sources/templates/mangathemesia.dart';

void main() {
  test('FilterValues is structural, order-insensitive, and clears empty values', () {
    final a = FilterValues.empty.withSingle('status', 'ongoing').toggleMulti('genre', 'action').toggleMulti('genre', 'drama');
    final b = FilterValues.empty.toggleMulti('genre', 'drama').toggleMulti('genre', 'action').withSingle('status', 'ongoing');
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.activeCount, 2);
    expect(a.withSingle('status', '').toggleMulti('genre', 'action').toggleMulti('genre', 'drama'), FilterValues.empty);
  });

  test('MangaThemesia search URL carries filters like the Kotlin template', () {
    final source = MangaThemesiaSource(id: 't', name: 'T', baseUrl: 'https://example.com');
    final filters = FilterValues.empty
        .withSingle('status', 'completed')
        .withSingle('type', 'Manhwa')
        .withSingle('order', 'title')
        .toggleMulti('genre', 'action')
        .toggleMulti('genre', 'fantasy');
    final url = source.searchUrl(1, '', filters: filters);
    expect(url.path, '/manga/');
    expect(url.queryParametersAll, {
      'page': ['1'],
      'status': ['completed'],
      'type': ['Manhwa'],
      'order': ['title'],
      'genre[]': ['action', 'fantasy'],
    });
  });

  test('MangaThemesia parses genre checkboxes', () {
    final doc = html_parser.parse('''
      <ul class="genrez">
        <li><input type="checkbox" value="action" id="g1"><label for="g1">Action</label></li>
        <li><input type="checkbox" value="drama" id="g2"><label for="g2">Drama</label></li>
      </ul>''');
    final genres = MangaThemesiaSource(id: 't', name: 'T', baseUrl: 'https://e.com').parseGenres(doc);
    expect(genres.map((g) => '${g.label}=${g.value}'), ['Action=action', 'Drama=drama']);
  });

  test('Komiku search URL uses Filters.kt parameter names', () {
    final url = KomikuSource().searchUrl(
      2,
      'one',
      FilterValues.empty.withSingle('tipe', 'manhwa').withSingle('statusmanga', 'end').withSingle('genre', 'action'),
    );
    expect(url.toString(), startsWith('https://api.komiku.org/manga/page/2/?'));
    expect(url.queryParameters, {'s': 'one', 'tipe': 'manhwa', 'genre': 'action', 'statusmanga': 'end'});
  });
}
