import 'package:dio/dio.dart';

import '../../core/network/api_exception.dart';
import '../../core/utils/json.dart';
import '../models/series.dart';

/// Klien tipis untuk scraper-hub `/api/v1` (routes/api.php).
///
/// Mengembalikan JSON mentah; parsing ke model dilakukan repository supaya
/// respons yang sama bisa disimpan ke cache offline apa adanya.
///
/// Endpoint publik yang dipakai (semua wajib header X-Api-Key):
///   GET home                       → section beranda
///   GET genres                     → opsi filter genre & status
///   GET {novels|comics}            → daftar + pencarian (paginasi)
///   GET {novels|comics}/{id}       → detail seri
///   GET {novels|comics}/{id}/chapters?page=&per_page= (maks 500)
///
/// Endpoint auth:sanctum (library/history/progress di server) belum dipakai;
/// favorit & riwayat disimpan lokal di perangkat.
/// TODO(sync): bila nanti ingin sinkron antar-perangkat, tambahkan login
/// (POST auth/login → token Bearer) lalu panggil PUT library/{type}/{id} dan
/// POST {type}/{id}/progress dari FavoritesNotifier / HistoryNotifier.
class ScraperHubApi {
  ScraperHubApi(this._dio, {required this.hasApiKey});

  final Dio _dio;
  final bool hasApiKey;

  /// Batas per_page endpoint chapters di NovelController/ComicController.
  static const maxChaptersPerPage = 500;

  Future<JsonMap> home() => _get('home');

  Future<JsonMap> genres() => _get('genres');

  Future<JsonMap> listSeries(SeriesType type, Map<String, dynamic> query) =>
      _get(type.path, query: query);

  Future<JsonMap> series(SeriesType type, int id) => _get('${type.path}/$id');

  Future<JsonMap> chapters(
    SeriesType type,
    int id, {
    int page = 1,
    int perPage = maxChaptersPerPage,
  }) =>
      _get('${type.path}/$id/chapters', query: {'page': page, 'per_page': perPage});

  Future<JsonMap> _get(String path, {Map<String, dynamic>? query}) async {
    if (!hasApiKey) {
      throw const ApiException(ApiErrorKind.notConfigured);
    }
    try {
      final response = await _dio.get<Object?>(path, queryParameters: query);
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      // Mis. halaman HTML dari reverse proxy / alamat yang salah.
      throw const ApiException(ApiErrorKind.badResponse);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
