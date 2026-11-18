// Situs katalog (bagian X: HentaiNexus), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0).

import 'dart:convert';

import 'package:html/dom.dart';

import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import 'fn_source.dart';

/// Dekripsi data pembaca HentaiNexus (kunci diturunkan dari hostname).
String _nexusDecrypt(String b64) {
  final data = base64.decode(base64.normalize(b64.trim())).toList();
  const host = 'hentainexus.com';
  for (var i = 0; i < host.length; i++) {
    data[i] = data[i] ^ host.codeUnitAt(i);
  }
  final keyStream = data.sublist(0, 64);
  final cipher = data.sublist(64);
  const primes = [2, 3, 5, 7, 11, 13, 17, 19];
  final digest = List<int>.generate(256, (i) => i);
  var primeIdx = 0;
  for (var i = 0; i < 64; i++) {
    primeIdx ^= keyStream[i];
    for (var j = 0; j < 8; j++) {
      primeIdx = (primeIdx & 1) != 0 ? ((primeIdx >> 1) ^ 12) : (primeIdx >> 1);
    }
  }
  primeIdx &= 7;
  var key = 0;
  for (var i = 0; i < 256; i++) {
    key = (key + digest[i] + keyStream[i % 64]) % 256;
    final t = digest[i];
    digest[i] = digest[key];
    digest[key] = t;
  }
  final q = primes[primeIdx];
  var k = 0, n = 0, p = 0, xorKey = 0;
  final out = <int>[];
  for (final c in cipher) {
    k = (k + q) % 256;
    n = (p + digest[(n + digest[k]) % 256]) % 256;
    p = (p + k + digest[k]) % 256;
    final t = digest[k];
    digest[k] = digest[n];
    digest[n] = t;
    xorKey = digest[(n + digest[(k + digest[(xorKey + p) % 256]) % 256]) % 256];
    out.add((c ^ xorKey) & 0xff);
  }
  return latin1.decode(out);
}

MangaPage _nexusList(HtmlResponse res, {bool popularNow = false}) {
  final out = <SourceManga>[];
  for (final el in res.document.querySelectorAll('.container .column')) {
    final href = attrAbs(el.querySelector('a'), 'href', res.url);
    final title = clean(el.querySelector('.card-header-title')?.text);
    if (href == null || title.isEmpty) continue;
    out.add(SourceManga(url: href, title: title, thumbnailUrl: attrAbs(el.querySelector('.card-image img'), 'src', res.url)));
  }
  return MangaPage(out, hasNextPage: popularNow || res.document.querySelector('a.pagination-next[href]') != null);
}

Uri _nexusSearch(FnSource s, int page, String q) =>
    Uri.parse('${s.baseUrl}${page > 1 ? '/page/$page' : '/'}').replace(queryParameters: {'q': q.trim()});

FnSource _hentaiNexus() => FnSource(
      id: 'en.hentainexus',
      name: 'HentaiNexus',
      baseUrl: 'https://hentainexus.com',
      contentWarning: ContentWarning.nsfw,
      popularFn: (s, page) async {
        if (page > 1) return _nexusList(await s.fetchHtml(_nexusSearch(s, page - 1, 'sort:popular')));
        return _nexusList(await s.fetchHtml(Uri.parse('${s.baseUrl}/explore/hot')), popularNow: true);
      },
      latestFn: (s, page) async => _nexusList(await s.fetchHtml(Uri.parse(page > 1 ? '${s.baseUrl}/page/$page' : s.baseUrl))),
      searchFn: (s, page, q) async => _nexusList(await s.fetchHtml(_nexusSearch(s, page, q))),
      detailsFn: (s, url) async {
        final res = await s.fetchHtml(Uri.parse(url));
        final doc = res.document;
        final table = doc.querySelector('.view-page-details');
        String cell(String key) {
          for (final td in table?.querySelectorAll('td.viewcolumn').toList() ?? <Element>[]) {
            if (clean(td.text).contains(key)) {
              final next = td.nextElementSibling;
              final links = next?.querySelectorAll('a').map((e) => clean(ownText(e))).where((e) => e.isNotEmpty).join(', ') ?? '';
              final own = next == null ? '' : clean(ownText(next));
              return own.isNotEmpty ? own : links;
            }
          }
          return '';
        }

        final artist = cell('Artist');
        final circle = cell('Circle');
        var author = cell('Author');
        if (author.isEmpty) author = circle.isNotEmpty ? circle : artist;
        final desc = <String>[
          for (final k in ['Circle', 'Event', 'Magazine', 'Parody', 'Publisher', 'Pages', 'Favorites'])
            if (cell(k).isNotEmpty) '$k: ${cell(k)}',
        ];
        final about = cell('Description');
        final id = Uri.parse(url).pathSegments.last;
        return SourceMangaDetails(
          url: url,
          title: clean(doc.querySelector('h1.title')?.text),
          thumbnailUrl: attrAbs(doc.querySelector('figure.image img'), 'src', res.url),
          author: author,
          artist: artist,
          description: [desc.join('\n'), if (about.isNotEmpty) about].where((e) => e.isNotEmpty).join('\n\n'),
          genres: [
            for (final a in table?.querySelectorAll('span.tag a').toList() ?? <Element>[]) clean(a.text).replaceAll(RegExp(r'\s*\([\d,]+\)$'), ''),
          ],
          status: SourceMangaStatus.completed,
          chapters: [
            SourceChapter(url: '${s.baseUrl}/read/$id', name: 'Chapter', number: 1, uploadedAt: parseLooseDate(cell('Published'))),
          ],
        );
      },
      pagesFn: (s, ch) async {
        final res = await s.fetchHtml(Uri.parse(ch.url));
        String? script;
        for (final sc in res.document.querySelectorAll('script')) {
          if (sc.text.contains('initReader')) script = sc.text;
        }
        if (script == null) throw StateError('Skrip initReader tidak ditemukan.');
        final encoded = script.split('initReader("').last.split('",').first;
        final list = jsonDecode(_nexusDecrypt(encoded)) as List;
        return [
          for (final e in list.cast<Map>())
            if (e['type'] == 'image' && e['image_fallback'] != null) '${e['image_fallback']}',
        ];
      },
    );

List<MangaSource> portsX() => [_hentaiNexus()];
