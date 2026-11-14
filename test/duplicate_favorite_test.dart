import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/data/models/source_library.dart';

SourceFavorite fav(String source, String url, String title) =>
    SourceFavorite(item: SourceLibraryItem(sourceId: source, url: url, title: title), addedAt: DateTime(2026));

void main() {
  final existing = [fav('a', 'u1', 'Solo Leveling!'), fav('lnr:x', 'p1', 'Omniscient Reader')];

  test('judul sama dari sumber lain terdeteksi (abaikan besar kecil & tanda baca)', () {
    final item = const SourceLibraryItem(sourceId: 'b', url: 'u2', title: 'solo  leveling');
    expect(findDuplicateFavorite(existing, item)?.item.key, 'a|u1');
  });

  test('item yang sama tidak dianggap duplikat', () {
    final item = const SourceLibraryItem(sourceId: 'a', url: 'u1', title: 'Solo Leveling!');
    expect(findDuplicateFavorite(existing, item), isNull);
  });

  test('komik dan novel tidak saling dianggap duplikat', () {
    final item = const SourceLibraryItem(sourceId: 'b', url: 'u3', title: 'Omniscient Reader');
    expect(findDuplicateFavorite(existing, item), isNull);
  });
}
