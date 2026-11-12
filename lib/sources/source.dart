import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'models.dart';
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
  Future<MangaPage> search(int page, String query);

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

  static const userAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';

  /// Maksimal request per detik ke situs ini (padanan `rateLimit(n)`).
  int get requestsPerSecond => 2;

  /// Header tambahan per sumber.
  Map<String, String> get extraHeaders => const {};

  late final Dio dio = _injectedDio ??
      Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        responseType: ResponseType.plain,
        headers: {
          'User-Agent': userAgent,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7',
          'Referer': '$baseUrl/',
          ...extraHeaders,
        },
      ));

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
        url,
        options: Options(headers: headers),
      );
      final body = response.data ?? '';
      return HtmlResponse(html_parser.parse(body), body, response.realUri);
    } catch (error) {
      throw toSourceException(error);
    }
  }

  @override
  Map<String, String> imageHeaders({String? referer}) => {
        'User-Agent': userAgent,
        'Referer': referer ?? '$baseUrl/',
        'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
      };
}
