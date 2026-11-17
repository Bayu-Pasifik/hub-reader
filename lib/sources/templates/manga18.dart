// Port Dart dari template Manga18 milik keiyoushi/extensions-source
// (Apache-2.0): lib-multisrc/manga18.
//
// Situs HTML: daftar `/list-manga/<n>` (urut `?order_by=views`), tag `/manga-list/<tag>/<n>`,
// detail & bab di satu halaman `/manhwa/<slug>`, gambar bab dalam skrip
// `slides_p_path` (daftar URL ber-base64).

import 'dart:convert';

import 'package:html/dom.dart';

import '../../core/i18n/strings.dart';
import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class Manga18Source extends HttpSource {
  Manga18Source({
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

  /// Filter tag tidak berfungsi di sebagian situs (mis. HANMAN18).
  bool get getAvailableTags => vals['getAvailableTags'] != false;

  // =========================== Daftar ===========================

  @override
  Future<MangaPage> popular(int page) => _list('$baseUrl/list-manga/$page?order_by=views');

  @override
  Future<MangaPage> latest(int page) => _list('$baseUrl/list-manga/$page');

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) {
    final tag = filters.single('tag');
    if (query.trim().isNotEmpty || tag == null || tag.isEmpty) {
      return _list(Uri.parse('$baseUrl/list-manga/$page').replace(queryParameters: {'search': query.trim()}).toString());
    }
    final sort = filters.single('sort');
    return _list(Uri.parse('$baseUrl/manga-list/$tag/$page')
        .replace(queryParameters: {if (sort != null) 'order_by': sort}).toString());
  }

  Future<MangaPage> _list(String url) async {
    final res = await fetchHtml(Uri.parse(url));
    return parseList(res.document, res.url);
  }

  MangaPage parseList(Document doc, Uri base) {
    final items = <SourceManga>[];
    for (final el in doc.querySelectorAll('div.story_item')) {
      final url = absUrl(base, el.querySelector('a')?.attributes['href']);
      final title = clean(el.querySelector('div.mg_info > div.mg_name a')?.text);
      if (url == null || title.isEmpty) continue;
      items.add(SourceManga(url: url, title: title, thumbnailUrl: attrAbs(el.querySelector('img'), 'src', base)));
    }
    final next = doc.querySelector('.pagination > li:last-child:not(.active)');
    return MangaPage(items, hasNextPage: next != null);
  }

  // =========================== Filter ===========================

  @override
  Future<List<FilterDef>> filters() async {
    if (!getAvailableTags) return const [];
    try {
      final res = await fetchHtml(Uri.parse('$baseUrl/list-manga/1'));
      final tags = [
        for (final a in res.document.querySelectorAll('div.grid_cate li > a'))
          if (clean(a.text).isNotEmpty && (a.attributes['href'] ?? '').isNotEmpty)
            FilterOption(
              clean(a.text),
              (a.attributes['href']!.replaceFirst(RegExp(r'/+$'), '').split('/').last),
            ),
      ];
      return [
        const SelectFilterDef('sort', 'Sort (ignored with text search)', [
          FilterOption('Latest', ''),
          FilterOption('Views', 'views'),
          FilterOption('A-Z', 'name'),
        ]),
        if (tags.isNotEmpty) SelectFilterDef('tag', 'Tags (ignored with text search)', [const FilterOption('', ''), ...tags]),
      ];
    } catch (_) {
      return const [];
    }
  }

  // =========================== Detail ===========================

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    return parseDetails(res.document, res.url);
  }

  static String? _value(Element info, String labelSelector, List<String> labels) {
    for (final label in whereContains(info, labelSelector, labels)) {
      final value = label.nextElementSibling;
      if (value != null && value.classes.contains('info_value')) {
        final v = clean(value.text);
        return v.isEmpty || v == 'Updating' ? null : v;
      }
    }
    return null;
  }

  SourceMangaDetails parseDetails(Document doc, Uri base) {
    final info = doc.querySelector('div.detail_listInfo');
    if (info == null) throw SourceException(SourceErrorKind.parse, detail: tr('Detail seri tidak ditemukan.'));

    final description = doc
        .querySelectorAll('div.detail_reviewContent')
        .map((e) => clean(e.text))
        .where((t) => t.isNotEmpty)
        .join('\n\n');
    String? alt;
    for (final item in whereContains(info, 'div.item', ['other name'])) {
      final v = clean(item.querySelector('div.info_value')?.text);
      if (v.isNotEmpty && v != 'Updating') alt = v;
    }
    String? status;
    for (final item in whereContains(info, 'div.item', ['status'])) {
      status = clean(item.querySelector('div.info_value')?.text);
    }

    final chapters = <SourceChapter>[];
    for (final el in doc.querySelectorAll('div.chapter_box .item')) {
      final link = el.querySelector('a');
      final url = absUrl(base, link?.attributes['href']);
      final name = clean(link?.text);
      if (url == null || name.isEmpty) continue;
      chapters.add(SourceChapter(
        url: url,
        name: name,
        number: parseChapterNumber(name),
        uploadedAt: parseLooseDate(el.querySelector('p')?.text),
      ));
    }

    return SourceMangaDetails(
      url: base.toString(),
      title: clean(doc.querySelector('div.detail_name > h1')?.text),
      thumbnailUrl: attrAbs(doc.querySelector('div.detail_avatar > img'), 'src', base),
      author: _value(info, 'div.info_label', ['author', 'autor']),
      artist: _value(info, 'div.info_label', ['artist']),
      description: [if (description.isNotEmpty) description, if (alt != null) 'Alternative Names:\n$alt'].join('\n\n').nullIfEmpty,
      genres: [
        for (final a in info.querySelectorAll('div.info_value > a[href*="/manga-list/"]'))
          if (clean(a.text).isNotEmpty) clean(a.text),
      ],
      status: switch (status) {
        'On Going' => SourceMangaStatus.ongoing,
        'Completed' => SourceMangaStatus.completed,
        _ => SourceMangaStatus.unknown,
      },
      chapters: chapters,
    );
  }

  // =========================== Halaman ===========================

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    return parsePages(res.document, res.url);
  }

  List<String> parsePages(Document doc, Uri base) {
    final script = doc.querySelectorAll('script').where((s) => s.text.contains('slides_p_path')).firstOrNull;
    if (script == null) throw SourceException(SourceErrorKind.parse, detail: tr('Daftar gambar tidak terbaca.'));
    final data = script.text;
    final start = data.indexOf('[');
    final end = data.indexOf(',]', start);
    if (start < 0) throw SourceException(SourceErrorKind.parse, detail: tr('Daftar gambar tidak terbaca.'));
    final encoded = data.substring(start + 1, end < 0 ? data.indexOf(']', start) : end).replaceAll('"', '').split(',');
    final out = <String>[];
    for (final e in encoded) {
      if (e.trim().isEmpty) continue;
      final url = utf8.decode(base64.decode(base64.normalize(e.trim())), allowMalformed: true);
      out.add(url.startsWith('/') ? '$baseUrl$url' : url);
    }
    if (out.isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    return out;
  }
}

extension on String {
  String? get nullIfEmpty => trim().isEmpty ? null : trim();
}
