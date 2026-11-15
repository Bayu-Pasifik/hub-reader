import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/state/download_ahead.dart';

SourceChapter ch(String n, {String? scanlator}) => SourceChapter(url: '/$n', name: 'Bab $n', scanlator: scanlator);

void main() {
  // Terbaru → terlama, seperti daftar situs: 5, 4, 3, 2, 1.
  final chapters = [for (final n in [5, 4, 3, 2, 1]) ch('$n')];
  List<String> names(List<SourceChapter> l) => [for (final c in l) c.url];

  test('mengambil bab di depan yang terdekat dulu', () {
    expect(names(chaptersToDownloadAhead(chapters, 3, count: 2)), ['/3', '/4']); // membaca bab 2
    expect(names(chaptersToDownloadAhead(chapters, 4, count: 10)), ['/2', '/3', '/4', '/5']); // membaca bab 1
  });

  test('tidak ada bab di depan atau fitur mati', () {
    expect(chaptersToDownloadAhead(chapters, 0, count: 3), isEmpty); // sudah bab terbaru
    expect(chaptersToDownloadAhead(chapters, 3, count: 0), isEmpty);
    expect(chaptersToDownloadAhead(chapters, -1, count: 3), isEmpty);
    expect(chaptersToDownloadAhead(chapters, 9, count: 3), isEmpty);
  });

  test('yang sudah ada tidak memakai jatah, jadi tetap menjangkau bab belum terunduh', () {
    final have = {'/3', '/4'};
    final out = chaptersToDownloadAhead(chapters, 4, count: 2, alreadyHave: (c) => have.contains(c.url));
    expect(names(out), ['/2', '/5']);
  });

  test('grup scanlator yang disembunyikan dilewati', () {
    final list = [ch('4', scanlator: 'B'), ch('3', scanlator: 'A'), ch('2', scanlator: 'B'), ch('1', scanlator: 'A')];
    final out = chaptersToDownloadAhead(list, 3, count: 2, hiddenGroups: {'B'});
    expect(names(out), ['/3']); // bab 2 & 4 disembunyikan, hanya 3 yang tersisa
  });

  test('pilihan di pengaturan', () {
    expect(downloadAheadChoices.first, 0);
    expect(downloadAheadChoices, isNot(contains(-1)));
  });
}
