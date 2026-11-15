import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/core/crash/crash_log.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('crashlog');
    await CrashLog.install(dir: dir);
  });

  tearDown(() => dir.delete(recursive: true));

  test('records an entry with message, stack and context', () {
    CrashLog.record(StateError('boom'), StackTrace.current, context: 'saat membangun widget');
    final text = CrashLog.read();
    expect(text, contains('boom'));
    expect(text, contains('saat membangun widget'));
    expect(text, contains('---'));
  });

  test('clear removes the file and read returns empty', () {
    CrashLog.record('x', null);
    CrashLog.clear();
    expect(CrashLog.read(), isEmpty);
  });

  test('file is trimmed to stay under the size cap, newest entry kept', () {
    final big = 'e' * 4000;
    for (var i = 0; i < 80; i++) {
      CrashLog.record('$big#$i', null);
    }
    expect(CrashLog.file!.lengthSync(), lessThan(CrashLog.maxBytes + 4100));
    expect(CrashLog.read(), contains('#79'));
    expect(CrashLog.read(), isNot(contains('#0\n')));
  });
}
