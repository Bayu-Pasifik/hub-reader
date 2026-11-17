// Port Dart dari extension KomikAV milik keiyoushi/extensions-source
// (Apache-2.0): src/id/komikav.

import 'package:html/dom.dart';

import '../../core/i18n/strings.dart';
import '../filters.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class KomikAvSource extends HttpSource {
  KomikAvSource({super.dio});

  @override
  String get id => 'id.komikav';
  @override
  String get name => 'Komik AV';
  @override
  String get lang => 'id';
  @override
  String get defaultBaseUrl => 'https://komikav.net';
  @override
  ContentWarning get contentWarning => ContentWarning.mixed;

  static const _perSitePage = 18;

  /// "Muat lebih banyak" situs mengembalikan halaman 1..N sekaligus untuk
  /// `?page=N`, jadi bagian yang sudah tampil dibuang.
  Future<MangaPage> _list(String path, int page) async {
    final res = await fetchHtml(Uri.parse('$baseUrl$path').replace(queryParameters: {'page': '$page'}));
    final seen = <String>{};
    final all = <SourceManga>[];
    for (final a in res.document.querySelectorAll('a[href^="/manga/"]')) {
      final img = a.querySelector('img.lazyimage');
      final href = attrAbs(a, 'href', res.url);
      if (img == null || href == null || !seen.add(href)) continue;
      all.add(SourceManga(
        url: href,
        title: clean(img.attributes['alt']),
        thumbnailUrl: attrAbs(img, 'data-src', res.url) ?? imgAttr(img, res.url),
      ));
    }
    final skip = (page - 1) * _perSitePage;
    final items = skip >= all.length ? <SourceManga>[] : all.sublist(skip);
    return MangaPage(items, hasNextPage: all.length >= page * _perSitePage);
  }

  @override
  Future<MangaPage> popular(int page) => _list('/popular/', page);

  @override
  Future<MangaPage> latest(int page) => _list('/', page);

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) {
    final q = query.trim();
    return _list(q.isEmpty ? '/comic-list/' : '/search/${Uri.encodeComponent(q)}/', page);
  }

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    final doc = res.document;
    final title = clean(doc.querySelector('h1.font-kghappy')?.text);
    if (title.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Judul seri tidak ditemukan.'));
    }
    final authors = <String>[];
    for (final p in doc.querySelectorAll('p')) {
      if (ownText(p) == 'Author') {
        var sib = p.nextElementSibling;
        while (sib != null) {
          if (sib.localName == 'p') authors.add(clean(sib.text));
          sib = sib.nextElementSibling;
        }
        break;
      }
    }
    final type = clean(doc.querySelector('div.rounded-l-full')?.text);
    final chapters = <SourceChapter>[];
    for (final a in doc.querySelectorAll('div.overflow-y-auto > a[href*="/chapter-"]')) {
      final href = attrAbs(a, 'href', res.url);
      final name = clean(a.querySelector('p')?.text);
      if (href == null) continue;
      chapters.add(SourceChapter(
        url: href,
        name: name,
        number: parseChapterNumber(name),
        uploadedAt: _relative(clean(a.querySelector('p.text-xs')?.text)),
      ));
    }
    return SourceMangaDetails(
      url: mangaUrl,
      title: title,
      thumbnailUrl: doc.querySelector('meta[property="og:image"]')?.attributes['content'],
      author: authors.isEmpty ? null : authors.join(', '),
      description: clean(doc.querySelector('div.mt-4.w-full > p')?.text.replaceAll('&#x20;', '')),
      genres: [
        if (type.isNotEmpty) type,
        for (final Element a in doc.querySelectorAll('a[href^="/tax/genre/"]')) clean(a.text),
      ],
      status: switch (clean(doc.querySelector('div.rounded-r-full')?.text).toLowerCase()) {
        'on-going' => SourceMangaStatus.ongoing,
        'end' => SourceMangaStatus.completed,
        _ => SourceMangaStatus.unknown,
      },
      chapters: chapters,
    );
  }

  /// Teks "3 jam lalu" milik situs; "bln" = 4 minggu, "thn" = 48 minggu.
  DateTime? _relative(String text) {
    final parts = text.split(' ');
    final v = int.tryParse(parts.first);
    if (v == null || parts.length < 2) return null;
    final d = switch (parts[1]) {
      'dtk' => Duration(seconds: v),
      'mnt' => Duration(minutes: v),
      'jam' => Duration(hours: v),
      'hari' => Duration(days: v),
      'mgg' => Duration(days: v * 7),
      'bln' => Duration(days: v * 28),
      'thn' => Duration(days: v * 336),
      _ => null,
    };
    return d == null ? null : DateTime.now().subtract(d);
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    final pages = [
      for (final img in res.document.querySelectorAll('img.imgku'))
        if (!img.classes.contains('langsungload') && attrAbs(img, 'src', res.url) != null) attrAbs(img, 'src', res.url)!,
    ];
    if (pages.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    }
    return pages;
  }
}
