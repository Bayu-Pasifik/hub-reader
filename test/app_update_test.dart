import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/core/update/app_update.dart';
import 'package:hub_reader/data/local/backup.dart';
import 'package:hub_reader/state/app_update_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('tag comes from the releases/latest redirect', () {
    expect(AppUpdate.tagFromLocation('https://github.com/Bayu-Pasifik/hub-reader/releases/tag/v1.2.0'), 'v1.2.0');
    expect(AppUpdate.tagFromLocation('/Bayu-Pasifik/hub-reader/releases/tag/v1.2.0/'), 'v1.2.0');
    // Belum ada rilis: GitHub mengalihkan ke daftar rilis.
    expect(AppUpdate.tagFromLocation('https://github.com/Bayu-Pasifik/hub-reader/releases'), isNull);
    expect(AppUpdate.tagFromLocation(null), isNull);
  });

  test('release URLs match the CI asset name', () {
    final r = AppUpdate.releaseFor('v1.2.0');
    expect(r.version, '1.2.0');
    expect(
        r.apk.toString(), 'https://github.com/Bayu-Pasifik/hub-reader/releases/download/v1.2.0/hub-reader-1.2.0.apk');
    expect(r.page.toString(), 'https://github.com/Bayu-Pasifik/hub-reader/releases/tag/v1.2.0');
  });

  test('version compare', () {
    expect(AppUpdate.compare('1.0.1', '1.0.0'), greaterThan(0));
    expect(AppUpdate.compare('1.10.0', '1.9.9'), greaterThan(0));
    expect(AppUpdate.compare('v1.2', '1.2.0'), 0);
    expect(AppUpdate.compare('1.0.0+5', '1.0.0'), 0);
    expect(AppUpdate.compare('1.0.0', '2.0.0-beta'), lessThan(0));
  });

  group('auto check', () {
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });
    final now = DateTime(2026, 11, 13, 12);
    Future<AppRelease?> v(String tag) async => AppUpdate.releaseFor(tag);

    test('offers a newer release once per day', () async {
      var calls = 0;
      Future<AppRelease?> fetch() {
        calls++;
        return v('v1.1.0');
      }

      final first = await UpdatePolicy.autoCheck(prefs, current: '1.0.0', fetch: fetch, now: now);
      expect(first?.version, '1.1.0');
      final again = await UpdatePolicy.autoCheck(
        prefs,
        current: '1.0.0',
        fetch: fetch,
        now: now.add(const Duration(hours: 3)),
      );
      expect(again, isNull);
      expect(calls, 1);
      final nextDay = await UpdatePolicy.autoCheck(
        prefs,
        current: '1.0.0',
        fetch: fetch,
        now: now.add(const Duration(hours: 25)),
      );
      expect(nextDay?.version, '1.1.0');
    });

    test('same or older release is not offered', () async {
      expect(await UpdatePolicy.autoCheck(prefs, current: '1.1.0', fetch: () => v('v1.1.0'), now: now), isNull);
    });

    test('"later" hides that version until a newer one ships', () async {
      await UpdatePolicy.skip(prefs, AppUpdate.releaseFor('v1.1.0'));
      expect(await UpdatePolicy.autoCheck(prefs, current: '1.0.0', fetch: () => v('v1.1.0'), now: now), isNull);
      final later = now.add(const Duration(days: 2));
      expect((await UpdatePolicy.autoCheck(prefs, current: '1.0.0', fetch: () => v('v1.2.0'), now: later))?.version,
          '1.2.0');
    });

    test('network errors are swallowed and retried next launch', () async {
      final r = await UpdatePolicy.autoCheck(
        prefs,
        current: '1.0.0',
        fetch: () => Future.error(Exception('offline')),
        now: now,
      );
      expect(r, isNull);
      expect(prefs.getInt(UpdatePolicy.lastCheckKey), isNull);
    });

    test('update schedule is not part of backups', () async {
      await prefs.setInt(UpdatePolicy.lastCheckKey, 1);
      await prefs.setString(UpdatePolicy.skippedKey, '1.1.0');
      await prefs.setBool('app.check_updates.v1', false);
      final backup = await AppBackup.create(prefs, includeSecrets: false);
      final keys = backup.toString();
      expect(keys, isNot(contains(UpdatePolicy.lastCheckKey)));
      expect(keys, isNot(contains(UpdatePolicy.skippedKey)));
      expect(keys, contains('app.check_updates.v1'));
    });
  });
}
