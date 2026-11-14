import 'package:dio/dio.dart';

/// Hasil cari teks terpilih: terjemahan dan (untuk satu kata Inggris) definisi.
class LookupResult {
  const LookupResult({this.translation, this.definitions = const [], this.phonetic});

  final String? translation;

  /// Definisi kamus, mis. "noun: a domesticated feline".
  final List<String> definitions;
  final String? phonetic;

  bool get isEmpty => translation == null && definitions.isEmpty;
}

/// Pencarian kamus & terjemahan lewat layanan web gratis (MyMemory dan
/// dictionaryapi.dev). Teks terpilih dikirim ke layanan itu.
class TextLookup {
  TextLookup({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ));

  final Dio _dio;

  /// Satu kata Latin dianggap kata kamus.
  static bool isSingleWord(String text) => RegExp(r"^[A-Za-z][A-Za-z'\-]{1,40}$").hasMatch(text.trim());

  /// Batas panjang teks yang dikirim (batas layanan gratis).
  static const maxLength = 450;

  Future<LookupResult> lookup(String text, {String target = 'id'}) async {
    final q = text.trim();
    if (q.isEmpty) return const LookupResult();
    final clipped = q.length > maxLength ? q.substring(0, maxLength) : q;
    final results = await Future.wait([
      _translate(clipped, target),
      isSingleWord(q) ? _define(q) : Future.value(const LookupResult()),
    ]);
    return LookupResult(
      translation: results[0].translation,
      definitions: results[1].definitions,
      phonetic: results[1].phonetic,
    );
  }

  Future<LookupResult> _translate(String text, String target) async {
    try {
      final res = await _dio.get<Object>(
        'https://api.mymemory.translated.net/get',
        queryParameters: {'q': text, 'langpair': 'Autodetect|$target'},
      );
      final data = res.data;
      if (data is Map) {
        final out = (data['responseData'] as Map?)?['translatedText'];
        if (out is String && out.trim().isNotEmpty && out.trim().toLowerCase() != text.toLowerCase()) {
          return LookupResult(translation: out.trim());
        }
      }
    } on Object {
      // layanan opsional
    }
    return const LookupResult();
  }

  Future<LookupResult> _define(String word) async {
    try {
      final res = await _dio
          .get<Object>('https://api.dictionaryapi.dev/api/v2/entries/en/${Uri.encodeComponent(word.toLowerCase())}');
      final data = res.data;
      if (data is List && data.isNotEmpty && data.first is Map) {
        final entry = data.first as Map;
        final defs = <String>[];
        for (final m in (entry['meanings'] as List? ?? const [])) {
          final pos = (m as Map)['partOfSpeech'];
          for (final d in (m['definitions'] as List? ?? const []).take(2)) {
            final text = (d as Map)['definition'];
            if (text is String) defs.add(pos is String ? '$pos: $text' : text);
          }
          if (defs.length >= 5) break;
        }
        return LookupResult(definitions: defs.take(5).toList(), phonetic: entry['phonetic'] as String?);
      }
    } on Object {
      // bukan kata Inggris / tidak ada entri
    }
    return const LookupResult();
  }
}
