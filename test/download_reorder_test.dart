import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/state/download_providers.dart';

void main() {
  const l = ['a', 'b', 'c', 'd'];

  test('pindah ke bawah memakai konvensi ReorderableListView', () {
    expect(reorderList(l, 0, 3), ['b', 'c', 'a', 'd']);
    expect(reorderList(l, 0, 4), ['b', 'c', 'd', 'a']);
  });

  test('pindah ke atas', () {
    expect(reorderList(l, 3, 0), ['d', 'a', 'b', 'c']);
    expect(reorderList(l, 2, 1), ['a', 'c', 'b', 'd']);
  });

  test('tidak ada perubahan atau indeks tak valid mengembalikan null', () {
    expect(reorderList(l, 1, 1), isNull);
    expect(reorderList(l, 1, 2), isNull);
    expect(reorderList(l, -1, 2), isNull);
    expect(reorderList(l, 4, 0), isNull);
    expect(reorderList(l, 0, 5), isNull);
  });

  test('daftar asli tidak diubah', () {
    final copy = [...l];
    reorderList(copy, 0, 3);
    expect(copy, l);
  });
}
