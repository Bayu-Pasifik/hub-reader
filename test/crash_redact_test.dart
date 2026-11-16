import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/core/crash/crash_log.dart';

void main() {
  test('redact menyamarkan data pribadi', () {
    const raw = 'GET https://x.id/api?token=abc123&page=2 gagal\n'
        r'user me@mail.com di C:\Users\Budi\AppData\Roaming'
        '\n'
        'Cookie: cf_clearance=zzz; a=b\n'
        'file /data/user/0/com.x/cache';
    final out = CrashLog.redact(raw);
    expect(out, isNot(contains('abc123')));
    expect(out, contains('page=2'));
    expect(out, isNot(contains('me@mail.com')));
    expect(out, isNot(contains('Budi')));
    expect(out, isNot(contains('cf_clearance')));
    expect(out, contains('/data/user/0/com.x/cache'));
  });
}
