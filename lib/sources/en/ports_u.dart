// Situs katalog (bagian U: Manhwa18, Paradise Scans, The Duck Webcomics),
// port Dart dari extension keiyoushi/extensions-source (Apache-2.0).

import 'package:html/dom.dart';

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import 'fn_source.dart';
import 'ports_util.dart';

DateTime? _dmy(String? raw) {
  final m = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(raw ?? '');
  return m == null ? null : DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
}

// ------------------------------------------------------------- Manhwa18 ---

String? _bgUrl(Element? el) {
  if (el == null) return null;
  final data = el.attributes['data-bg'];
  if (data != null && data.isNotEmpty) return data;
  final style = el.attributes['style'] ?? '';
  final i = style.indexOf("url('");
  if (i < 0) return null;
  return style.substring(i + 5).split("')").first;
}

Future<MangaPage> _m18List(FnSource s, Map<String, String> params) async {
  final res = await s.fetchHtml(Uri.parse('${s.baseUrl}/tim-kiem').replace(queryParameters: params));
  final out = <SourceManga>[];
  for (final el in res.document.querySelectorAll('.thumb-item-flow')) {
    final href = attrAbs(el.querySelector('a'), 'href', res.url);
    final title = clean(el.querySelector('.series-title a')?.text);
    if (href == null || title.isEmpty) continue;
    out.add(SourceManga(
      url: href,
      title: title,
      thumbnailUrl: absUrl(res.url, _bgUrl(el.querySelector('.lazy-bg')) ?? _bgUrl(el.querySelector('.img-in-ratio'))),
    ));
  }
  return MangaPage(out, hasNextPage: res.document.querySelector('.pagination_wrap a.next') != null);
}

FnSource _manhwa18() => FnSource(
      id: 'en.manhwa18',
      name: 'Manhwa18',
      baseUrl: 'https://manhwa18.com',
      contentWarning: ContentWarning.nsfw,
      popularFn: (s, page) => _m18List(s, {'sort': 'top', 'page': '$page'}),
      latestFn: (s, page) => _m18List(s, {'sort': 'update', 'page': '$page'}),
      searchFn: (s, page, q) => _m18List(s, {'q': q, 'sort': 'update', 'page': '$page'}),
      detailsFn: (s, url) async {
        final res = await s.fetchHtml(Uri.parse(url));
        final doc = res.document;
        String? author;
        var genres = <String>[];
        String? status;
        for (final item in doc.querySelectorAll('.series-information .info-item')) {
          final name = clean(item.querySelector('.info-name')?.text);
          final value = clean(item.querySelector('.info-value')?.text);
          if (name.isEmpty || value.isEmpty) continue;
          final lower = name.toLowerCase();
          if (lower.contains('author')) author = value;
          if (lower.contains('genre')) genres = [for (final a in item.querySelectorAll('.info-value a')) clean(a.text)];
          if (lower.contains('status')) status = value;
        }
        author ??= clean(doc.querySelector('.fantrans-value a')?.text);
        final chapters = <SourceChapter>[];
        for (final a in doc.querySelectorAll('div.au-chgrid a.au-chtile, ul.list-chapters > a')) {
          final href = attrAbs(a, 'href', res.url);
          if (href == null) continue;
          final name = clean((a.attributes['data-name'] ?? '').isNotEmpty ? a.attributes['data-name'] : a.attributes['title']);
          final t = a.querySelector('.au-chtile-date')?.text ?? a.querySelector('.chapter-time')?.text ?? '';
          chapters.add(SourceChapter(url: href, name: name.isEmpty ? clean(a.text) : name, number: parseChapterNumber(name), uploadedAt: _dmy(t)));
        }
        return SourceMangaDetails(
          url: url,
          title: clean(doc.querySelector('.series-name a, .au-bento h1, .au-crumb a:last-child')?.text),
          thumbnailUrl: absUrl(res.url, _bgUrl(doc.querySelector('.series-cover .img-in-ratio'))),
          author: author,
          description: clean(doc.querySelector('.summary-content')?.text),
          genres: genres,
          status: parseStatus(status?.replaceAll(' ', '')),
          chapters: chapters,
        );
      },
      pagesFn: (s, ch) async {
        final res = await s.fetchHtml(Uri.parse(ch.url));
        return [
          for (final img in res.document.querySelectorAll('#chapter-content img.lazy'))
            if (attrAbs(img, 'data-src', res.url) case final u?) u,
        ];
      },
    );

