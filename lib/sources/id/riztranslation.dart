// Port Dart dari extension Riztranslation milik keiyoushi/extensions-source
// (Apache-2.0): src/id/riztranslation. Backend Supabase (kunci anon publik).

import 'dart:convert';

import '../../core/i18n/strings.dart';
import '../../core/utils/json.dart';
import '../filters.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class RiztranslationSource extends HttpSource {
  RiztranslationSource({super.dio});

  @override
  String get id => 'id.riztranslation';
  @override
  String get name => 'Riztranslation';
  @override
  String get lang => 'id';
  @override
  String get defaultBaseUrl => 'https://riztranslation.pages.dev';
  @override
  ContentWarning get contentWarning => ContentWarning.safe;

  static const _api = 'https://uefnaojxivvxeamljskn.supabase.co/rest/v1';
  static const _key =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVlZm5hb2p4aXZ2eGVhbWxqc2tuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc3MTU5MjksImV4cCI6MjA2MzI5MTkyOX0._lEBN5puTvATwtYodg4zbcoTwg0ss3j2BebD8WoHt9A';

  Future<List<Object?>> _get(Map<String, String> query) async => asList(await fetchJson(
        Uri.parse('$_api/${query.remove('_table')}').replace(queryParameters: query),
        headers: {'apikey': _key},
      ));

  SourceManga _manga(JsonMap m) => SourceManga(
        url: '$baseUrl/detail/${m['id']}',
        title: clean(asString(m['judul'])),
        thumbnailUrl: asString(m['cover']),
      );

  Future<MangaPage> _books(int page, {String? query}) async {
    final list = await _get({
      '_table': 'Book',
      'select': 'id,judul,cover',
      'type': 'not.ilike.*novel*',
      if (query != null && query.isNotEmpty) 'judul': 'ilike.*$query*',
      'order': 'id.desc',
      'offset': '${(page - 1) * 20}',
      'limit': '20',
    });
    return MangaPage([for (final b in list) _manga(asMap(b))], hasNextPage: list.length == 20);
  }

  @override
  Future<MangaPage> popular(int page) => _books(page);

  @override
  Future<MangaPage> latest(int page) async {
    final list = await _get({
      '_table': 'Chapter',
      'select': 'bookId,Book!inner(id,judul,cover)',
      'Book.type': 'not.ilike.*novel*',
      'order': 'created_at.desc',
      'offset': '${(page - 1) * 30}',
      'limit': '30',
    });
    final seen = <int>{};
    final items = <SourceManga>[];
    for (final c in list) {
      final book = asMap(asMap(c)['Book']);
      final bid = asInt(book['id']);
      if (bid != null && seen.add(bid)) items.add(_manga(book));
    }
    return MangaPage(items, hasNextPage: list.length == 30);
  }

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) =>
      _books(page, query: query.trim());

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final bookId = Uri.parse(mangaUrl).pathSegments.where((s) => s.isNotEmpty).last;
    final books = await _get({
      '_table': 'Book',
      'select': '*,genres:_BookGenre(genre:Genre(*))',
      'type': 'not.ilike.*novel*',
      'id': 'eq.$bookId',
    });
    if (books.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Judul seri tidak ditemukan.'));
    }
    final b = asMap(books.first);
    final rows = await _get({
      '_table': 'Chapter',
      'select': 'id,bookId,chapter,nama,created_at',
      'bookId': 'eq.$bookId',
      'order': 'chapter.desc',
    });
    final chapters = <SourceChapter>[];
    for (final r in rows) {
      final c = asMap(r);
      final n = asDouble(c['chapter']);
      final nama = asString(c['nama']);
      final numText = n == null ? null : (n == n.roundToDouble() ? '${n.toInt()}' : '$n');
      final name = [
        if (numText != null) 'Chapter $numText',
        if (nama != null && nama.trim().isNotEmpty) nama.trim(),
      ].join(' - ');
      chapters.add(SourceChapter(
        url: '$baseUrl/view/$bookId/${c['id']}',
        name: name.isEmpty ? tr('Bab') : name,
        number: n,
        uploadedAt: DateTime.tryParse(asString(c['created_at']) ?? ''),
      ));
    }
    return SourceMangaDetails(
      url: mangaUrl,
      title: clean(asString(b['judul'])),
      thumbnailUrl: asString(b['cover']),
      author: asString(b['author']),
      artist: asString(b['artist']),
      description: asString(b['synopsis']),
      genres: [
        for (final g in asList(b['genres']))
          if (asString(asMap(asMap(g)['genre'])['nama']) case final n?) n,
      ],
      status: switch (asString(b['status'])?.toLowerCase()) {
        'completed' || 'complete' || 'oneshot' => SourceMangaStatus.completed,
        'ongoing' => SourceMangaStatus.ongoing,
        _ => SourceMangaStatus.unknown,
      },
      chapters: chapters,
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    final chapterId = Uri.parse(chapter.url).pathSegments.where((s) => s.isNotEmpty).last;
    final rows = await _get({
      '_table': 'Chapter',
      'select': 'id,bookId,isigambar',
      'id': 'eq.$chapterId',
    });
    final raw = rows.isEmpty ? null : asString(asMap(rows.first)['isigambar']);
    var images = <String>[];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        images = asStringList(jsonDecode(raw));
      } on FormatException {
        images = const [];
      }
    }
    if (images.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
    }
    return images;
  }
}
