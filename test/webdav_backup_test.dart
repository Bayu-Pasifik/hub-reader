import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/data/local/auto_backup.dart';
import 'package:hub_reader/data/local/webdav_backup.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WebDAV mini di memori: MKCOL, PUT, GET, DELETE, PROPFIND (+ Basic auth).
class _FakeDav {
  _FakeDav(this.server, {required this.auth});

  final HttpServer server;
  final String auth;
  final files = <String, List<int>>{};
  final modified = <String, DateTime>{};
  bool folder = false;
  int rejected = 0;

  static Future<_FakeDav> start({String user = 'me', String pass = 'pw'}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final dav = _FakeDav(server, auth: 'Basic ${base64Encode(utf8.encode('$user:$pass'))}');
    server.listen(dav._handle);
    return dav;
  }

  String get url => 'http://127.0.0.1:${server.port}/dav/HubReader';

  Future<void> _handle(HttpRequest req) async {
    if (req.headers.value('authorization') != auth) {
      rejected++;
      req.response.statusCode = 401;
      await req.response.close();
      return;
    }
    final path = req.uri.path;
    final name = Uri.decodeComponent(path.split('/').last);
    switch (req.method) {
      case 'MKCOL':
        req.response.statusCode = folder ? 405 : 201;
        folder = true;
      case 'PUT':
        files[name] = await req.fold<List<int>>([], (a, b) => a..addAll(b));
        modified[name] = DateTime.utc(2026, 11, 15, 8, 0, files.length);
        req.response.statusCode = 201;
      case 'GET':
        final data = files[name];
        req.response.statusCode = data == null ? 404 : 200;
        if (data != null) req.response.add(data);
      case 'DELETE':
        req.response.statusCode = files.remove(name) == null ? 404 : 204;
      case 'PROPFIND':
        req.response.statusCode = 207;
        req.response.headers.contentType = ContentType('application', 'xml', charset: 'utf-8');
        final rows = StringBuffer('<d:response><d:href>/dav/HubReader/</d:href></d:response>');
        files.forEach((n, bytes) {
          final m = modified[n]!;
          rows.write('<d:response><d:href>/dav/HubReader/${Uri.encodeComponent(n)}</d:href><d:propstat><d:prop>'
              '<d:getlastmodified>Sun, 15 Nov 2026 ${m.hour.toString().padLeft(2, '0')}:00:${m.second.toString().padLeft(2, '0')} GMT</d:getlastmodified>'
              '<d:getcontentlength>${bytes.length}</d:getcontentlength></d:prop></d:propstat></d:response>');
        });
        req.response.write('<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">$rows</d:multistatus>');
      default:
        req.response.statusCode = 405;
    }
    await req.response.close();
  }

  Future<void> close() => server.close(force: true);
}

void main() {
  late _FakeDav dav;
  late SharedPreferences prefs;

  WebDavConfig config({String pass = 'pw', bool enabled = true}) =>
      WebDavConfig(url: dav.url, username: 'me', password: pass, enabled: enabled);

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    dav = await _FakeDav.start();
  });

  tearDown(() async {
    AutoBackup.webDavClient = null;
    await dav.close();
  });

  test('upload creates the folder, stores the file, and lists it back', () async {
    final client = WebDavClient(config());
    await client.upload('hub_reader_auto_1.json', utf8.encode('{"a":1}'));
    expect(dav.folder, isTrue);
    expect(utf8.decode(dav.files['hub_reader_auto_1.json']!), '{"a":1}');
    final listed = await client.list();
    expect(listed.map((f) => f.name), ['hub_reader_auto_1.json']);
    expect(listed.single.size, 7);
    expect(await client.download('hub_reader_auto_1.json'), '{"a":1}');
  });

  test('plain HTTP to a public host is refused before any request is sent', () async {
    const cfg = WebDavConfig(url: 'http://cloud.example.com/dav', username: 'me', password: 'pw');
    await expectLater(
      WebDavClient(cfg).test(),
      throwsA(isA<WebDavException>().having((e) => e.message, 'message', contains('HTTPS'))),
    );
  });

  test('wrong password reports a readable login error', () async {
    await expectLater(
      WebDavClient(config(pass: 'nope')).test(),
      throwsA(isA<WebDavException>().having((e) => e.message, 'message', contains('login ditolak'))),
    );
  });

  test('prune keeps only the newest automatic backups on the server', () async {
    final client = WebDavClient(config());
    for (var i = 1; i <= 4; i++) {
      await client.upload('hub_reader_auto_$i.json', utf8.encode('{}'));
    }
    await client.upload('manual.json', utf8.encode('{}'));
    await client.prune(2);
    expect(dav.files.keys.toSet(), {'hub_reader_auto_3.json', 'hub_reader_auto_4.json', 'manual.json'});
  });

  test('listing parser handles prefixed namespaces and sorts newest first', () {
    const xml = '''<?xml version="1.0"?><D:multistatus xmlns:D="DAV:">
<D:response><D:href>/x/</D:href></D:response>
<D:response><D:href>/x/a%20b.json</D:href><D:propstat><D:prop><D:getlastmodified>Mon, 02 Nov 2026 10:00:00 GMT</D:getlastmodified><D:getcontentlength>10</D:getcontentlength></D:prop></D:propstat></D:response>
<D:response><D:href>/x/c.json</D:href><D:propstat><D:prop><D:getlastmodified>Sun, 15 Nov 2026 10:00:00 GMT</D:getlastmodified><D:getcontentlength>20</D:getcontentlength></D:prop></D:propstat></D:response>
<D:response><D:href>/x/readme.txt</D:href></D:response></D:multistatus>''';
    final files = WebDavClient.parseListing(xml);
    expect(files.map((f) => f.name), ['c.json', 'a b.json']);
    expect(files.last.size, 10);
  });

  test('uploadToWebDav does nothing while disabled', () async {
    await config(enabled: false).write(prefs);
    await AutoBackup.uploadToWebDav(prefs, 'x.json', [1], keep: 3);
    expect(dav.files, isEmpty);
  });

  test('uploadToWebDav uploads when enabled and records the status', () async {
    await config().write(prefs);
    await AutoBackup.uploadToWebDav(prefs, 'hub_reader_auto_9.json', utf8.encode('{}'), keep: 3);
    expect(dav.files.keys, ['hub_reader_auto_9.json']);
    expect(prefs.getString(AutoBackup.webDavStatusKey), startsWith('ok|'));
  });

  test('a failing server never throws for automatic uploads but records the error', () async {
    await config(pass: 'wrong').write(prefs);
    await AutoBackup.uploadToWebDav(prefs, 'x.json', [1], keep: 3);
    expect(prefs.getString(AutoBackup.webDavStatusKey), startsWith('error|'));
    // Unggah manual (force) melempar supaya UI bisa menampilkan alasannya.
    await expectLater(
      AutoBackup.uploadToWebDav(prefs, 'x.json', [1], keep: 3, force: true),
      throwsA(isA<WebDavException>()),
    );
  });
}
