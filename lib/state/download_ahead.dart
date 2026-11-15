import '../sources/models.dart';
import '../sources/scanlator.dart';

/// Pilihan jumlah bab "unduh di depan" (0 = mati).
const downloadAheadChoices = [0, 1, 2, 3, 5, 10];

/// Bab yang perlu diunduh di depan bab yang sedang dibaca.
///
/// [chapters] urut terbaru → terlama (seperti daftar situs), jadi "berikutnya"
/// adalah indeks yang lebih kecil dari [index]. Hasilnya diurutkan dari bab
/// yang paling dekat. Bab dari grup scanlator yang disembunyikan dilewati,
/// dan [alreadyHave] (sudah terunduh / sedang antre) tidak dihitung ke jatah
/// [count] supaya unduhan tetap menjangkau [count] bab yang belum ada.
List<SourceChapter> chaptersToDownloadAhead(
  List<SourceChapter> chapters,
  int index, {
  required int count,
  Set<String> hiddenGroups = const {},
  bool Function(SourceChapter)? alreadyHave,
}) {
  if (count <= 0 || index <= 0 || index >= chapters.length) return const [];
  final out = <SourceChapter>[];
  for (var i = index - 1; i >= 0 && out.length < count; i--) {
    final c = chapters[i];
    if (!chapterVisible(c, hiddenGroups)) continue;
    if (alreadyHave?.call(c) ?? false) continue;
    out.add(c);
  }
  return out;
}
