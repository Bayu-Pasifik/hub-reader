// Port Dart dari template Guya milik keiyoushi/extensions-source (Apache-2.0):
// lib-multisrc/guya (Guya.moe, Danke fürs Lesen, Hachirumi, Magical Translators).
//
// API JSON: `/api/get_all_series/` (semua seri sekaligus), `/api/series/<slug>/`
// (detail + bab per grup). Gambar di `/media/manga/<slug>/chapters/<folder>/<grup>/<file>`.

import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';
import '../../core/i18n/strings.dart';

class GuyaSource extends HttpSource {
  GuyaSource({
    required this.id,
    required this.name,
    required String baseUrl,
    required this.lang,
    this.contentWarning = ContentWarning.safe,
    this.vals = const {},
    super.dio,
  }) : defaultBaseUrl = baseUrl;

  @override
  final String id;
  @override
  final String name;
  @override
  final String defaultBaseUrl;
  @override
  final String lang;
  @override
  final ContentWarning contentWarning;

  final JsonMap vals;

  /// Magical Translators: satu situs, tiga bahasa dibedakan akhiran slug (-ES, -PL).
  bool get slugLangFilter => vals['slugLangFilter'] == true;

  // =========================== Daftar ===========================

  @override
  Future<MangaPage> popular(int page) async => _page(await _all());

  @override
  Future<MangaPage> latest(int page) async {
    final all = (await _all()).entries.toList()
      ..sort((a, b) => (asInt(b.value['last_updated']) ?? 0).compareTo(asInt(a.value['last_updated']) ?? 0));
    return _page(Map.fromEntries(all));
  }

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    final all = await _all();
    final q = query.trim();
    const slugPrefix = 'slug:';
    if (q.startsWith(slugPrefix)) {
      final slug = q.substring(slugPrefix.length);
      return _page({
        for (final e in all.entries)
          if (asString(e.value['slug']) == slug) e.key: e.value,
      });
    }
    return _page({
      for (final e in all.entries)
        if (e.key.toLowerCase().contains(q.toLowerCase())) e.key: e.value,
    });
  }

  Future<Map<String, JsonMap>> _all() async {
    final json = asMap(await fetchJson(Uri.parse('$baseUrl/api/get_all_series/')));
    return {for (final e in json.entries) e.key: asMap(e.value)};
  }

  MangaPage parseSeries(Map<String, JsonMap> series) => _page(series);

  MangaPage _page(Map<String, JsonMap> series) {
    final items = <SourceManga>[];
    for (final e in series.entries) {
      final slug = asString(e.value['slug']);
      if (slug == null || !_keepSlug(slug)) continue;
      items.add(SourceManga(url: _seriesUrl(slug), title: e.key, thumbnailUrl: _coverUrl(asString(e.value['cover']))));
    }
    return MangaPage(items, hasNextPage: false);
  }

  bool _keepSlug(String slug) {
    if (!slugLangFilter) return true;
    final es = slug.endsWith('-ES');
    final pl = slug.endsWith('-PL');
    return switch (lang) {
      'es' => es,
      'pl' => pl,
      _ => !es && !pl,
    };
  }

  String _seriesUrl(String slug) => '$baseUrl/reader/series/$slug/';

  String? _coverUrl(String? cover) {
    if (cover == null || cover.isEmpty) return null;
    if (cover.startsWith('http')) return cover;
    return cover.startsWith('/') ? '$baseUrl$cover' : '$baseUrl/$cover';
  }

  // =========================== Detail ===========================

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final segments = Uri.parse(mangaUrl).pathSegments.where((s) => s.isNotEmpty).toList();
    // /reader/series/<slug>/
    final slug = segments.length >= 3 ? segments[2] : (segments.lastOrNull ?? '');
    if (slug.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('URL seri tidak dikenali.'));
    final json = asMap(await fetchJson(Uri.parse('$baseUrl/api/series/$slug/')));
    return parseDetails(json);
  }

  static String _cleanDescription(String? html) {
    if (html == null || html.isEmpty) return '';
    if (!html.contains('<')) return html;
    return clean(html.replaceAll(RegExp(r'<a\b[^>]*>.*?</a>', dotAll: true), '').replaceAll(RegExp(r'<[^>]*>'), ' '));
  }

  SourceMangaDetails parseDetails(JsonMap s) {
    final slug = asString(s['slug']) ?? '';
    final groups = asMap(s['groups']);
    final seriesSort = _sort(s['preferred_sort']);
    final chapters = <SourceChapter>[];
    for (final entry in asMap(s['chapters']).entries) {
      final num = entry.key;
      final ch = asMap(entry.value);
      final chGroups = asMap(ch['groups']);
      final sort = _sort(ch['preferred_sort']) ?? seriesSort;
      final release = asMap(ch['release_date']);
      final title = '$num - ${asString(ch['title']) ?? ''}';
      DateTime? date(String g) {
        final ts = asInt(release[g]);
        return ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      }

      if (sort != null && chGroups.isNotEmpty) {
        final best = sort.firstWhere(chGroups.containsKey, orElse: () => chGroups.keys.first);
        chapters.add(_chapter(slug, num, best, title, asString(groups[best]) ?? best, date(best)));
      } else {
        for (final g in chGroups.keys) {
          chapters.add(_chapter(slug, num, g, title, asString(groups[g]), date(g)));
        }
      }
    }
    final description = _cleanDescription(asString(s['description']));
    return SourceMangaDetails(
      url: _seriesUrl(slug),
      title: clean(asString(s['title'])),
      thumbnailUrl: _coverUrl(asString(s['cover'])),
      author: asString(s['author']),
      artist: asString(s['artist']),
      description: description.isEmpty ? null : description,
      chapters: chapters.reversed.toList(),
    );
  }

  static List<String>? _sort(Object? raw) {
    final list = asList(raw).map(asString).whereType<String>().toList();
    return list.isEmpty ? null : list;
  }

  SourceChapter _chapter(String slug, String num, String group, String name, String? scanlator, DateTime? date) =>
      SourceChapter(
        // Slug, nomor, dan grup di fragmen: dibutuhkan untuk membentuk URL gambar.
        url: '$baseUrl/read/manga/$slug/${num.replaceAll('.', '-')}/1/'
            '#s=${Uri.encodeComponent(slug)}&n=${Uri.encodeComponent(num)}&g=${Uri.encodeComponent(group)}',
        name: name,
        number: double.tryParse(num),
        scanlator: scanlator,
        uploadedAt: date,
      );

  // =========================== Halaman ===========================

  static String? _frag(String fragment, String key) {
    for (final part in fragment.split('&')) {
      if (part.startsWith('$key=')) return Uri.decodeComponent(part.substring(key.length + 1));
    }
    return null;
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final fragment = Uri.parse(chapter.url).fragment;
    final slug = _frag(fragment, 's');
    final num = _frag(fragment, 'n');
    final group = _frag(fragment, 'g');
    if (slug == null || num == null || group == null) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Muat ulang daftar bab.'));
    }
    final series = asMap(await fetchJson(Uri.parse('$baseUrl/api/series/$slug/')));
    final ch = asMap(asMap(series['chapters'])[num]);
    final files = asList(asMap(ch['groups'])[group]);
    return parsePages(slug, asString(ch['folder']) ?? '', group, files);
  }

  List<String> parsePages(String slug, String folder, String group, List<Object?> files) => [
        for (final f in files) '$baseUrl/media/manga/$slug/chapters/$folder/$group/${asString(f)}',
      ];
}
