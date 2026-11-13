/// Normalisasi URL repo (manifest plugin / katalog sumber); null bila bukan
/// URL http(s). Tautan halaman GitHub `blob/` diubah ke file mentah.
String? normalizeRepoUrl(String input) {
  var url = input.trim();
  if (url.isEmpty) return null;
  final blob = RegExp(r'^https?://github\.com/([^/]+)/([^/]+)/blob/(.+)$').firstMatch(url);
  if (blob != null) url = 'https://raw.githubusercontent.com/${blob[1]}/${blob[2]}/${blob[3]}';
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https')) || uri.host.isEmpty) return null;
  return url;
}
