import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PBKDF2-HMAC-SHA256 hashing for passwords and PINs.
///
/// Stored format: `pbkdf2-sha256$<iterations>$<salt b64>$<hash b64>`.
class PasswordHasher {
  const PasswordHasher({this.iterations = 60000});

  final int iterations;

  Future<String> hash(String secret) {
    final salt = _randomBytes(16);
    final iters = iterations;
    return Isolate.run(
      () => _encode(iters, salt, _pbkdf2(secret, salt, iters)),
    );
  }

  Future<bool> verify(String secret, String stored) {
    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != 'pbkdf2-sha256') {
      return Future.value(false);
    }
    final iters = int.tryParse(parts[1]);
    if (iters == null) return Future.value(false);
    final salt = base64Decode(parts[2]);
    final expected = base64Decode(parts[3]);
    return Isolate.run(
      () => _constantTimeEquals(_pbkdf2(secret, salt, iters), expected),
    );
  }

  static String _encode(int iters, List<int> salt, List<int> hash) =>
      'pbkdf2-sha256\$$iters\$${base64Encode(salt)}\$${base64Encode(hash)}';

  static Uint8List _pbkdf2(String secret, List<int> salt, int iterations) {
    final hmac = Hmac(sha256, utf8.encode(secret));
    // One 32-byte block is all we need (block index 1).
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final out = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < out.length; j++) {
        out[j] ^= u[j];
      }
    }
    return out;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static List<int> _randomBytes(int n) {
    final r = Random.secure();
    return List<int>.generate(n, (_) => r.nextInt(256));
  }
}
