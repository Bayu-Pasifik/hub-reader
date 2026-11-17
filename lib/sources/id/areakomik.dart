// Port Dart dari extension AreaKomik milik keiyoushi/extensions-source
// (Apache-2.0): src/id/areakomik.

import 'package:html/dom.dart';

import '../../core/i18n/strings.dart';
import '../filters.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class AreaKomikSource extends HttpSource {
  AreaKomikSource({super.dio});

  @override
  String get id => 'id.areakomik';
  @override
  String get name => 'Area Komik';
  @override
  String get lang => 'id';
  @override
  String get defaultBaseUrl => 'https://areakomik.com';
  @override
  ContentWarning get contentWarning => ContentWarning.nsfw;

  static const _card = 'article.komik-card:not(.native-ad-slot)';
  static const _synopsisIntro = 'adalah komik yang bisa kamu baca online';
  static const _synopsisOutro = 'Pilih chapter dari daftar di bawah untuk mulai membaca.';

  Uri _pageUrl(int page) => baseUri.replace(pathSegments: [
        if (page > 1) ...['page', '$page'],
        '',
      ]);

  Future<MangaPage> _list(Uri url, String selector) async {
    final res = await fetchHtml(url);
    final items = <SourceManga>[];
    for (final card in res.document.querySelectorAll(selector)) {
      final a = card.querySelector('h3.card-title a');
      final href = attrAbs(a, 'href', res.url);
      if (href == null) continue;
      items.add(SourceManga(
        url: href,
        title: clean(a!.text),
        thumbnailUrl: imgAttr(card.querySelector('img'), res.url),
      ));
    }
    return MangaPage(items, hasNextPage: res.document.querySelector('a.next.page-numbers') != null);
  }

  @override
  Future<MangaPage> popular(int page) => latest(page);

  @override
  Future<MangaPage> latest(int page) => _list(_pageUrl(page), '#lin-update-terbaru ~ .komik-grid $_card');

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) {
    final q = query.trim();
    if (q.isEmpty) return latest(page);
    // Halaman /page/N/ pada pencarian mengulang entri; hanya ?paged=N yang benar.
    return _list(baseUri.replace(queryParameters: {'s': q, if (page > 1) 'paged': '$page'}), _card);
  }

  String? _meta(Document doc, String label) {
    for (final item in doc.querySelectorAll('.meta-item')) {
      final strong = item.querySelector('strong');
      if (strong == null || !clean(strong.text).startsWith(label)) continue;
      final text = clean(item.text);
      final value = clean(text.substring(text.indexOf(':') + 1));
      if (value.isNotEmpty && value != '-') return value;
    }
    return null;
  }

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final res = await fetchHtml(Uri.parse(mangaUrl));
    final doc = res.document;
    final title = clean(doc.querySelector('h1')?.text);
    if (title.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Judul seri tidak ditemukan.'));
    }
    final synopsis = doc
        .querySelectorAll('#lin-sinopsis p')
        .map((p) => clean(p.text))
        .where((t) => t.isNotEmpty && !t.contains(_synopsisIntro) && t != _synopsisOutro)
        .join('\n\n');
    final alt = _meta(doc, 'Alternatif');
    final type = _meta(doc, 'Type');
    final chapters = <SourceChapter>[];
    for (final row in doc.querySelectorAll('#chapter-grid-container .chapter-row[data-num]')) {
      final href = attrAbs(row.querySelector('a.chapter-link'), 'href', res.url);
      if (href == null) continue;
      final num = clean(row.querySelector('.chap-num')?.text);
      final sub = clean(row.querySelector('.chap-title')?.text);
      final epoch = int.tryParse(row.attributes['data-date'] ?? '');
      chapters.add(SourceChapter(
        url: href,
        name: sub.isEmpty ? num : '$num - $sub',
        number: double.tryParse(row.attributes['data-num'] ?? '') ?? parseChapterNumber(num),
        uploadedAt: epoch == null ? null : DateTime.fromMillisecondsSinceEpoch(epoch * 1000),
      ));
    }
    return SourceMangaDetails(
      url: mangaUrl,
      title: title,
      thumbnailUrl: imgAttr(doc.querySelector('.series-thumb > img'), res.url),
      author: _meta(doc, 'Author'),
      description: [
        if (synopsis.isNotEmpty) synopsis,
        if (alt != null) trp('Judul alternatif:\n- {alt}', {'alt': alt}),
      ].join('\n\n'),
      genres: [
        for (final a in doc.querySelectorAll('.genre-list a.genre-tag')) clean(a.text),
        if (type != null) type,
      ],
      status: switch (_meta(doc, 'Status')?.toLowerCase()) {
        'ongoing' => SourceMangaStatus.ongoing,
        'completed' => SourceMangaStatus.completed,
        'hiatus' => SourceMangaStatus.hiatus,
        _ => SourceMangaStatus.unknown,
      },
      chapters: chapters,
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final res = await fetchHtml(Uri.parse(chapter.url));
    final pages = [
      for (final img in res.document.querySelectorAll('.chapter-content img.chapter-img'))
        if (imgAttr(img, res.url) case final u?) u,
    ];
    if (pages.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    }
    return pages;
  }
}
