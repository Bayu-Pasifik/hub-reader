import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/data/local/mihon_import.dart';
import 'package:hub_reader/data/local/source_library_store.dart';
import 'package:hub_reader/sources/source.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Src implements MangaSource {
  @override
  String get id => 'id.komiku';
  @override
  String get name => 'Komiku';
  @override
  String get baseUrl => 'https://komiku.id';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<int> _varint(int v) {
  final out = <int>[];
  while (v > 0x7f) {
    out.add((v & 0x7f) | 0x80);
    v >>= 7;
  }
  out.add(v);
  return out;
}

List<int> _int(int field, int v) => [..._varint(field << 3), ..._varint(v)];
List<int> _bytes(int field, List<int> b) => [..._varint((field << 3) | 2), ..._varint(b.length), ...b];
List<int> _s(int field, String s) => _bytes(field, utf8.encode(s));

void main() {
  test('parse + impor cadangan Mihon (gzip)', () async {
    final chapter = [..._s(1, '/ch-1/'), ..._int(4, 1), ..._int(6, 5)];
    final history = [..._s(1, '/ch-1/'), ..._int(2, 1700000000000)];
    final manga = [
      ..._int(1, 123),
      ..._s(2, '/manga/solo/'),
      ..._s(3, 'Solo Leveling'),
      ..._int(13, 1690000000000),
      ..._bytes(16, chapter),
      ..._int(17, 2),
      ..._int(100, 1),
      ..._bytes(104, history),
    ];
    final unknown = [..._int(1, 999), ..._s(2, '/x/'), ..._s(3, 'Lain'), ..._int(100, 1)];
    final data = [
      ..._bytes(1, manga),
      ..._bytes(1, unknown),
      ..._bytes(2, [..._s(1, 'Aksi'), ..._int(2, 2)]),
      ..._bytes(101, [..._s(1, 'Komiku'), ..._int(2, 123)]),
    ];
    final backup = MihonBackup.parse(gzip.encode(data));
    expect(backup.manga, hasLength(2));
    expect(backup.categories[2], 'Aksi');

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final r = await MihonImport.apply(prefs, backup, [_Src()]);
    expect(r.imported, 1);
    expect(r.skipped, 1);

    final store = SourceLibraryStore(prefs);
    final fav = store.readFavorites().single;
    expect(fav.item.url, 'https://komiku.id/manga/solo/');
    expect(fav.categories, ['Aksi']);
    final p = store.readProgress()[fav.item.key]!['https://komiku.id/ch-1/']!;
    expect(p.done, isTrue);
    expect(p.page, 5);
    expect(store.readHistory().single.readAt.millisecondsSinceEpoch, 1700000000000);
    expect(prefs.getStringList('library.categories.v1'), ['Aksi']);
  });

  test('file sembarang ditolak', () {
    expect(() => MihonBackup.parse(utf8.encode('{"not":"protobuf"}')), throwsFormatException);
  });
}
