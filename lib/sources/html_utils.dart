import 'package:html/dom.dart';

import 'models.dart';

/// Helper parsing HTML, padanan util Jsoup yang dipakai extension Mihon.
///
/// Catatan: package:html TIDAK mendukung pseudo-selector khas Jsoup seperti
/// `:contains(...)` dan `:has(...)` (melempar UnimplementedError). Gunakan
/// [findLabeled] / filter manual sebagai gantinya.

final _spaces = RegExp(r'\s+');

String clean(String? text) => (text ?? '').replaceAll(_spaces, ' ').trim();

/// Teks node langsung milik elemen, tanpa teks anak (Jsoup `ownText()`).
String ownText(Element element) =>
    clean(element.nodes.whereType<Text>().map((n) => n.text).join(' '));

/// `ownText`, atau seluruh teks bila elemen hanya membungkus anak (mis. `<i><a>X</a></i>`).
String ownOrFullText(Element element) {
  final own = ownText(element);
  return own.isNotEmpty ? own : clean(element.text);
}

/// Jsoup `absUrl`: resolve href relatif terhadap URL halaman.
String? absUrl(Uri base, String? href) {
  final value = href?.trim();
  if (value == null ||
      value.isEmpty ||
      value.startsWith('data:') ||
      value.startsWith('javascript:') ||
      value.startsWith('#')) {
    return null;
  }
  try {
    return base.resolve(value).toString();
  } on FormatException {
    return null;
  }
}

String? attrAbs(Element? element, String attr, Uri base) =>
    element == null ? null : absUrl(base, element.attributes[attr]);

/// URL gambar dengan dukungan lazy-load (MangaThemesia `imgAttr()`).
String? imgAttr(Element? img, Uri base) {
  if (img == null) return null;
  // Beberapa situs memakai atribut khusus seperti data-original-src.
  for (final entry in img.attributes.entries) {
    final key = entry.key.toString();
    if (key.endsWith('original-src')) {
      final url = absUrl(base, entry.value);
      if (url != null) return url;
    }
  }
  for (final key in const ['data-lazy-src', 'data-src', 'data-cfsrc', 'src']) {
    final url = absUrl(base, img.attributes[key]);
    if (url != null) return url;
  }
  return null;
}

/// Mengganti selector Jsoup `X:contains(label)`: cari elemen [selector] yang
/// teksnya memuat salah satu [labels] (tanpa peka huruf besar/kecil).
Iterable<Element> whereContains(Element root, String selector, List<String> labels) {
  final lower = labels.map((l) => l.toLowerCase()).toList();
  return root.querySelectorAll(selector).where((e) {
    final text = e.text.toLowerCase();
    return lower.any(text.contains);
  });
}

/// Nilai placeholder yang dianggap kosong.
String? nonPlaceholder(String? value) {
  final v = clean(value);
  const empty = {'', '-', 'n/a', 'unknown', '?'};
  return empty.contains(v.toLowerCase()) ? null : v;
}

String? removeQuery(String? url) {
  if (url == null) return null;
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  return uri.replace(query: '').toString().replaceFirst(RegExp(r'\?$'), '');
}

final _chapterNumber = RegExp(
  r'(?:chapter|chap|ch\.?|bab|episode|ep\.?)\s*(\d+(?:[.,]\d+)?)',
  caseSensitive: false,
);
final _anyNumber = RegExp(r'(\d+(?:[.,]\d+)?)');

/// "Chapter 12.5 - Judul" → 12.5. Fallback: angka pertama di teks.
double? parseChapterNumber(String text) {
  final match = _chapterNumber.firstMatch(text) ?? _anyNumber.firstMatch(text);
  return double.tryParse(match?.group(1)?.replaceAll(',', '.') ?? '');
}

