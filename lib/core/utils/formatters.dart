import '../i18n/strings.dart';
String relativeTime(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inMinutes < 1) return tr('baru saja');
  if (diff.inHours < 1) return trp('{inMinutes} menit lalu', {'inMinutes': diff.inMinutes});
  if (diff.inDays < 1) return trp('{inHours} jam lalu', {'inHours': diff.inHours});
  if (diff.inDays < 30) return trp('{inDays} hari lalu', {'inDays': diff.inDays});
  if (diff.inDays < 365) return trp('{inDays} bulan lalu', {'inDays': diff.inDays ~/ 30});
  return trp('{inDays} tahun lalu', {'inDays': diff.inDays ~/ 365});
}
