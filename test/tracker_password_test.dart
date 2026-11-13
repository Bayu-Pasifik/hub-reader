import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/data/local/backup.dart';
import 'package:hub_reader/trackers/kitsu.dart';
import 'package:hub_reader/trackers/mangaupdates.dart';
import 'package:hub_reader/trackers/tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _Req = ({String method, String url, String body, Map<String, dynamic> headers});

/// Adapter Dio palsu: mencatat request, membalas dari [respond].
class _Fake implements HttpClientAdapter {
  _Fake(this.respond);

  final (int, Object?) Function(_Req req) respond;
  final log = <_Req>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    final bytes = body == null ? <int>[] : await body.expand((b) => b).toList();
    final req = (method: o.method, url: o.uri.toString(), body: utf8.decode(bytes), headers: o.headers);
    log.add(req);
    final (status, data) = respond(req);
    return ResponseBody.fromString(
      data == null ? '' : jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_Fake fake) => Dio()..httpClientAdapter = fake;

void main() {
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('Kitsu', () {
    test('password login stores token and user, never the password', () async {
      final fake = _Fake((r) {
        if (r.url.contains('/oauth/token')) return (200, {'access_token': 'AT', 'refresh_token': 'RT'});
        if (r.url.contains('/users')) {
          return (
            200,
            {
              'data': [
                {
                  'id': '42',
                  'attributes': {'name': 'neko'},
                },
              ],
            }
          );
        }
        return (404, null);
      });
      final t = KitsuTracker(prefs, dio: _dio(fake));
      await t.loginWithPassword('me@example.com', 'hunter2');
      expect(t.loggedIn, isTrue);
      expect(t.username, 'neko');
      expect(fake.log.first.body, contains('grant_type=password'));
      expect(fake.log[1].headers['Authorization'], 'Bearer AT');
      expect(prefs.getKeys().map(prefs.get).join(), isNot(contains('hunter2')));
    });

    test('wrong password is reported', () async {
      final t = KitsuTracker(prefs, dio: _dio(_Fake((_) => (400, {'error': 'invalid_grant'}))));
      expect(
        () => t.loginWithPassword('a', 'b'),
        throwsA(isA<TrackerException>().having((e) => e.message, 'message', contains('salah'))),
      );
    });

    test('update creates a library entry, then patches it', () async {
      await prefs.setString('tracker.kitsu.token', 'AT');
      await prefs.setString('tracker.kitsu.user_id', '42');
      var hasEntry = false;
      final fake = _Fake((r) {
        if (r.url.contains('/library-entries?')) {
          return (
            200,
            {
              'data': [
                if (hasEntry)
                  {
                    'id': '900',
                    'attributes': {'status': 'current', 'progress': 3, 'reconsuming': false},
                  },
              ],
            }
          );
        }
        if (r.method == 'POST') hasEntry = true;
        return (200, {'data': {}});
      });
      final t = KitsuTracker(prefs, dio: _dio(fake));
      await t.update(7, progress: 3, status: TrackStatus.reading);
      final post = fake.log.firstWhere((r) => r.method == 'POST');
      expect(post.url, endsWith('/library-entries'));
      final created = jsonDecode(post.body) as Map;
      expect(created['data']['relationships']['media']['data'], {'id': '7', 'type': 'manga'});
      expect(created['data']['attributes']['status'], 'current');

      await t.update(7, progress: 10, status: TrackStatus.completed);
      final patch = fake.log.firstWhere((r) => r.method == 'PATCH');
      expect(patch.url, endsWith('/library-entries/900'));
      expect((jsonDecode(patch.body) as Map)['data']['attributes'], {
        'status': 'completed',
        'progress': 10,
        'reconsuming': false,
      });
    });

    test('search prefers novels for novel series', () async {
      final fake = _Fake((_) => (
            200,
            {
              'data': [
                {
                  'id': '1',
                  'attributes': {'canonicalTitle': 'Solo Leveling', 'subtype': 'manhwa', 'slug': 'solo'},
                },
                {
                  'id': '2',
                  'attributes': {'canonicalTitle': 'Solo Leveling', 'subtype': 'novel', 'chapterCount': 270},
                },
              ],
            }
          ));
      final t = KitsuTracker(prefs, dio: _dio(fake));
      expect((await t.search('solo', novel: true)).single.total, 270);
      expect((await t.search('solo', novel: false)).single.url, 'https://kitsu.app/manga/solo');
    });
  });

  group('MangaUpdates', () {
    test('login keeps the session token only', () async {
      final fake = _Fake((r) => r.url.endsWith('/account/login')
          ? (
              200,
              {
                'status': 'success',
                'context': {'session_token': 'S', 'uid': 5},
              }
            )
          : (404, null));
      final t = MangaUpdatesTracker(prefs, dio: _dio(fake));
      await t.loginWithPassword('neko', 'hunter2');
      expect(t.token, 'S');
      expect(t.username, 'neko');
      expect(fake.log.single.method, 'PUT');
      expect(prefs.getKeys().map(prefs.get).join(), isNot(contains('hunter2')));
    });

    test('login error shows the site reason', () async {
      final t = MangaUpdatesTracker(
        prefs,
        dio: _dio(_Fake((_) => (401, {'status': 'exception', 'reason': 'No user found'}))),
      );
      expect(
        () => t.loginWithPassword('a', 'b'),
        throwsA(isA<TrackerException>().having((e) => e.message, 'message', 'No user found')),
      );
    });

    test('series not in a list: entry is empty and update adds it', () async {
      await prefs.setString('tracker.mangaupdates.token', 'S');
      final fake = _Fake((r) => r.method == 'GET' ? (404, {'reason': 'not found'}) : (200, {'status': 'success'}));
      final t = MangaUpdatesTracker(prefs, dio: _dio(fake));
      expect((await t.entry(15180124327))?.status, isNull);
      await t.update(15180124327, progress: 12, status: TrackStatus.onHold);
      final add = fake.log.last;
      expect(add.url, endsWith('/lists/series/add'));
      expect(jsonDecode(add.body), [
        {
          'series': {'id': 15180124327},
          'list_id': 4,
          'status': {'chapter': 12},
        },
      ]);
    });

    test('series already in a list: entry maps list_id and update moves it', () async {
      await prefs.setString('tracker.mangaupdates.token', 'S');
      final fake = _Fake((r) => r.method == 'GET'
          ? (
              200,
              {
                'list_id': 2,
                'status': {'chapter': 200},
              }
            )
          : (200, {'status': 'success'}));
      final t = MangaUpdatesTracker(prefs, dio: _dio(fake));
      final e = await t.entry(1);
      expect(e?.status, TrackStatus.completed);
      expect(e?.progress, 200);
      await t.update(1, progress: 201, status: TrackStatus.rereading);
      expect(fake.log.last.url, endsWith('/lists/series/update'));
      expect((jsonDecode(fake.log.last.body) as List).single['list_id'], 0);
    });
  });

  test('Kitsu and MangaUpdates sessions are secrets in backups', () {
    expect(AppBackup.isSecretKey('tracker.kitsu.token'), isTrue);
    expect(AppBackup.isSecretKey('tracker.kitsu.refresh'), isTrue);
    expect(AppBackup.isSecretKey('tracker.mangaupdates.token'), isTrue);
    expect(AppBackup.isSecretKey('tracker.links.v1'), isFalse);
  });
}
