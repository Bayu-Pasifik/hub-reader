import 'dart:io';

import 'package:dio/dio.dart';

/// Kategori error yang dibedakan oleh UI.
enum ApiErrorKind {
  /// API key belum diisi (semua endpoint /api/v1 wajib header X-Api-Key).
  notConfigured,
  noConnection,
  timeout,

  /// 401/403, mis. "Missing or invalid API key."
  unauthorized,
  notFound,

  /// 422 dari FormRequest Laravel (mis. sort / per_page tidak valid).
  validation,

  /// 429 dari middleware throttle:api.
  rateLimited,
  server,

  /// Respons bukan JSON atau bentuknya tidak sesuai model.
  badResponse,
  cancelled,
  unknown,
}

/// Satu-satunya tipe error yang keluar dari lapisan data.
class ApiException implements Exception {
  const ApiException(this.kind, {this.statusCode, this.serverMessage});

  final ApiErrorKind kind;
  final int? statusCode;

  /// Field "message" dari body error Laravel, bila ada.
  final String? serverMessage;

  factory ApiException.fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(ApiErrorKind.timeout);
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return const ApiException(ApiErrorKind.noConnection);
      case DioExceptionType.cancel:
        return const ApiException(ApiErrorKind.cancelled);
      case DioExceptionType.badResponse:
        return ApiException.fromStatus(
          error.response?.statusCode,
          error.response?.data,
        );
      case DioExceptionType.unknown:
        if (error.error is SocketException || error.error is HttpException) {
          return const ApiException(ApiErrorKind.noConnection);
        }
        if (error.error is FormatException) {
          return const ApiException(ApiErrorKind.badResponse);
        }
        return ApiException(ApiErrorKind.unknown, serverMessage: error.message);
      // Dio menambah tipe baru antar versi minor (mis. transformTimeout di 5.9+).
      default:
        return const ApiException(ApiErrorKind.timeout);
    }
  }

  factory ApiException.fromStatus(int? status, Object? body) {
    final message =
        body is Map && body['message'] is String ? body['message'] as String : null;
    final kind = switch (status) {
      401 || 403 => ApiErrorKind.unauthorized,
      404 => ApiErrorKind.notFound,
      422 => ApiErrorKind.validation,
      429 => ApiErrorKind.rateLimited,
      final int code when code >= 500 => ApiErrorKind.server,
      _ => ApiErrorKind.badResponse,
    };
    return ApiException(kind, statusCode: status, serverMessage: message);
  }

  /// Error sementara / sisi server: aman untuk menampilkan data cache.
  bool get canFallBackToCache => switch (kind) {
        ApiErrorKind.noConnection ||
        ApiErrorKind.timeout ||
        ApiErrorKind.server ||
        ApiErrorKind.rateLimited ||
        ApiErrorKind.badResponse ||
        ApiErrorKind.notConfigured ||
        ApiErrorKind.unknown =>
          true,
        _ => false,
      };

  /// Judul singkat untuk pengguna.
  String get title => switch (kind) {
        ApiErrorKind.notConfigured => 'API key belum diatur',
        ApiErrorKind.noConnection => 'Tidak dapat terhubung ke server',
        ApiErrorKind.timeout => 'Waktu permintaan habis',
        ApiErrorKind.unauthorized => 'Akses ditolak server',
        ApiErrorKind.notFound => 'Konten tidak ditemukan',
        ApiErrorKind.validation => 'Permintaan tidak valid',
        ApiErrorKind.rateLimited => 'Terlalu banyak permintaan',
        ApiErrorKind.server => 'Server sedang bermasalah',
        ApiErrorKind.badResponse => 'Respons server tidak dikenali',
        ApiErrorKind.cancelled => 'Permintaan dibatalkan',
        ApiErrorKind.unknown => 'Terjadi kesalahan',
      };

  /// Penjelasan + saran tindakan.
  String get message => switch (kind) {
        ApiErrorKind.notConfigured =>
          'Isi API key di Pengaturan. Semua endpoint scraper-hub membutuhkan header X-Api-Key.',
        ApiErrorKind.noConnection =>
          'Periksa koneksi internet, atau pastikan server scraper-hub sedang berjalan dan alamatnya benar.',
        ApiErrorKind.timeout =>
          'Server terlalu lama merespons. Coba lagi beberapa saat lagi.',
        ApiErrorKind.unauthorized =>
          'API key salah atau sudah dicabut. Periksa kembali di Pengaturan.',
        ApiErrorKind.notFound =>
          'Data yang diminta tidak ada di server (mungkin sudah dihapus).',
        ApiErrorKind.validation =>
          serverMessage ?? 'Parameter pencarian tidak diterima server.',
        ApiErrorKind.rateLimited =>
          'Batas permintaan per menit tercapai. Tunggu sebentar lalu coba lagi.',
        ApiErrorKind.server =>
          'Server mengembalikan error${statusCode != null ? ' ($statusCode)' : ''}. Coba lagi nanti.',
        ApiErrorKind.badResponse =>
          'Format data dari server tidak sesuai. Pastikan alamat API mengarah ke /api/v1 scraper-hub.',
        ApiErrorKind.cancelled => 'Permintaan dihentikan sebelum selesai.',
        ApiErrorKind.unknown => serverMessage ?? 'Kesalahan tak terduga. Coba lagi.',
      };

  @override
  String toString() => 'ApiException($kind, $statusCode, $serverMessage)';
}

/// Mengubah error apa pun (Dio, parsing, dll.) menjadi [ApiException].
ApiException toApiException(Object error) {
  if (error is ApiException) return error;
  if (error is DioException) return ApiException.fromDio(error);
  if (error is FormatException || error is TypeError) {
    return const ApiException(ApiErrorKind.badResponse);
  }
  return ApiException(ApiErrorKind.unknown, serverMessage: error.toString());
}
