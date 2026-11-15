import 'dart:io';

/// HTTP polos hanya aman untuk jaringan lokal (localhost, IP privat, `.local`,
/// nama host tanpa titik). Ke host publik, isi dan cookie bisa dibaca/diubah
/// siapa pun di jalur jaringan.
bool isCleartextAllowed(Uri uri) => uri.scheme != 'http' || isLocalHost(uri.host);

/// Host jaringan lokal: localhost, `.local`, nama tanpa titik, IP loopback /
/// link-local / privat (RFC 1918, fc00::/7).
bool isLocalHost(String host) {
  final h = host.toLowerCase();
  if (h == 'localhost' || h.endsWith('.local')) return true;
  final ip = InternetAddress.tryParse(h);
  if (ip == null) return !h.contains('.'); // nama host tanpa titik = LAN
  if (ip.isLoopback || ip.isLinkLocal) return true;
  final b = ip.rawAddress;
  if (ip.type == InternetAddressType.IPv4) {
    return b[0] == 10 || (b[0] == 172 && b[1] >= 16 && b[1] <= 31) || (b[0] == 192 && b[1] == 168);
  }
  return (b[0] & 0xfe) == 0xfc; // fc00::/7
}

/// `http://` ke host publik dinaikkan jadi `https://`; lainnya apa adanya.
/// Port 80 eksplisit ikut dibuang (port bawaan https).
Uri upgradeCleartext(Uri uri) {
  if (isCleartextAllowed(uri)) return uri;
  return uri.replace(scheme: 'https', port: uri.hasPort && uri.port != 80 ? uri.port : null);
}
