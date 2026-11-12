import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'cookie_store.dart';
import 'filters.dart';
import 'models.dart';

export 'filters.dart';
import 'source_exception.dart';

/// Kontrak satu extension sumber (padanan `Source`/`KeiSource` di Mihon).
///
/// Implementasi baru cukup extend [HttpSource] (atau template seperti
/// MangaThemesia) lalu didaftarkan di `registry.dart`.
abstract class MangaSource {
  /// Unik & stabil, mis. "id.komiku". Dipakai di URL rute & kunci provider.
  String get id;
  String get name;

  /// Kode bahasa ISO, mis. "id".
  String get lang;
  String get baseUrl;
  ContentWarning get contentWarning;
  bool get supportsLatest => true;

  Future<MangaPage> popular(int page);
  Future<MangaPage> latest(int page);
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty});

  /// Definisi filter yang didukung (boleh mengambil data dari situs, mis.
  /// daftar genre). Kosong = sumber tidak punya filter.
  Future<List<FilterDef>> filters() async => const [];

  /// Detail + daftar bab dari URL seri (absolut).
  Future<SourceMangaDetails> details(String mangaUrl);

  /// URL gambar halaman-halaman satu bab.
  Future<List<String>> pages(SourceChapter chapter);

  /// Header untuk memuat gambar (sampul & halaman). Banyak situs menolak
  /// gambar tanpa `Referer` dari domainnya sendiri.
  Map<String, String> imageHeaders({String? referer});
}

/// Hasil fetch HTML: dokumen terparsing + body mentah + URL akhir
/// (setelah redirect, dipakai untuk me-resolve URL relatif).
class HtmlResponse {
  const HtmlResponse(this.document, this.body, this.url);

  final Document document;
  final String body;
  final Uri url;
}

/// Basis extension berbasis HTTP: Dio dengan header browser, rate limit
/// sederhana, dan helper ambil dokumen HTML.
abstract class HttpSource extends MangaSource {
  HttpSource({Dio? dio}) : _injectedDio = dio;

  final Dio? _injectedDio;

  static const fallbackUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';

  /// Di Android diganti saat startup dengan UA asli WebView perangkat, supaya
  /// cookie Cloudflare dari WebView berlaku juga untuk request Dio.
  static String userAgent = fallbackUserAgent;

  /// Cookie per host (mis. cf_clearance). Diganti versi persisten di main().
  static SourceCookieStore cookies = SourceCookieStore();

  /// Domain bawaan sumber.
  String get defaultBaseUrl;

  /// Domain pengganti dari pengaturan (situs sering pindah domain).
  String? baseUrlOverride;

  /// Host lama yang pernah dipakai sumber ini. URL tersimpan (favorit,
  /// riwayat) yang memakai host ini dialihkan ke [baseUrl] saat ini.
  Set<String> previousHosts = {};

  @override
  String get baseUrl {
    final override = baseUrlOverride?.trim();
    if (override == null || override.isEmpty) return defaultBaseUrl;
    return override.endsWith('/') ? override.substring(0, override.length - 1) : override;
  }

  /// Alihkan URL berhost lama milik sumber ini ke domain saat ini.
  Uri rewriteToCurrentHost(Uri url) {
    final current = baseUri;
    if (url.host == current.host) return url;
    final known = {Uri.parse(defaultBaseUrl).host, ...previousHosts};
    if (!known.contains(url.host)) return url;
    return url.replace(scheme: current.scheme, host: current.host, port: current.hasPort ? current.port : null);
  }

  /// Maksimal request per detik ke situs ini (padanan `rateLimit(n)`).
  int get requestsPerSecond => 2;

  /// Header tambahan per sumber.
  Map<String, String> get extraHeaders => const {};

  late final Dio dio = _injectedDio ??
      (Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        responseType: ResponseType.plain,
        headers: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7',
          'Referer': '$baseUrl/',
          ...extraHeaders,
        },
      ))
        ..interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
          // UA & cookie dibaca per request: keduanya bisa berubah setelah
          // verifikasi Cloudflare di WebView.
          options.headers.putIfAbsent('User-Agent', () => userAgent);
          final cookie = cookies.cookieHeaderFor(options.uri);
          if (cookie != null) options.headers['Cookie'] = cookie;
          handler.next(options);
        })));

  Uri get baseUri => Uri.parse(baseUrl);

  DateTime _nextSlot = DateTime.fromMillisecondsSinceEpoch(0);

  /// Antrian slot waktu: request ke-n menunggu sampai slotnya tiba.
  Future<void> _throttle() async {
    final interval = Duration(milliseconds: (1000 / requestsPerSecond).ceil());
    final now = DateTime.now();
    final slot = _nextSlot.isAfter(now) ? _nextSlot : now;
    _nextSlot = slot.add(interval);
    final wait = slot.difference(now);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
  }

  Future<HtmlResponse> fetchHtml(Uri url, {Map<String, String>? headers}) async {
    await _throttle();
    try {
      final response = await dio.getUri<String>(
        rewriteToCurrentHost(url),
        options: Options(headers: headers),
      );
      final body = response.data ?? '';
      return HtmlResponse(html_parser.parse(body), body, response.realUri);
    } catch (error) {
      throw toSourceException(error);
    }
  }

  /// POST form (application/x-www-form-urlencoded), hasil berupa HTML.
  /// Dipakai template WordPress seperti Madara (`admin-ajax.php`).
  Future<HtmlResponse> postHtml(Uri url, Map<String, String> form, {Map<String, String>? headers}) async {
    await _throttle();
    try {
      final response = await dio.postUri<String>(
        rewriteToCurrentHost(url),
        data: form,
        options: Options(contentType: Headers.formUrlEncodedContentType, headers: headers),
      );
      final body = response.data ?? '';
      return HtmlResponse(html_parser.parse(body), body, response.realUri);
    } catch (error) {
      throw toSourceException(error);
    }
  }

  /// GET JSON (untuk sumber berbasis API, mis. Shinigami).
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async {
    await _throttle();
    try {
      final response = await dio.getUri<String>(
        url,
        options: Options(headers: {'Accept': 'application/json', ...?headers}),
      );
      return jsonDecode(response.data ?? 'null');
    } on FormatException {
      throw const SourceException(SourceErrorKind.parse, detail: 'Respons API bukan JSON.');
    } catch (error) {
      throw toSourceException(error);
    }
  }

  @override
  Map<String, String> imageHeaders({String? referer}) {
    final cookie = cookies.cookieHeaderFor(baseUri);
    return {
      'User-Agent': userAgent,
      'Referer': referer ?? '$baseUrl/',
      'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
      if (cookie != null) 'Cookie': cookie,
    };
  }
}
