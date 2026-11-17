// Sumber berbasis fungsi: perilaku (daftar, cari, detail, halaman) diberikan
// lewat closure. Dipakai situs katalog dinamis dari keiyoushi/extensions-source
// (Apache-2.0) yang terlalu kecil untuk punya kelas sendiri.

import 'dart:convert';

import 'package:dio/dio.dart';

import '../filters.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

typedef ListFn = Future<MangaPage> Function(FnSource s, int page);
typedef SearchFn = Future<MangaPage> Function(FnSource s, int page, String query);
typedef DetailsFn = Future<SourceMangaDetails> Function(FnSource s, String url);
typedef PagesFn = Future<List<String>> Function(FnSource s, SourceChapter chapter);

class FnSource extends HttpSource {
  FnSource({
    required this.id,
    required this.name,
    required String baseUrl,
    required this.popularFn,
    required this.searchFn,
    required this.detailsFn,
    required this.pagesFn,
    this.latestFn,
    this.contentWarning = ContentWarning.safe,
    this.lang = 'en',
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
  @override
  bool get supportsLatest => latestFn != null;

  final ListFn popularFn;
  final ListFn? latestFn;
  final SearchFn searchFn;
  final DetailsFn detailsFn;
  final PagesFn pagesFn;

  @override
  Future<MangaPage> popular(int page) => popularFn(this, page);

  @override
  Future<MangaPage> latest(int page) => latestFn!(this, page);

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) {
    final q = query.trim();
    return q.isEmpty ? popularFn(this, page) : searchFn(this, page, q);
  }

  @override
  Future<SourceMangaDetails> details(String mangaUrl) => detailsFn(this, mangaUrl);

  @override
  Future<List<String>> pages(SourceChapter chapter) => pagesFn(this, chapter);

  /// POST form (urlencoded) dengan balasan JSON.
  Future<Object?> postFormJson(Uri url, Map<String, String> form) async {
    try {
      final res = await dio.postUri<String>(
        url,
        data: form,
        options: Options(contentType: Headers.formUrlEncodedContentType, headers: {'Accept': 'application/json'}),
      );
      return jsonDecode(res.data ?? 'null');
    } catch (error) {
      throw toSourceException(error);
    }
  }
}
