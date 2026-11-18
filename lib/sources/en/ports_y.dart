// Situs katalog (bagian Y: Dynasty Scans), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0). Versi ringkas: seri, antologi,
// doujin, edisi, dan bab lepas; filter lanjutan (tag/penulis) belum ada.

import 'package:html/parser.dart' as html;

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import 'fn_source.dart';

const _mangaTypes = {'Series': 'series', 'Anthology': 'anthologies', 'Doujin': 'doujins', 'Issue': 'issues'};
final _chapterSlug = RegExp(r'(.*?)_(ch[0-9_]+|volume_[0-9_\w]+)');

String _title(String permalink) => permalink.replaceAll('_', ' ').replaceFirstMapped(RegExp(r'^\w'), (m) => m[0]!.toUpperCase());

/// Bab yang terhubung ke seri dialihkan ke halaman seri.
(String, String) _resolve(String dir, String permalink) {
  if (dir != 'chapters') return (dir, permalink);
  final m = _chapterSlug.firstMatch(permalink);
  return m == null ? (dir, permalink) : ('series', m[1]!);
}

String _stripHtml(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final text = raw.replaceAllMapped(RegExp(r'\\u([0-9A-Fa-f]{4})'), (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)));
  final frag = html.parseFragment(text);
  for (final a in frag.querySelectorAll('a')) {
    a.remove();
  }
  return frag.text?.trim() ?? '';
}