// -------------------------------------------------------- Paradise Scans ---

String _pdNumber(double n) => n == n.roundToDouble() ? '${n.toInt()}' : '$n';

MangaPage _pdPage(FnSource s, Object? json) {
  final m = json as Map;
  final meta = m['meta'] as Map?;
  return MangaPage([
    for (final it in (m['data'] as List).cast<Map>())
      SourceManga(
        url: '${s.baseUrl}/series/${it['slug']}',
        title: clean('${it['title']}'),
        thumbnailUrl: absUrl(s.baseUri, it['cover_url'] as String?),
      ),
  ], hasNextPage: ((meta?['current_page'] as num?) ?? 1) < ((meta?['last_page'] as num?) ?? 1));
}

Future<MangaPage> _pdList(FnSource s, Map<String, String> params) async => _pdPage(
    s,
    await s.fetchJson(Uri.parse('${s.baseUrl}/api/series').replace(queryParameters: {...params, 'per_page': '12'}), headers: const {'Accept': 'application/json'}));

FnSource _paradise() => FnSource(
      id: 'en.paradisescans',
      name: 'Paradise Scans',
      baseUrl: 'https://paradisescans.com',
      contentWarning: ContentWarning.nsfw,
      popularFn: (s, page) => _pdList(s, {'sort': 'sales', 'dir': 'desc', 'page': '$page'}),
      latestFn: (s, page) => _pdList(s, {'sort': 'latest_chapter', 'page': '$page'}),
      searchFn: (s, page, q) => _pdList(s, {'q': q, 'page': '$page'}),
      detailsFn: (s, url) async {
        final slug = Uri.parse(url).pathSegments.last;
        final series = await s.fetchJson(Uri.parse('${s.baseUrl}/api/series/$slug'), headers: const {'Accept': 'application/json'}) as Map;
        final list = await s.fetchJson(Uri.parse('${s.baseUrl}/api/series/$slug/chapters'), headers: const {'Accept': 'application/json'}) as List;
        final chapters = <SourceChapter>[];
        final sorted = list.cast<Map>().toList()..sort((a, b) => ((b['number'] as num?) ?? 0).compareTo((a['number'] as num?) ?? 0));
        for (final c in sorted) {
          final locked = ((c['price'] as num?) ?? 0) > 0 || c['is_premium'] == true || c['early_access'] == true || c['early_locked'] == true;
          if (locked) continue;
          final n = (c['number'] as num?)?.toDouble();
          final title = c['title'] as String?;
          final label = n == null
              ? (title == null || title.trim().isEmpty ? 'Chapter' : title)
              : (title == null || title.trim().isEmpty || title == _pdNumber(n)
                  ? 'Chapter ${_pdNumber(n)}'
                  : title.toLowerCase().startsWith('chapter')
                      ? title
                      : 'Chapter ${_pdNumber(n)} - $title');
          chapters.add(SourceChapter(
            url: '${s.baseUrl}/series/$slug/chapter/${n == null ? c['id'] : _pdNumber(n)}?id=${c['id']}',
            name: label,
            number: n,
            uploadedAt: DateTime.tryParse('${c['created_at'] ?? ''}'),
          ));
        }
        return SourceMangaDetails(
          url: url,
          title: clean('${series['title']}'),
          thumbnailUrl: absUrl(s.baseUri, series['cover_url'] as String?),
          author: series['author'] as String?,
          artist: (series['artist'] ?? series['author']) as String?,
          description: series['description'] as String?,
          genres: [for (final g in (series['genres'] as List? ?? const [])) '$g'],
          status: parseStatus(series['status'] as String?),
          chapters: chapters,
        );
      },
      pagesFn: (s, ch) async {
        final id = Uri.parse(ch.url).queryParameters['id'];
        if (id == null) return const [];
        final list = await s.fetchJson(Uri.parse('${s.baseUrl}/api/chapters/$id/pages'), headers: const {'Accept': 'application/json'}) as List;
        final pages = list.cast<Map>().toList()..sort((a, b) => ((a['page_number'] as num?) ?? 0).compareTo((b['page_number'] as num?) ?? 0));
        return [for (final p in pages) absUrl(s.baseUri, '${p['image_url']}')!];
      },
    );

