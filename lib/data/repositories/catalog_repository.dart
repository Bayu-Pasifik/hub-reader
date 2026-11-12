import 'dart:async';

import '../../core/network/api_exception.dart';
import '../../core/storage/json_cache.dart';
import '../../core/utils/json.dart';
import '../api/scraper_hub_api.dart';
import '../models/chapter.dart';
import '../models/chapter_content.dart';
import '../models/filter_options.dart';
import '../models/home_sections.dart';
import '../models/paginated.dart';
import '../models/series.dart';
import '../models/series_query.dart';

/// Hasil fetch + penanda apakah data berasal dari cache (mode offline).
class Fetched<T> {
  const Fetched(this.data, {this.cachedAt});

  final T data;

  /// Non-null = server tidak bisa dihubungi, ini data simpanan terakhir.
  final DateTime? cachedAt;

  bool get isFromCache => cachedAt != null;
}

/// Satu pintu untuk semua data katalog. Strategi: network first →
/// simpan ke cache → bila jaringan/server gagal, pakai cache.
class CatalogRepository {
  CatalogRepository(this._api, this._cache, {required String cacheNamespace})
      : _ns = cacheNamespace;

  final ScraperHubApi _api;
  final JsonCache _cache;

  /// Cache dipisah per base URL agar data dari server berbeda tidak tercampur.
  final String _ns;

  /// Pengaman: maksimal halaman bab yang diambil (500 × 40 = 20.000 bab).
  static const _maxChapterPages = 40;

  Future<Fetched<HomeSections>> home() =>
      _networkFirst('home', _api.home, HomeSections.fromJson);

  Future<Fetched<FilterOptions>> filterOptions() =>
      _networkFirst('genres', _api.genres, FilterOptions.fromJson);

  Future<Fetched<Paginated<Series>>> browse(
    SeriesType type,
    SeriesQuery query, {
    required int page,
    required int perPage,
  }) =>
      _networkFirst(
        'list:${type.path}:${query.cacheKey}:$page:$perPage',
        () => _api.listSeries(
          type,
          query.toQueryParameters(page: page, perPage: perPage),
        ),
        (json) => Paginated.fromJson(json, Series.tryParse),
      );

  Future<Fetched<Series>> series(SeriesType type, int id) => _networkFirst(
        'series:${type.path}:$id',
        () => _api.series(type, id),
        (json) => Series.fromJson(asMap(json['data'])),
      );

  /// Semua bab (urut naik), diambil per 500 lalu digabung. Daftar lengkap
  /// dibutuhkan reader untuk tombol bab sebelumnya/berikutnya.
  Future<Fetched<List<Chapter>>> chapters(SeriesType type, int id) => _networkFirst(
        'chapters:${type.path}:$id',
        () => _fetchAllChapterPages(type, id),
        (json) => asList(json['data'])
            .map((e) => Chapter.tryParse(asMap(e)))
            .whereType<Chapter>()
            .toList(growable: false),
      );

  /// TODO(scraper-hub): ganti dengan pemanggilan endpoint isi bab bila sudah
  /// tersedia (kontrak usulan ada di chapter_content.dart), contoh:
  ///   final json = await _api.chapterContent(type, id, number);
  ///   return ChapterContent.fromJson(json);
  /// Mengembalikan null = reader memakai WebView ke URL sumber.
  Future<ChapterContent?> chapterContent(
    SeriesType type,
    int id,
    double number,
  ) async =>
      null;

  Future<JsonMap> _fetchAllChapterPages(SeriesType type, int id) async {
    final all = <Object?>[];
    var page = 1;
    while (true) {
      final json = await _api.chapters(type, id, page: page);
      all.addAll(asList(json['data']));
      final meta = asMap(json['meta']);
      final lastPage = asInt(meta['last_page']) ?? page;
      if (page >= lastPage || page >= _maxChapterPages) break;
      page++;
    }
    return {'data': all};
  }

  Future<Fetched<T>> _networkFirst<T>(
    String key,
    Future<JsonMap> Function() fetch,
    T Function(JsonMap json) parse,
  ) async {
    final cacheKey = '$_ns|$key';
    try {
      final json = await fetch();
      // Parse dulu: respons rusak tidak boleh menimpa cache yang baik.
      final parsed = parse(json);
      unawaited(_cache.write(cacheKey, json));
      return Fetched(parsed);
    } catch (error) {
      final apiError = toApiException(error);
      if (apiError.canFallBackToCache) {
        final cached = await _cache.read(cacheKey);
        if (cached != null) {
          try {
            return Fetched(parse(cached.data), cachedAt: cached.savedAt);
          } catch (_) {
            // Cache lama tidak cocok dengan model sekarang; lempar error asli.
          }
        }
      }
      throw apiError;
    }
  }
}