FnSource _dynasty() {
  SourceManga entry(FnSource s, String dir, String permalink, String title, {String? cover}) =>
      SourceManga(url: '${s.baseUrl}/$dir/$permalink', title: title, thumbnailUrl: cover);

  return FnSource(
    id: 'en.dynasty',
    name: 'Dynasty Scans',
    baseUrl: 'https://dynasty-scans.com',
    contentWarning: ContentWarning.mixed,
    popularFn: (s, page) async {
      if (page > 1) return const MangaPage([], hasNextPage: false);
      final res = await s.fetchHtml(Uri.parse(s.baseUrl));
      final out = <SourceManga>[];
      for (final h4 in res.document.querySelectorAll('h4')) {
        if (!h4.text.contains('Most Popular of Past 7 Days')) continue;
        var el = h4.nextElementSibling;
        while (el != null && el.localName != 'h4') {
          for (final a in el.querySelectorAll('a.thumbnail')) {
            final seg = Uri.tryParse(absUrl(res.url, a.attributes['href']) ?? '')?.pathSegments ?? const [];
            if (seg.length < 2) continue;
            final (dir, perm) = _resolve(seg[0], seg[1]);
            out.add(entry(s, dir, perm, _title(perm), cover: attrAbs(a.querySelector('img'), 'src', res.url)));
          }
          el = el.nextElementSibling;
        }
      }
      return MangaPage(out.toSet().toList(), hasNextPage: false);
    },
    latestFn: (s, page) async {
      final j = await s.fetchJson(Uri.parse('${s.baseUrl}/chapters/added.json?page=${page - 1}'), headers: const {'Accept': 'application/json'}) as Map;
      final entries = <SourceManga>{};
      for (final c in (j['chapters'] as List).cast<Map>()) {
        var series = false;
        for (final t in (c['tags'] as List).cast<Map>()) {
          final dir = _mangaTypes['${t['type']}'];
          if (dir == null) continue;
          entries.add(entry(s, dir, '${t['permalink']}', '${t['name']}'));
          series = series || t['type'] == 'Series';
        }
        if (!series) entries.add(entry(s, 'chapters', '${c['permalink']}', '${c['title']}'));
      }
      return MangaPage(entries.toList(), hasNextPage: (j['current_page'] as num) <= (j['total_pages'] as num));
    },
    searchFn: (s, page, q) async {
      final uri = Uri.parse('${s.baseUrl}/search').replace(queryParameters: <String, dynamic>{
        'q': q.trim(),
        'classes[]': ['Series', 'Chapter', 'Anthology', 'Doujin', 'Issue'],
        'sort': '',
        if (page > 1) 'page': '$page',
      });
      final res = await s.fetchHtml(uri);
      final out = <SourceManga>{};
      for (final a in res.document.querySelectorAll('.chapter-list a.name')) {
        final seg = Uri.tryParse(absUrl(res.url, a.attributes['href']) ?? '')?.pathSegments ?? const [];
        if (seg.length < 2 || !{'series', 'anthologies', 'chapters', 'doujins', 'issues'}.contains(seg[0])) continue;
        final (dir, perm) = _resolve(seg[0], seg[1]);
        out.add(entry(s, dir, perm, dir == seg[0] ? clean(ownText(a)) : _title(perm)));
      }
      return MangaPage(out.toList(), hasNextPage: res.document.querySelector('.pagination [rel=next]') != null);
    },
    detailsFn: (s, url) async {
      final seg = Uri.parse(url).pathSegments.where((e) => e.isNotEmpty).toList();
      final dir = seg[0];
      final permalink = seg[1];
      final api = '${s.baseUrl}/$dir/$permalink.json';
      final j = await s.fetchJson(Uri.parse(api), headers: const {'Accept': 'application/json'}) as Map;
      if (dir == 'chapters') {
        final tags = (j['tags'] as List).cast<Map>();
        return SourceMangaDetails(
          url: url,
          title: '${j['title']}',
          thumbnailUrl: (j['pages'] as List).isEmpty ? null : '${s.baseUrl}${((j['pages'] as List).first as Map)['url']}',
          author: tags.where((t) => t['type'] == 'Author').map((t) => '${t['name']}').join(', '),
          genres: [for (final t in tags.where((t) => t['type'] == 'General')) '${t['name']}'],
          description: 'Released: ${j['released_on']}',
          status: SourceMangaStatus.completed,
          chapters: [
            SourceChapter(
              url: url,
              name: 'Chapter',
              number: 1,
              scanlator: tags.where((t) => t['type'] == 'Scanlator').map((t) => '${t['name']}').join(', '),
              uploadedAt: DateTime.tryParse('${j['released_on']}'),
            ),
          ],
        );
      }
      final items = (j['taggings'] as List).cast<Map>().toList();
      final totalPages = (j['total_pages'] as num?)?.toInt() ?? 1;
      for (var p = 2; p <= totalPages && p <= 10; p++) {
        final more = await s.fetchJson(Uri.parse('$api?page=$p'), headers: const {'Accept': 'application/json'}) as Map;
        items.addAll((more['taggings'] as List).cast<Map>());
      }
      final authors = <String>{};
      final genres = <String>{};
      final status = <String>{};
      for (final t in (j['tags'] as List).cast<Map>()) {
        switch (t['type']) {
          case 'Author':
            authors.add('${t['name']}');
          case 'General':
            genres.add('${t['name']}');
          case 'Status':
            status.add('${t['name']}');
        }
      }
      String? header;
      final chapters = <SourceChapter>[];
      for (final it in items) {
        if (it.containsKey('header')) {
          header = it['header'] as String?;
          continue;
        }
        final tags = (it['tags'] as List? ?? const []).cast<Map>();
        var name = header == null ? '${it['title']}' : '$header ${it['title']}';
        if (j['type'] != 'Series') {
          final by = tags.where((t) => t['type'] == 'Author').map((t) => '${t['name']}').join(' and ');
          if (by.isNotEmpty) name += ' by $by';
        }
        chapters.add(SourceChapter(
          url: '${s.baseUrl}/chapters/${it['permalink']}',
          name: name,
          number: parseChapterNumber('${it['title']}'),
          scanlator: tags.where((t) => t['type'] == 'Scanlator').map((t) => '${t['name']}').join(', '),
          uploadedAt: DateTime.tryParse('${it['released_on']}'),
        ));
      }
      final desc = _stripHtml(j['description'] as String?);
      final aliases = (j['aliases'] as List?)?.map((e) => '• $e').join('\n') ?? '';
      return SourceMangaDetails(
        url: url,
        title: '${j['name']}',
        thumbnailUrl: j['cover'] == null ? null : absUrl(s.baseUri, '${j['cover']}'),
        author: authors.join(', '),
        description: [if (desc.isNotEmpty) desc, 'Type: ${j['type']}', if (aliases.isNotEmpty) 'Aliases:\n$aliases'].join('\n\n'),
        genres: genres.toList(),
        status: status.contains('Ongoing')
            ? SourceMangaStatus.ongoing
            : status.contains('Completed')
                ? SourceMangaStatus.completed
                : status.contains('On Hiatus')
                    ? SourceMangaStatus.hiatus
                    : status.any(const {'Dropped', 'Cancelled', 'Not Updated', 'Abandoned', 'Removed'}.contains)
                        ? SourceMangaStatus.cancelled
                        : SourceMangaStatus.unknown,
        chapters: j['type'] == 'Doujin' ? chapters : chapters.reversed.toList(),
      );
    },
    pagesFn: (s, ch) async {
      final permalink = Uri.parse(ch.url).pathSegments.where((e) => e.isNotEmpty).last;
      final j = await s.fetchJson(Uri.parse('${s.baseUrl}/chapters/$permalink.json'), headers: const {'Accept': 'application/json'}) as Map;
      return [for (final p in (j['pages'] as List).cast<Map>()) '${s.baseUrl}${p['url']}'];
    },
  );
}

List<MangaSource> portsY() => [_dynasty()];