const _months = {
  'january': 1, 'januari': 1, 'jan': 1,
  'february': 2, 'februari': 2, 'feb': 2, 'pebruari': 2,
  'march': 3, 'maret': 3, 'mar': 3,
  'april': 4, 'apr': 4,
  'may': 5, 'mei': 5,
  'june': 6, 'juni': 6, 'jun': 6,
  'july': 7, 'juli': 7, 'jul': 7,
  'august': 8, 'agustus': 8, 'aug': 8, 'agu': 8, 'agt': 8,
  'september': 9, 'sep': 9, 'sept': 9,
  'october': 10, 'oktober': 10, 'oct': 10, 'okt': 10,
  'november': 11, 'nov': 11, 'nopember': 11,
  'december': 12, 'desember': 12, 'dec': 12, 'des': 12,
};

/// Tanggal bab dalam format umum situs: "November 3, 2025", "3 Oktober 2025",
/// "03/11/2025" (dd/MM/yyyy), "2025-11-03", atau relatif "2 jam lalu" / "3 days ago".
DateTime? parseLooseDate(String? raw, {DateTime? now}) {
  final text = clean(raw).toLowerCase();
  if (text.isEmpty) return null;

  final relative = _parseRelative(text, now ?? DateTime.now());
  if (relative != null) return relative;

  final iso = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(text);
  if (iso != null) {
    return _date(int.parse(iso[1]!), int.parse(iso[2]!), int.parse(iso[3]!));
  }

  final dmy = RegExp(r'(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})').firstMatch(text);
  if (dmy != null) {
    return _date(int.parse(dmy[3]!), int.parse(dmy[2]!), int.parse(dmy[1]!));
  }

  // "november 3, 2025"
  final mdy = RegExp(r'([a-z]+)\.?\s+(\d{1,2}),?\s+(\d{4})').firstMatch(text);
  if (mdy != null && _months.containsKey(mdy[1])) {
    return _date(int.parse(mdy[3]!), _months[mdy[1]]!, int.parse(mdy[2]!));
  }

  // "3 oktober 2025"
  final dMy = RegExp(r'(\d{1,2})\s+([a-z]+)\.?,?\s+(\d{4})').firstMatch(text);
  if (dMy != null && _months.containsKey(dMy[2])) {
    return _date(int.parse(dMy[3]!), _months[dMy[2]]!, int.parse(dMy[1]!));
  }
  return null;
}

DateTime? _date(int y, int m, int d) =>
    (m < 1 || m > 12 || d < 1 || d > 31) ? null : DateTime(y, m, d);

DateTime? _parseRelative(String text, DateTime now) {
  if (!text.contains('lalu') && !text.contains('ago')) return null;
  final match = RegExp(r'(\d+|an?|se)\s*([a-z]+)').firstMatch(text);
  if (match == null) return null;
  final amount = int.tryParse(match[1]!) ?? 1;
  final unit = match[2]!;
  Duration? d;
  if (unit.startsWith('det') || unit.startsWith('sec')) d = Duration(seconds: amount);
  if (unit.startsWith('men') || unit.startsWith('min')) d = Duration(minutes: amount);
  if (unit.startsWith('jam') || unit.startsWith('hour')) d = Duration(hours: amount);
  if (unit.startsWith('hari') || unit.startsWith('day')) d = Duration(days: amount);
  if (unit.startsWith('minggu') || unit.startsWith('week')) d = Duration(days: 7 * amount);
  if (unit.startsWith('bulan') || unit.startsWith('month')) d = Duration(days: 30 * amount);
  if (unit.startsWith('tahun') || unit.startsWith('year')) d = Duration(days: 365 * amount);
  return d == null ? null : now.subtract(d);
}

SourceMangaStatus parseStatus(String? raw) {
  final s = clean(raw).toLowerCase();
  if (s.isEmpty) return SourceMangaStatus.unknown;
  bool any(List<String> words) => words.any(s.contains);
  if (any(['ongoing', 'on going', 'berjalan', 'updating', 'publishing', 'new season'])) {
    return SourceMangaStatus.ongoing;
  }
  if (any(['completed', 'complete', 'tamat', 'finished', 'end', 'one-shot', 'selesai'])) {
    return SourceMangaStatus.completed;
  }
  if (any(['hiatus', 'on hold', 'season end'])) return SourceMangaStatus.hiatus;
  if (any(['cancel', 'dropped', 'discontinued'])) return SourceMangaStatus.cancelled;
  return SourceMangaStatus.unknown;
}
