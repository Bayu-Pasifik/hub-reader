import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/state/similar_series.dart';

SourceMangaDetails _d({String title = 'Kimi no Na wa', String? author, String? artist}) => SourceMangaDetails(
      url: 'u',
      title: title,
      author: author,
      artist: artist,
      genres: const [],
      status: SourceMangaStatus.ongoing,
      chapters: const [],
    );

void main() {
  test('penulis dulu, lalu kata awal judul', () {
    expect(similarQueries(_d(author: 'Nishi Jouyou')), ['Nishi Jouyou', 'Kimi no', 'Kimi no Na', 'Kimi']);
  });

  test('penulis kosong atau "-" dilewati, artis sama tidak diulang', () {
    expect(similarQueries(_d(author: '-', artist: '-', title: 'So')), isEmpty);
    expect(similarQueries(_d(author: 'A B', artist: 'A B', title: 'X Y')), ['A B', 'X Y']);
  });
}
