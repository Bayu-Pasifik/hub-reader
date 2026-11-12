import 'dart:convert';

/// Penyimpanan cookie per host untuk request scraping (padanan cookie jar
/// WebView yang dipakai OkHttp di Mihon).
///
/// Dipakai terutama untuk `cf_clearance` hasil verifikasi Cloudflare di
/// WebView. Cookie itu terikat ke User-Agent + IP, jadi request harus memakai
/// User-Agent yang sama dengan WebView (lihat `HttpSource.userAgent`).
class SourceCookieStore {
  SourceCookieStore({Map<String, String>? initial, this.onChanged})
      : _byHost = {...?initial};

  /// Dipanggil setiap kali isi berubah, untuk persistensi.
  final void Function(String json)? onChanged;

  final Map<String, String> _byHost;

  factory SourceCookieStore.fromJson(String? raw, {void Function(String json)? onChanged}) {
    var initial = <String, String>{};
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          initial = {
            for (final e in decoded.entries)
              if (e.value is String) e.key.toString(): e.value as String,
          };
        }
      } on FormatException {
        // abaikan data rusak
      }
    }
    return SourceCookieStore(initial: initial, onChanged: onChanged);
  }

  /// Header `Cookie` untuk [url]: cookie host itu sendiri plus domain induknya
  /// (cookie `.situs.com` berlaku juga untuk `cdn.situs.com`).
  String? cookieHeaderFor(Uri url) {
    final host = url.host.toLowerCase();
    final pairs = <String, String>{};
    for (final entry in _byHost.entries) {
      final h = entry.key;
      if (host == h || host.endsWith('.$h')) pairs.addAll(_parse(entry.value));
    }
    if (pairs.isEmpty) return null;
    return pairs.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  bool hasCookie(Uri url, String name) =>
      _parse(cookieHeaderFor(url) ?? '').containsKey(name);

  /// Simpan string cookie mentah (format `a=1; b=2`) untuk host [url].
  void save(Uri url, String? cookieString) {
    final host = url.host.toLowerCase();
    if (cookieString == null || cookieString.trim().isEmpty) return;
    final merged = {..._parse(_byHost[host] ?? ''), ..._parse(cookieString)};
    _byHost[host] = merged.entries.map((e) => '${e.key}=${e.value}').join('; ');
    onChanged?.call(jsonEncode(_byHost));
  }

  void clear(Uri url) {
    if (_byHost.remove(url.host.toLowerCase()) != null) onChanged?.call(jsonEncode(_byHost));
  }

  static Map<String, String> _parse(String raw) => {
        for (final part in raw.split(';'))
          if (part.contains('='))
            part.substring(0, part.indexOf('=')).trim(): part.substring(part.indexOf('=') + 1).trim(),
      };
}
