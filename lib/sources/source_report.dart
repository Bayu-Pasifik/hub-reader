import '../core/update/app_update.dart';
import 'source_exception.dart';

/// Sumber yang dilaporkan: hanya nama, id, dan domain publik situs.
typedef SourceReportTarget = ({String name, String id, String baseUrl});

/// Error yang layak dilaporkan sebagai sumber rusak. Gangguan koneksi,
/// timeout, Cloudflare, dan batas permintaan biasanya masalah jaringan
/// pengguna, bukan sumbernya.
bool isReportable(SourceErrorKind kind) => switch (kind) {
      SourceErrorKind.parse || SourceErrorKind.notFound || SourceErrorKind.server || SourceErrorKind.unknown => true,
      _ => false,
    };

/// Tautan isu GitHub yang sudah terisi untuk melaporkan sumber rusak.
///
/// Hanya dibuka di browser untuk ditinjau dan dikirim sendiri oleh pengguna;
/// aplikasi tidak mengirim apa pun. Isinya sengaja minim: tidak ada riwayat,
/// favorit, cookie, proxy, maupun alamat pengguna.
Uri buildSourceReportUri(
  SourceReportTarget source,
  SourceException error, {
  String? appVersion,
  String repo = AppUpdate.repo,
}) {
  String clip(String? s, int max) {
    final t = (s ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length <= max ? t : '${t.substring(0, max)}…';
  }

  final status = error.statusCode == null ? '' : ' (HTTP ${error.statusCode})';
  final body = StringBuffer()
    ..writeln('**Sumber:** ${clip(source.name, 80)} (`${clip(source.id, 80)}`)')
    ..writeln('**Domain:** ${clip(source.baseUrl, 200)}')
    ..writeln('**Jenis error:** ${error.kind.name}$status')
    ..writeln('**Versi aplikasi:** ${appVersion ?? 'tidak diketahui'}');
  final detail = clip(error.detail, 300);
  if (detail.isNotEmpty) body.writeln('**Detail:** $detail');
  body
    ..writeln()
    ..writeln('Langkah: (tulis halaman atau seri yang gagal dibuka)');
  return Uri.https('github.com', '/$repo/issues/new', {
    'title': '[Sumber rusak] ${clip(source.name, 60)}: ${error.kind.name}$status',
    'body': body.toString(),
  });
}
