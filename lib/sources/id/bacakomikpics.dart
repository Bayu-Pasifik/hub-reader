// Port Dart dari extension BacaKomik.pics milik keiyoushi/extensions-source
// (Apache-2.0): src/id/bacakomikpics. Daftar dari wp-json `komik_series`.

import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' show parseFragment;

import '../../core/i18n/strings.dart';
import '../../core/utils/json.dart';
import '../filters.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class BacaKomikPicsSource extends HttpSource {
  BacaKomikPicsSource({super.dio});

  @override
  String get id => 'id.bacakomikpics';
  @override
  String get name => 'BacaKomik.pics';
  @override
  String get lang => 'id';
  @override
  String get defaultBaseUrl => 'https://bacakomik.pics';
  @override
  ContentWarning get contentWarning => ContentWarning.nsfw;

  static final _chapterData = RegExp(r'chapterData\s*=\s*(\[.*?\]);', dotAll: true);

  @override
  Future<MangaPage> popular(int page) async {
    final res = await fetchHtml(baseUri.replace(path: '/komik-populer/'));
    final items = <SourceManga>[];
    for (final card in res.document.querySelectorAll('.grid a.card')) {
      final href = attrAbs(card, 'href', res.url);
      if (href == null) continue;
      items.add(SourceManga(
        url: href,
        title: clean(card.querySelector('.card-title')?.text),
        thumbnailUrl: attrAbs(card.querySelector('img'), 'src', res.url),
      ));
    }
    return MangaPage(items, hasNextPage: false);
  }

  Future<MangaPage> _series(int page, {String? query, String orderBy = 'modified'}) async {
    final list = asList(await fetchJson(baseUri.replace(path: '/wp-json/wp/v2/komik_series', queryParameters: {
      'per_page': '20',
      'page': '$page',
      '_embed': 'wp:featuredmedia',
      if (query != null) 'search': query,
      'orderby': orderBy,
      'order': 'desc',
    })));
    final items = <SourceManga>[
      for (final s in list)
        () {
          final m = asMap(s);
          final link = asString(m['link']) ?? '';
          final media = asList(asMap(m['_embedded'])['wp:featuredmedia']);
          return SourceManga(
            url: link,
            title: clean(parseFragment(asString(asMap(m['title'])['rendered']) ?? '').text),
            thumbnailUrl: media.isEmpty ? null : asString(asMap(media.first)['source_url']),
          );
        }(),
    ];
    return MangaPage(items, hasNextPage: list.length == 20);
  }

  @override
  Future<MangaPage> latest(int page) => _series(page);

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) =>
      _series(page, query: query.trim().isEmpty ? null : query.trim(), orderBy: 'relevance');

  String? _field(Element synopsis, String label) {
    for (final strong in synopsis.querySelectorAll('strong')) {
      if (!clean(strong.text).startsWith(label)) continue;
      final buf = StringBuffer();
      final siblings = strong.parent?.nodes ?? const <Node>[];
      for (var i = siblings.indexOf(strong) + 1; i < siblings.length; i++) {
        final n = siblings[i];
        if (n is Element && n.localName == 'strong') break;
        if (n is Text) buf.write(n.text);
      }
      final v = clean(buf.toString());
      if (v.isNotEmpty) return v;
    }
    return null;
  }

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    final doc = res.document;
    final info = doc.querySelector('.series-info');
    final title = clean(info?.querySelector('h1')?.text);
    if (info == null || title.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Judul seri tidak ditemukan.'));
    }
    final syn = info.querySelector('.sinopsis p');
    final alt = syn == null ? null : _field(syn, 'Alternatif');
    final desc = syn == null ? null : _field(syn, 'Sinopsis');
    final chapters = <SourceChapter>[];
    final json = _chapterData.firstMatch(res.body)?.group(1);
    if (json != null) {
      try {
        for (final c in asList(jsonDecode(json))) {
          final m = asMap(c);
          final url = asString(m['url']);
          final name = asString(m['title']);
          if (url == null || name == null) continue;
          chapters.add(SourceChapter(url: absUrl(res.url, url) ?? url, name: name, number: parseChapterNumber(name)));
        }
      } on FormatException {
        // daftar bab kosong
      }
    }
    return SourceMangaDetails(
      url: mangaUrl,
      title: title,
      thumbnailUrl: attrAbs(doc.querySelector('.series-thumb img.thumb'), 'src', res.url),
      author: syn == null ? null : _field(syn, 'Author'),
      description: [
        if (desc != null) desc,
        if (alt != null) trp('Judul alternatif:\n- {alt}', {'alt': alt}),
      ].join('\n\n'),
      genres: [for (final a in info.querySelectorAll('a.genre-link')) clean(a.text)],
      status: switch ((syn == null ? null : _field(syn, 'Status'))?.toLowerCase()) {
        'ongoing' => SourceMangaStatus.ongoing,
        'completed' => SourceMangaStatus.completed,
        _ => SourceMangaStatus.unknown,
      },
      chapters: chapters.reversed.toList(),
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    final pages = [
      for (final img in res.document.querySelectorAll('.viewer-komik img[data-wm]'))
        if (attrAbs(img, 'src', res.url) case final u?) u,
    ];
    if (pages.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    }
    return pages;
  }
}
