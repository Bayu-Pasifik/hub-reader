import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/data/local/auto_backup.dart';
import 'package:hub_reader/data/local/backup.dart';
import 'package:hub_reader/novels/plugin_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tmp;
  late NovelPluginRepository plugins;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('auto_backup_test');
    AutoBackup.directoryOverride = Directory('${tmp.path}/backups');
    plugins = NovelPluginRepository(Directory('${tmp.path}/lnreader'));
  });

  tearDown(() async {
    AutoBackup.directoryOverride = null;
    await tmp.delete(recursive: true);
  });

  test('isDue follows enabled flag and interval', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const off = AutoBackupConfig(hours: 0, keep: 5, plugins: true, secrets: false);
    const daily = AutoBackupConfig(hours: 24, keep: 5, plugins: true, secrets: false);
    final now = DateTime(2026, 11, 14, 12);

    expect(AutoBackup.isDue(prefs, off, now: now), isFalse);
    expect(AutoBackup.isDue(prefs, daily, now: now), isTrue); // belum pernah

    await prefs.setInt('backup.auto.last.v1', now.subtract(const Duration(hours: 23)).millisecondsSinceEpoch);
    expect(AutoBackup.isDue(prefs, daily, now: now), isFalse);
    await prefs.setInt('backup.auto.last.v1', now.subtract(const Duration(hours: 24)).millisecondsSinceEpoch);
    expect(AutoBackup.isDue(prefs, daily, now: now), isTrue);
  });

  test('run writes a restorable backup, skips secrets, and prunes old files', () async {
    SharedPreferences.setMockInitialValues({
      'source_library.favorites.v1': '[{"item":{"source_id":"s","url":"u","title":"T"}}]',
      'sources.cookies.v1': '{"a.com":"x=1"}',
    });
    final prefs = await SharedPreferences.getInstance();
    const config = AutoBackupConfig(hours: 24, keep: 2, plugins: true, secrets: false);

    final base = DateTime(2026, 11, 10, 8);
    for (var i = 0; i < 4; i++) {
      final file = await AutoBackup.run(prefs, plugins, config: config, now: base.add(Duration(days: i)));
      // mtime dipakai untuk urutan; atur eksplisit agar test tidak bergantung pada kecepatan tulis.
      await file.setLastModified(base.add(Duration(days: i)));
    }

    final list = await AutoBackup.list();
    expect(list, hasLength(2));
    expect(list.first.modified.isAfter(list.last.modified), isTrue);
    expect(list.first.name, contains('20261113'));
    expect(Directory('${tmp.path}/backups').listSync().where((e) => e.path.endsWith('.tmp')), isEmpty);

    final data = jsonDecode(await list.first.file.readAsString());
    expect((data['prefs'] as Map).keys, contains('source_library.favorites.v1'));
    expect((data['prefs'] as Map).keys, isNot(contains('sources.cookies.v1')));
    expect(AppBackup.inspect(data)!.favorites, 1);
    expect(AutoBackup.lastRun(prefs), base.add(const Duration(days: 3)));
  });

  test('config round-trips through prefs', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(AutoBackupConfig.read(prefs).enabled, isFalse);
    await const AutoBackupConfig(hours: 72, keep: 10, plugins: false, secrets: true).write(prefs);
    final read = AutoBackupConfig.read(prefs);
    expect([read.hours, read.keep, read.plugins, read.secrets], [72, 10, false, true]);
  });
}
