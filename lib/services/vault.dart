import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'security.dart';

/// Encryption at rest.
///
/// A random 256-bit data key (DEK) encrypts the app state with AES-256-GCM.
/// The DEK is stored twice, each copy wrapped by a key-encryption key derived
/// with PBKDF2-HMAC-SHA256 from a secret: one from the PIN, one from the
/// recovery phrase. A wrong secret fails GCM authentication, so no PIN hash
/// needs to be stored at all.
class Vault {
  static final _aes = AesGcm.with256bits();
  static const iterations = 100000;

  static List<int> randomKey() {
    final r = Random.secure();
    return List<int>.generate(32, (_) => r.nextInt(256));
  }

  /// PBKDF2 runs off the UI isolate so unlocking never janks the UI.
  static Future<List<int>> _derive(String secret, String salt, int iter) =>
      Isolate.run(() => Security.deriveKey(secret, salt, iter));

  static Future<Map<String, dynamic>> seal(List<int> key, List<int> plain) async {
    final box = await _aes.encrypt(plain, secretKey: SecretKey(key));
    return {'n': base64Encode(box.nonce), 'c': base64Encode(box.cipherText), 'm': base64Encode(box.mac.bytes)};
  }

  /// Returns null when the key is wrong or the data was tampered with.
  static Future<List<int>?> open(List<int> key, Map<String, dynamic> blob) async {
    try {
      return await _aes.decrypt(
        SecretBox(base64Decode(blob['c']), nonce: base64Decode(blob['n']), mac: Mac(base64Decode(blob['m']))),
        secretKey: SecretKey(key),
      );
    } on SecretBoxAuthenticationError {
      return null;
    }
  }

  static Future<Map<String, dynamic>> wrap(String secret, List<int> dek) async {
    final salt = Security.newSalt();
    final kek = await _derive(secret, salt, iterations);
    return {...await seal(kek, dek), 's': salt, 'i': iterations};
  }

  static Future<List<int>?> unwrap(String secret, Map<String, dynamic> wrapped) async {
    final kek = await _derive(secret, wrapped['s'] as String, wrapped['i'] as int? ?? iterations);
    return open(kek, wrapped);
  }

  static Future<Map<String, dynamic>> encryptJson(List<int> dek, Map<String, dynamic> data) =>
      seal(dek, utf8.encode(jsonEncode(data)));

  static Future<Map<String, dynamic>?> decryptJson(List<int> dek, Map<String, dynamic> blob) async {
    final plain = await open(dek, blob);
    return plain == null ? null : jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
  }
}
