// Port Dart dari extension Bacami milik keiyoushi/extensions-source
// (Apache-2.0): src/id/bacami.

import 'dart:convert';

import 'package:html/dom.dart';

import '../../core/i18n/strings.dart';
import '../filters.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class BacamiSource extends HttpSource {
  BacamiSource({super.dio});

  @override
  String get id => 'id.bacami';
  @override
  String get name => 'Bacami';
  @override
  String get lang => 'id';
  @override
  String get defaultBaseUrl => 'https://v1.bacami.site';
  @override
  ContentWarning get contentWarning => ContentWarning.safe;

  String? _img(Element? img, Uri base) => attrAbs(img, 'data-src', base) ?? attrAbs(img, 'src', base);

  Future<MangaPage> _list(String path, int page) async {
    final res = await fetchHtml(Uri.parse('$baseUrl/$path${page > 1 ? '/page/$page' : ''}'));
    final items = <SourceManga>[];
    for (final el in res.document.querySelectorAll('article.genre-card')) {
      final link = el.querySelector('div.genre-cover > a');
      final href = attrAbs(link, 'href', res.url);
      if (link == null || href == null) continue;
      items.add(SourceManga(
        url: href,
        title: clean(el.querySelector('div.genre-info > a')?.text),
        thumbnailUrl: _img(link.querySelector('img'), res.url),
      ));
    }
    return MangaPage(items, hasNextPage: res.document.querySelector('div.paginate a.next.page-numbers') != null);
  }

  @override
  Future<MangaPage> popular(int page) => _list('custom-search/orderby/score', page);

  @override
  Future<MangaPage> latest(int page) => _list('custom-search/orderby/latest', page);

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) {
    final q = query.trim();
    return q.isEmpty ? latest(page) : _list('search/${Uri.encodeComponent(q)}', page);
  }

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    final doc = res.document;
    final content = doc.querySelector('#komik > section.manga-content');
    final title = clean(content?.querySelector('header > h1')?.text.replaceAll('Bahasa Indonesia', ''));
    if (content == null || title.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Judul seri tidak ditemukan.'));
    }
    String? author;
    for (final item in content.querySelectorAll('.info-item')) {
      if (clean(item.text).startsWith('Author')) {
        author = clean(item.querySelector('.info-value')?.text);
        break;
      }
    }
    final alt = clean(content.querySelector('p.manga-altname')?.text);
    final desc = clean(content.querySelector('p.manga-description')?.text);
    final chapters = <SourceChapter>[];
    for (final li in doc.querySelectorAll('ol.chapter-list > li')) {
      final a = li.querySelector('a.ch-link');
      final href = attrAbs(a, 'href', res.url);
      if (a == null || href == null) continue;
      final raw = clean(a.text);
      final tail = raw.contains('–') ? raw.split('–').last : (raw.contains('-') ? raw.split('-').last : raw);
      final name = clean(tail).isEmpty ? raw : clean(tail);
      chapters.add(SourceChapter(
        url: href,
        name: name,
        number: parseChapterNumber(name),
        uploadedAt: parseLooseDate(clean(li.querySelector('span.ch-date')?.text)),
      ));
    }
    return SourceMangaDetails(
      url: mangaUrl,
      title: title,
      thumbnailUrl: _img(content.querySelector('figure .image-wrap img'), res.url),
      author: (author == null || author.isEmpty) ? null : author,
      description: [
        if (desc.isNotEmpty) desc,
        if (alt.isNotEmpty) trp('Judul alternatif:\n- {alt}', {'alt': alt}),
      ].join('\n\n'),
      genres: [for (final a in content.querySelectorAll('nav > span > a')) clean(a.text)],
      status: doc.querySelector('.hot-tag, .project-tag') != null
          ? SourceMangaStatus.ongoing
          : doc.querySelector('.tamat-tag') != null
              ? SourceMangaStatus.completed
              : SourceMangaStatus.unknown,
      chapters: chapters,
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    for (final s in res.document.querySelectorAll('script')) {
      final text = s.text;
      final i = text.indexOf('imageUrls:');
      if (i < 0) continue;
      final rest = text.substring(i + 'imageUrls:'.length);
      final end = rest.indexOf('],');
      if (end < 0) continue;
      try {
        final list = jsonDecode('${rest.substring(0, end)}]') as List;
        final pages = [
          for (final u in list)
            if (absUrl(res.url, '$u') case final a?) a,
        ];
        if (pages.isNotEmpty) return pages;
      } on FormatException {
        continue;
      }
    }
    throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
  }
}
