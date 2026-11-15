import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

/// Kata sandi salah, atau berkas rusak/diubah (GCM gagal memverifikasi tag).
class BackupPasswordException implements Exception {
  const BackupPasswordException();

  @override
  String toString() => 'Kata sandi salah atau cadangan rusak';
}

/// Enkripsi cadangan: AES-256-GCM dengan kunci dari PBKDF2-HMAC-SHA256.
///
/// Hasilnya amplop JSON (`format: hub_reader-backup-enc`) berisi salt, nonce,
/// dan ciphertext+tag (base64). Cadangan berisi token tracker dan cookie login,
/// jadi sandi opsional ini melindunginya saat file disimpan di cloud/WebDAV.
abstract final class BackupCrypto {
  static const encFormat = 'hub_reader-backup-enc';

  /// Iterasi PBKDF2 tersimpan di amplop, jadi bisa dinaikkan nanti tanpa
  /// merusak cadangan lama.
  static const iterations = 210000;

  static const _autoKey = 'backup.auto.enc';
  static const _storage = FlutterSecureStorage();

  static bool isEncrypted(Object? decoded) => decoded is Map && decoded['format'] == encFormat;

  /// Teks cadangan siap simpan: JSON polos bila [password] kosong, selain itu
  /// amplop terenkripsi. PBKDF2 dijalankan di isolate agar UI tidak macet.
  static Future<String> encode(Object data, {String? password}) async {
    final json = jsonEncode(data);
    if (password == null || password.isEmpty) return json;
    final rnd = Random.secure();
    Uint8List random(int n) => Uint8List.fromList([for (var i = 0; i < n; i++) rnd.nextInt(256)]);
    final salt = random(16);
    final nonce = random(12);
    final plain = Uint8List.fromList(utf8.encode(json));
    final sealed = await Isolate.run(() => _seal(plain, password, salt, nonce, iterations));
    return jsonEncode({
      'format': encFormat,
      'version': 1,
      'kdf': 'pbkdf2-sha256',
      'iterations': iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'data': base64Encode(sealed),
    });
  }

  /// Buka amplop terenkripsi. Melempar [BackupPasswordException] bila sandi salah.
  static Future<Object?> decrypt(Object? envelope, String password) async {
    final m = envelope is Map ? envelope : const {};
    final Uint8List salt, nonce, data;
    final int iter;
    try {
      salt = base64Decode('${m['salt']}');
      nonce = base64Decode('${m['nonce']}');
      data = base64Decode('${m['data']}');
      iter = (m['iterations'] as num).toInt();
    } on Object {
      throw const FormatException('Amplop cadangan rusak');
    }
    if (iter < 1 || iter > 5000000) throw const FormatException('Amplop cadangan rusak');
    final Uint8List plain;
    try {
      plain = await Isolate.run(() => _open(data, password, salt, nonce, iter));
    } on InvalidCipherTextException {
      throw const BackupPasswordException();
    }
    return jsonDecode(utf8.decode(plain));
  }

  static Uint8List _key(String password, Uint8List salt, int iter) {
    final kdf = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iter, 32));
    return kdf.process(Uint8List.fromList(utf8.encode(password)));
  }

  static Uint8List _seal(Uint8List plain, String password, Uint8List salt, Uint8List nonce, int iter) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(_key(password, salt, iter)), 128, nonce, Uint8List(0)));
    return cipher.process(plain);
  }

  static Uint8List _open(Uint8List data, String password, Uint8List salt, Uint8List nonce, int iter) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(_key(password, salt, iter)), 128, nonce, Uint8List(0)));
    return cipher.process(data);
  }

  /// Sandi untuk cadangan otomatis/WebDAV (tanpa UI saat berjalan di latar),
  /// disimpan di Keystore, tidak pernah ikut cadangan.
  static Future<String> readAutoPassword() async {
    try {
      return await _storage.read(key: _autoKey) ?? '';
    } on Object {
      return '';
    }
  }

  static Future<void> writeAutoPassword(String password) async {
    try {
      if (password.isEmpty) {
        await _storage.delete(key: _autoKey);
      } else {
        await _storage.write(key: _autoKey, value: password);
      }
    } on Object {
      // Keystore tidak tersedia: cadangan otomatis tetap polos.
    }
  }
}
