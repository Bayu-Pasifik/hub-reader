/// 12.0 -> "12", 12.5 -> "12.5" (API mengirim nomor bab sebagai float).
String formatChapterNumber(double number) {
  if (number == number.truncateToDouble()) return number.toInt().toString();
  return number
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// Status dari scraper sudah dinormalisasi ke "ongoing"/"completed"
/// (lihat ComixScraper & WtrLabScraper). Nilai lain ditampilkan apa adanya.
String statusLabel(String? status) {
  if (status == null || status.isEmpty) return 'Tidak diketahui';
  return switch (status.toLowerCase()) {
    'ongoing' || 'releasing' => 'Berjalan',
    'completed' || 'finished' => 'Tamat',
    'hiatus' || 'on_hiatus' => 'Hiatus',
    'cancelled' || 'canceled' || 'discontinued' || 'dropped' => 'Dihentikan',
    'upcoming' || 'not_yet_released' => 'Segera rilis',
    _ => status,
  };
}

String relativeTime(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inMinutes < 1) return 'baru saja';
  if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
  if (diff.inDays < 1) return '${diff.inHours} jam lalu';
  if (diff.inDays < 30) return '${diff.inDays} hari lalu';
  if (diff.inDays < 365) return '${diff.inDays ~/ 30} bulan lalu';
  return '${diff.inDays ~/ 365} tahun lalu';
}

/// Deskripsi hasil scraping kadang berisi tag HTML.
String stripHtml(String input) {
  return input
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
