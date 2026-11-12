const _loopbackHosts = {'localhost', '127.0.0.1', '0.0.0.0', '::1'};

/// Memperbaiki URL gambar dari API agar bisa dibuka dari perangkat Android.
///
/// `cover.thumbnail` dibuat Laravel lewat `Storage::disk('public')->url()`
/// yang memakai APP_URL. Jika APP_URL=http://localhost:8000, emulator/HP tidak
/// bisa membukanya. URL loopback ditulis ulang ke host server API, dan path
/// relatif digabungkan dengan origin API.
String? resolveMediaUrl(String? raw, Uri? apiOrigin) {
  if (raw == null || raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;

  if (!uri.hasScheme) {
    return apiOrigin?.resolveUri(uri).toString();
  }

  if (apiOrigin != null &&
      _loopbackHosts.contains(uri.host) &&
      !_loopbackHosts.contains(apiOrigin.host)) {
    return uri
        .replace(
          scheme: apiOrigin.scheme,
          host: apiOrigin.host,
          port: apiOrigin.port,
        )
        .toString();
  }
  return raw;
}
