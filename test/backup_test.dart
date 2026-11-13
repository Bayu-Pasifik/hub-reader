import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/data/local/backup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('backup round-trips prefs and keeps secrets out unless asked', () async {
    SharedPreferences.setMockInitialValues({
      'source_library.favorites.v1': '[{"item":{"source_id":"s","url":"u","title":"T"}}]',
      'library.categories.v1': <String>['Baca'],
      'novels.hide_broken.v1': true,
      'sources.cookies.v1': '{"a.com":"x=1"}',
      'lnr.kv.WTRLAB_DB_sessionCookie': 'secret',
      'downloads.index.v1': '[]',
    });
    final prefs = await SharedPreferences.getInstance();
    final data = jsonDecode(jsonEncode(await AppBackup.create(prefs, includeSecrets: false)));
    final keys = (data['prefs'] as Map).keys;
    expect(keys, containsAll(['source_library.favorites.v1', 'library.categories.v1', 'novels.hide_broken.v1']));
    expect(keys, isNot(contains('sources.cookies.v1')));
    expect(keys, isNot(contains('lnr.kv.WTRLAB_DB_sessionCookie')));
    expect(keys, isNot(contains('downloads.index.v1')));

    final summary = AppBackup.inspect(data)!;
    expect(summary.favorites, 1);
    expect(summary.secrets, isFalse);

    // Data di HP berubah, lalu dipulihkan.
    await prefs.setString('source_library.favorites.v1', '[]');
    await prefs.setString('extra.v1', 'hapus');
    await AppBackup.restore(prefs, data);
    expect(prefs.getString('source_library.favorites.v1'), contains('"T"'));
    expect(prefs.getStringList('library.categories.v1'), ['Baca']);
    expect(prefs.getBool('novels.hide_broken.v1'), isTrue);
    expect(prefs.containsKey('extra.v1'), isFalse);
    // Rahasia & indeks unduhan di HP tetap.
    expect(prefs.getString('sources.cookies.v1'), '{"a.com":"x=1"}');
    expect(prefs.getString('lnr.kv.WTRLAB_DB_sessionCookie'), 'secret');
    expect(prefs.getString('downloads.index.v1'), '[]');
  });

  test('inspect rejects other JSON files', () {
    expect(AppBackup.inspect({'hello': 1}), isNull);
  });
}
