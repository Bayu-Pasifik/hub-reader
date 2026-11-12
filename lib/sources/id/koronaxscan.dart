// Port Dart dari extension KoronaxScan milik keiyoushi/extensions-source
// (Apache-2.0): src/id/koronaxscan.

import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

/// Situs tanpa daftar berhalaman: semua judul diambil sekali dari API lalu
/// diurutkan/dicari di sisi klien (sama dengan Kotlin).
class KoronaxScanSource extends HttpSource {
  KoronaxScanSource({super.dio});

  @override
  String get id => 'id.koronaxscan';
  @override
  String get name => 'KoronaxScan';
  @override
  String get lang => 'id';
  @override
  String get defaultBaseUrl => 'https://project.koronaxscan.my.id';
  @override
  ContentWarning get contentWarning => ContentWarning.mixed;

  static const api = 'https://asw.koronaxscan.my.id';

  static String image(String url) => url.startsWith('/') ? '$api$url' : url;

  Future<List<JsonMap>> _all() async {
    final json = asMap(await fetchJson(Uri.parse('$api/api/mangas')));
    return [
      for (final m in asList(json['data']))
        // Hanya judul proyek yang tersedia untuk semua (seperti situsnya).
        if (asMap(m)['project'] == true && (asString(asMap(m)['available']) ?? 'all') == 'all') asMap(m),
    ];
  }

  SourceManga _manga(JsonMap m) => SourceManga(
        url: '$baseUrl/detail/${m['slug']}',
        title: clean(asString(m['title'])),
        thumbnailUrl: asString(m['cover_image_url']) == null ? null : image(asString(m['cover_image_url'])!),
      );

  static String _latestAt(JsonMap m) => asList(m['chapters'])
      .map((c) => asString(asMap(c)['createdAt']) ?? '')
      .fold('', (a, b) => b.compareTo(a) > 0 ? b : a);

  @override
  Future<MangaPage> popular(int page) async {
    final all = await _all()
      ..sort((a, b) => (double.tryParse('${b['rating']}') ?? 0).compareTo(double.tryParse('${a['rating']}') ?? 0));
    return MangaPage(all.map(_manga).toList(), hasNextPage: false);
  }

  @override
  Future<MangaPage> latest(int page) async {
    final all = await _all()
      ..sort((a, b) => _latestAt(b).compareTo(_latestAt(a)));
    return MangaPage(all.map(_manga).toList(), hasNextPage: false);
  }

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    final q = query.trim().toLowerCase();
    final all = await _all();
    return MangaPage([
      for (final m in all)
        if ((asString(m['title']) ?? '').toLowerCase().contains(q) ||
            (asString(m['title_alt']) ?? '').toLowerCase().contains(q))
          _manga(m),
    ], hasNextPage: false);
  }

  static String _slug(String url) => Uri.parse(url).pathSegments.where((s) => s.isNotEmpty).elementAt(1);

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final slug = _slug(mangaUrl);
    final m = asMap(asMap(await fetchJson(Uri.parse('$api/api/mangas/$slug')))['data']);
    final alt = asString(m['title_alt'])?.trim();
    final desc = asString(m['description'])?.trim();
    return SourceMangaDetails(
      url: mangaUrl,
      title: clean(asString(m['title'])),
      thumbnailUrl: asString(m['cover_image_url']) == null ? null : image(asString(m['cover_image_url'])!),
      author: nonPlaceholder(asString(m['author'])),
      artist: nonPlaceholder(asString(m['artist'])),
      description: [
        if (desc != null && desc.isNotEmpty) desc,
        if (alt != null && alt.isNotEmpty) 'Judul alternatif:\n- $alt'
      ].join('\n\n'),
      genres: [
        if (asString(m['type']) case final t?) t,
        for (final g in asList(m['genres']))
          if (asString(asMap(g)['name']) case final n?) n,
      ],
      status: switch (asString(m['status'])?.toLowerCase()) {
        'ongoing' => SourceMangaStatus.ongoing,
        'completed' => SourceMangaStatus.completed,
        'hiatus' => SourceMangaStatus.hiatus,
        _ => SourceMangaStatus.unknown,
      },
      chapters: [
        for (final c in asList(m['chapters'])) _chapter(asMap(c), slug),
      ]..sort((a, b) => (b.number ?? 0).compareTo(a.number ?? 0)),
    );
  }

  SourceChapter _chapter(JsonMap c, String slug) {
    final n = asDouble(c['chapter_number']) ?? 0;
    final text = n == n.roundToDouble() ? '${n.toInt()}' : '$n';
    final premium = c['isPremium'] == true;
    return SourceChapter(
      url: '$baseUrl/reader/$slug/$text',
      name: '${premium ? '🔒 ' : ''}Chapter $text',
      number: n,
      uploadedAt: DateTime.tryParse(asString(c['createdAt']) ?? '')?.toLocal(),
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final segs = Uri.parse(chapter.url).pathSegments.where((s) => s.isNotEmpty).toList();
    final json = asMap(await fetchJson(Uri.parse('$api/api/mangas/${segs[1]}/chapter/${segs[2]}')));
    final pages = [
      for (final p in asList(json['pages']))
        if (asString(asMap(p)['image_url']) case final u?) image(u),
    ];
    if (pages.isEmpty) {
      throw const SourceException(SourceErrorKind.parse, detail: 'Gambar tidak ditemukan (bab premium?).');
    }
    return pages;
  }
}
