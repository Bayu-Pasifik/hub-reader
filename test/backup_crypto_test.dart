import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/data/local/auto_backup.dart';
import 'package:hub_reader/data/local/backup.dart';
import 'package:hub_reader/data/local/backup_crypto.dart';
import 'package:hub_reader/novels/plugin_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('round trip: encrypted text hides content and opens with the right password', () async {
    final data = {'format': AppBackup.format, 'secrets': true, 'token': 'rahasia-banget'};
    final text = await BackupCrypto.encode(data, password: 'sandi-ku');
    expect(text, isNot(contains('rahasia-banget')));
    final envelope = jsonDecode(text);
    expect(BackupCrypto.isEncrypted(envelope), isTrue);
    expect(await BackupCrypto.decrypt(envelope, 'sandi-ku'), data);
  });

  test('wrong password and tampered data are rejected', () async {
    final text = await BackupCrypto.encode({'a': 1}, password: 'benar');
    final envelope = jsonDecode(text) as Map<String, Object?>;
    await expectLater(BackupCrypto.decrypt(envelope, 'salah'), throwsA(isA<BackupPasswordException>()));

    final bytes = base64Decode(envelope['data']! as String)..[0] ^= 1;
    final tampered = {...envelope, 'data': base64Encode(bytes)};
    await expectLater(BackupCrypto.decrypt(tampered, 'benar'), throwsA(isA<BackupPasswordException>()));
  });

  test('same password gives different ciphertext (random salt/nonce)', () async {
    final a = await BackupCrypto.encode({'a': 1}, password: 'x');
    final b = await BackupCrypto.encode({'a': 1}, password: 'x');
    expect(a, isNot(b));
  });

  test('empty password keeps plain JSON', () async {
    final text = await BackupCrypto.encode({'a': 1});
    expect(jsonDecode(text), {'a': 1});
    expect(BackupCrypto.isEncrypted(jsonDecode(text)), isFalse);
  });

  test('absurd iteration count in a crafted envelope is refused', () async {
    final text = await BackupCrypto.encode({'a': 1}, password: 'x');
    final env = {...(jsonDecode(text) as Map<String, Object?>), 'iterations': 999999999};
    await expectLater(BackupCrypto.decrypt(env, 'x'), throwsA(isA<FormatException>()));
  });

  test('automatic backup is encrypted when enabled and restorable with the password', () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      'source_library.favorites.v1': '[{"item":{"source_id":"s","url":"u","title":"T"}}]',
    });
    final prefs = await SharedPreferences.getInstance();
    final tmp = await Directory.systemTemp.createTemp('enc_auto');
    AutoBackup.directoryOverride = Directory('${tmp.path}/backups');
    addTearDown(() async {
      AutoBackup.directoryOverride = null;
      await tmp.delete(recursive: true);
    });

    await AutoBackup.setAutoPassword(prefs, 'pw-otomatis');
    final file = await AutoBackup.run(
      prefs,
      NovelPluginRepository(Directory('${tmp.path}/lnreader')),
      config: const AutoBackupConfig(hours: 24, keep: 3, plugins: false, secrets: false),
    );
    final raw = jsonDecode(await file.readAsString());
    expect(BackupCrypto.isEncrypted(raw), isTrue);
    final opened = await BackupCrypto.decrypt(raw, 'pw-otomatis');
    expect(AppBackup.inspect(opened)?.favorites, 1);
  });

  test('encryption requested but password unreadable fails instead of writing plain', () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({AutoBackup.encryptedKey: true});
    final prefs = await SharedPreferences.getInstance();
    await expectLater(AutoBackup.autoPassword(prefs), throwsStateError);
  });
}
