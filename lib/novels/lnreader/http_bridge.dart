import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Request `fetch()` dari plugin. Data polos supaya bisa dikirim antar isolate.
class LnHttpRequest {
  const LnHttpRequest({
    required this.id,
    required this.url,
    required this.method,
    required this.headers,
    required this.bodyType,
    this.bodyText,
    this.bodyFields = const [],
    this.followRedirects = true,
  });

  final int id;
  final String url;
  final String method;
  final Map<String, String> headers;

  /// `none` | `text` | `base64` | `multipart`
  final String bodyType;
  final String? bodyText;
  final List<List<String>> bodyFields;
  final bool followRedirects;

  factory LnHttpRequest.fromJs(Map<String, Object?> json) {
    final body = (json['body'] as Map?) ?? const {'type': 'none'};
    return LnHttpRequest(
      id: json['id'] as int,
      url: json['url'] as String,
      method: (json['method'] as String?) ?? 'GET',
      headers: {for (final e in ((json['headers'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'},
      bodyType: (body['type'] as String?) ?? 'none',
      bodyText: body['value'] as String?,
      bodyFields: [
        for (final f in (body['fields'] as List?) ?? const []) ['${(f as List)[0]}', '${f[1]}'],
      ],
      followRedirects: json['redirect'] != 'manual',
    );
  }
}

class LnHttpResponse {
  const LnHttpResponse({
    required this.status,
    required this.statusText,
    required this.url,
    required this.redirected,
    required this.headers,
    required this.bytes,
  });

  final int status;
  final String statusText;
  final String url;
  final bool redirected;
  final Map<String, String> headers;
  final Uint8List bytes;

  String? get charset {
    final m = RegExp(r'charset=([^;\s]+)', caseSensitive: false).firstMatch(headers['content-type'] ?? '');
    return m?.group(1)?.replaceAll('"', '').toLowerCase();
  }

  Map<String, Object?> metaJson() => {
        'status': status,
        'statusText': statusText,
        'url': url,
        'redirected': redirected,
        'headers': headers,
      };
}

/// Error jaringan (bukan status HTTP): diteruskan ke JS sebagai `TypeError`.
class LnNetworkException implements Exception {
  const LnNetworkException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Pelaksana `fetch()` plugin dengan Dio, berbagi User-Agent & cookie dengan
/// sumber komik (cookie cf_clearance dari WebView ikut terkirim).
class LnFetcher {
  LnFetcher({
    required this.userAgent,
    this.cookieHeaderFor,
    this.onSetCookie,
    Dio? dio,
  }) : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 40),
              responseType: ResponseType.bytes,
              validateStatus: (_) => true,
              maxRedirects: 8,
            ));

  final Dio _dio;
  final String Function() userAgent;
  final String? Function(Uri url)? cookieHeaderFor;

  /// Dipanggil dengan pasangan `a=b; c=d` dari header `Set-Cookie`.
  final void Function(Uri url, String cookies)? onSetCookie;

  final _cancel = <int, CancelToken>{};

  static const _droppedHeaders = {'connection', 'accept-encoding', 'host', 'content-length'};

  void abort(int id) => _cancel.remove(id)?.cancel();

  Future<LnHttpResponse> fetch(LnHttpRequest req) async {
    final token = CancelToken();
    _cancel[req.id] = token;
    try {
      final uri = Uri.parse(req.url);
      final headers = <String, Object>{
        for (final e in req.headers.entries)
          if (!_droppedHeaders.contains(e.key.toLowerCase())) e.key: e.value,
      };
      if (!headers.keys.any((k) => k.toLowerCase() == 'user-agent')) headers['User-Agent'] = userAgent();
      final stored = cookieHeaderFor?.call(uri);
      if (stored != null) {
        final own = headers.entries.where((e) => e.key.toLowerCase() == 'cookie').map((e) => e.value).firstOrNull;
        headers.removeWhere((k, _) => k.toLowerCase() == 'cookie');
        headers['Cookie'] = own == null ? stored : '$stored; $own';
      }

      Object? data;
      switch (req.bodyType) {
        case 'text':
          data = req.bodyText;
        case 'base64':
          data = base64Decode(req.bodyText ?? '');
        case 'multipart':
          headers.removeWhere((k, _) => k.toLowerCase() == 'content-type');
          data = FormData()..fields.addAll([for (final f in req.bodyFields) MapEntry(f[0], f[1])]);
      }

      final response = await _dio.requestUri<List<int>>(
        uri,
        data: data,
        cancelToken: token,
        options: Options(
          method: req.method,
          headers: headers,
          followRedirects: req.followRedirects,
          responseType: ResponseType.bytes,
          validateStatus: (_) => true,
        ),
      );
      final setCookie = response.headers['set-cookie'];
      if (setCookie != null && setCookie.isNotEmpty) {
        onSetCookie?.call(response.realUri, setCookie.map((c) => c.split(';').first).join('; '));
      }
      return LnHttpResponse(
        status: response.statusCode ?? 0,
        statusText: response.statusMessage ?? '',
        url: response.realUri.toString(),
        redirected: response.redirects.isNotEmpty,
        headers: {for (final e in response.headers.map.entries) e.key: e.value.join(', ')},
        bytes: Uint8List.fromList(response.data ?? const []),
      );
    } on DioException catch (e) {
      throw LnNetworkException(switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout =>
          'Network request timed out',
        DioExceptionType.cancel => 'Aborted',
        _ => 'Network request failed: ${e.error ?? e.message}',
      });
    } finally {
      _cancel.remove(req.id);
    }
  }
}

/// Decode body sesuai charset; tidak dikenal → UTF-8 toleran.
String decodeBody(List<int> bytes, String? charset) {
  final c = charset?.toLowerCase();
  if (c == null || c == 'utf-8' || c == 'utf8') return utf8.decode(bytes, allowMalformed: true);
  final encoding = Encoding.getByName(c);
  if (encoding == null || encoding == utf8) return utf8.decode(bytes, allowMalformed: true);
  try {
    return encoding.decode(bytes);
  } catch (_) {
    return utf8.decode(bytes, allowMalformed: true);
  }
}