// ------------------------------------------------------ The Duck Webcomics -

MangaPage _duckList(HtmlResponse res) {
  final out = <SourceManga>[];
  for (final el in res.document.querySelectorAll('.breadcrumb ~ div[style]')) {
    final t = el.querySelector('.size24');
    final href = attrAbs(t, 'href', res.url);
    if (t == null || href == null) continue;
    out.add(SourceManga(url: href, title: clean(t.text), thumbnailUrl: attrAbs(el.querySelector('img'), 'src', res.url)));
  }
  return MangaPage(out, hasNextPage: res.document.querySelector('a.next') != null);
}

List<List<(String, String)>> _duckChapters(Document doc) {
  final chapters = <List<(String, String)>>[];
  for (final o in doc.querySelectorAll('#page_dropdown > option').reversed) {
    final text = o.text;
    if (!text.startsWith('-') || chapters.isEmpty) chapters.add([]);
    chapters.last.add((o.attributes['value'] ?? '', text.replaceFirst(RegExp(r'^-\s*'), '')));
  }
  if (chapters.isEmpty) return chapters;
  // Bab terakhir masih bisa bertambah halaman, jadi dipisah per halaman.
  final last = chapters.removeLast();
  return [...chapters, for (final p in last) [p]];
}

String? _duckImage(Document doc, Uri base) => attrAbs(doc.querySelector('.page-image'), 'src', base);

FnSource _duck() => FnSource(
      id: 'en.theduckwebcomics',
      name: 'The Duck Webcomics',
      baseUrl: 'https://www.theduckwebcomics.com',
      contentWarning: ContentWarning.mixed,
      popularFn: (s, page) async => _duckList(await s.fetchHtml(Uri.parse('${s.baseUrl}/search/').replace(queryParameters: {'page': '$page'}))),
      latestFn: (s, page) async =>
          _duckList(await s.fetchHtml(Uri.parse('${s.baseUrl}/search/').replace(queryParameters: {'page': '$page', 'last_update': 'today'}))),
      searchFn: (s, page, q) async =>
          _duckList(await s.fetchHtml(Uri.parse('${s.baseUrl}/search/').replace(queryParameters: {'search': q, 'page': '$page'}))),
      detailsFn: (s, url) async {
        // Detail hanya tersedia di hasil pencarian; ambil dari halaman komik.
        final res = await s.fetchHtml(Uri.parse(url));
        final err = clean(res.document.querySelector('.yellow-box > .paranomargin')?.text);
        if (err.isNotEmpty) throw StateError(err);
        final chapters = _duckChapters(res.document);
        final base = url.endsWith('/') ? url : '$url/';
        final out = <SourceChapter>[];
        for (var i = 0; i < chapters.length; i++) {
          out.add(SourceChapter(url: '$base${chapters[i].first.$1}/', name: chapters[i].first.$2, number: i + 1.0));
        }
        return SourceMangaDetails(
          url: url,
          title: clean(res.document.querySelector('h1, .size24')?.text),
          thumbnailUrl: absUrl(res.url, res.document.querySelector('meta[property="og:image"]')?.attributes['content']),
          chapters: out.reversed.toList(),
        );
      },
      pagesFn: (s, ch) async {
        final res = await s.fetchHtml(Uri.parse(ch.url));
        final seg = Uri.parse(ch.url).pathSegments.where((e) => e.isNotEmpty).toList();
        final comic = seg[seg.length - 2];
        final id = seg.last;
        final first = _duckImage(res.document, res.url);
        final chapters = _duckChapters(res.document);
        final group = chapters.where((c) => c.first.$1 == id).firstOrNull;
        if (group == null) return [if (first != null) first];
        final urls = await pooled<String?>([
          for (var i = 0; i < group.length; i++)
            if (i == 0)
              () async => first
            else
              () async {
                final p = await s.fetchHtml(Uri.parse('${s.baseUrl}/$comic/${group[i].$1}/'));
                return _duckImage(p.document, p.url);
              },
        ]);
        return urls.whereType<String>().toList();
      },
    );

List<MangaSource> portsU() => [_manhwa18(), _paradise(), _duck()];
