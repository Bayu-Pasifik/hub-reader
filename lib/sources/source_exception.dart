import 'dart:io';

import 'package:dio/dio.dart';

enum SourceErrorKind {
  noConnection,
  timeout,

  /// 403/503 dari Cloudflare ("Just a moment...").
  cloudflare,
  notFound,
  rateLimited,
  server,

  /// HTML berubah / selector tidak menemukan apa-apa.
  parse,
  unknown,
}

/// Error dari extension sumber; pesannya tentang situs sumber.
class SourceException implements Exception {
  const SourceException(this.kind, {this.statusCode, this.detail, this.url});

  final SourceErrorKind kind;
  final int? statusCode;
  final String? detail;

  /// URL request yang gagal. Untuk Cloudflare, URL inilah yang perlu dibuka
  /// di WebView (tantangan bisa hanya muncul di halaman tertentu, mis. pencarian).
  final Uri? url;

  factory SourceException.fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const SourceException(SourceErrorKind.timeout);
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return const SourceException(SourceErrorKind.noConnection);
      case DioExceptionType.badResponse:
        final response = error.response;
        final status = response?.statusCode;
        final server = response?.headers.value('server')?.toLowerCase() ?? '';
        final body = response?.data is String ? response!.data as String : '';
        final isCloudflare = (status == 403 || status == 503) &&
            (server.contains('cloudflare') ||
                body.contains('cf-chl') ||
                body.contains('Just a moment'));
        if (isCloudflare) {
          return SourceException(
            SourceErrorKind.cloudflare,
            statusCode: status,
            url: error.requestOptions.uri,
          );
        }
        return SourceException(
          switch (status) {
            404 => SourceErrorKind.notFound,
            429 => SourceErrorKind.rateLimited,
            final int code when code >= 500 => SourceErrorKind.server,
            _ => SourceErrorKind.unknown,
          },
          statusCode: status,
        );
      case DioExceptionType.unknown:
        // TlsException/HandshakeException: koneksi TLS diputus di tengah
        // jalan, umumnya situs diblokir provider (SNI) atau domain mati.
        if (error.error is SocketException || error.error is HttpException || error.error is TlsException) {
          return const SourceException(SourceErrorKind.noConnection);
        }
        return SourceException(SourceErrorKind.unknown, detail: error.message);
      case DioExceptionType.cancel:
        return const SourceException(SourceErrorKind.unknown, detail: 'Dibatalkan');
      // Tipe baru di versi Dio lebih baru (mis. transformTimeout).
      default:
        return const SourceException(SourceErrorKind.timeout);
    }
  }

  String get title => switch (kind) {
        SourceErrorKind.noConnection => 'Tidak dapat terhubung ke situs',
        SourceErrorKind.timeout => 'Situs terlalu lama merespons',
        SourceErrorKind.cloudflare => 'Situs diproteksi Cloudflare',
        SourceErrorKind.notFound => 'Halaman tidak ditemukan',
        SourceErrorKind.rateLimited => 'Terlalu banyak permintaan',
        SourceErrorKind.server => 'Situs sedang bermasalah',
        SourceErrorKind.parse => 'Format situs berubah',
        SourceErrorKind.unknown => 'Terjadi kesalahan',
      };

  String get message => switch (kind) {
        SourceErrorKind.noConnection =>
          'Periksa koneksi internet. Domain situs mungkin juga sudah pindah atau diblokir provider (coba DNS/VPN).',
        SourceErrorKind.timeout => 'Coba lagi beberapa saat lagi.',
        SourceErrorKind.cloudflare =>
          'Situs meminta verifikasi browser. Ketuk "Buka di WebView", selesaikan verifikasinya, lalu halaman dimuat ulang otomatis.',
        SourceErrorKind.notFound =>
          'URL mungkin sudah berubah atau seri dihapus dari situs.',
        SourceErrorKind.rateLimited => 'Tunggu sebentar lalu coba lagi.',
        // 520–526: Cloudflare tidak bisa menghubungi server asli situs.
        SourceErrorKind.server when statusCode != null && statusCode! >= 520 && statusCode! <= 526 =>
          'Server situs tidak merespons ($statusCode dari Cloudflare). Biasanya situsnya sedang down; coba lagi nanti.',
        SourceErrorKind.server =>
          'Situs mengembalikan error${statusCode != null ? ' ($statusCode)' : ''}.',
        SourceErrorKind.parse =>
          detail ?? 'Data tidak ditemukan di halaman. Extension perlu diperbarui.',
        SourceErrorKind.unknown => detail ?? 'Kesalahan tak terduga.',
      };

  @override
  String toString() => 'SourceException($kind, $statusCode, $detail)';
}

SourceException toSourceException(Object error) {
  if (error is SourceException) return error;
  if (error is DioException) return SourceException.fromDio(error);
  if (error is FormatException || error is TypeError || error is StateError) {
    return SourceException(SourceErrorKind.parse, detail: error.toString());
  }
  return SourceException(SourceErrorKind.unknown, detail: error.toString());
}
