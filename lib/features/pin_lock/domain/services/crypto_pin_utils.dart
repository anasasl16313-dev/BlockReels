import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Cryptographic service providing PBKDF2-HMAC-SHA256 PIN hashing.
class CryptoPinUtils {
  static const String _prefix = 'pbkdf2_sha256';
  static const int defaultIterations = 120000;
  static const int _keyLength = 32;

  /// Hashes [pin] with a random or supplied [salt] using PBKDF2-HMAC-SHA256.
  static Future<String> hashPin(
    String pin,
    String salt, {
    int iterations = defaultIterations,
  }) =>
      Isolate.run(() => _hashPin(pin, salt, iterations: iterations));

  static String _hashPin(
    String pin,
    String salt, {
    int iterations = defaultIterations,
  }) {
    final derived = _pbkdf2(
      utf8.encode(pin),
      utf8.encode(salt),
      iterations,
      _keyLength,
    );
    return '$_prefix\$$iterations\$${base64Encode(derived)}';
  }

  /// Verifies an entered PIN, accepting legacy SHA-256 hashes for migration.
  static Future<bool> verifyPin(
          String enteredPin, String storedHash, String salt) =>
      Isolate.run(() => _verifyPin(enteredPin, storedHash, salt));

  static bool _verifyPin(String enteredPin, String storedHash, String salt) {
    if (storedHash.startsWith('$_prefix\$')) {
      final parts = storedHash.split(r'$');
      if (parts.length != 3) return false;
      final iterations = int.tryParse(parts[1]);
      if (iterations == null || iterations <= 0 || iterations > defaultIterations * 2) return false;
      final computed = _hashPin(enteredPin, salt, iterations: iterations);
      return _constantTimeEquals(computed, storedHash);
    }

    final computedHash = _legacyHashPin(enteredPin, salt);
    if (_constantTimeEquals(computedHash, storedHash)) {
      return true;
    }
    final singleSaltHash = _legacyHashPinSingleSalt(enteredPin, salt);
    return _constantTimeEquals(singleSaltHash, storedHash);
  }

  /// Whether [storedHash] uses the legacy SHA-256 format.
  static bool isLegacyHash(String storedHash) =>
      !storedHash.startsWith('$_prefix\$');

  static String _legacyHashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin:$salt');
    return sha256.convert(bytes).toString();
  }

  static String _legacyHashPinSingleSalt(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  /// Generates a cryptographically strong random hex salt.
  static String generateSecureSalt([int length = 16]) {
    final random = Random.secure();
    final values = List<int>.generate(length, (_) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static List<int> _pbkdf2(
    List<int> password,
    List<int> salt,
    int iterations,
    int keyLength,
  ) {
    final hmac = Hmac(sha256, password);
    final result = <int>[];
    var blockIndex = 1;

    while (result.length < keyLength) {
      final block = <int>[
        ...salt,
        (blockIndex >> 24) & 0xff,
        (blockIndex >> 16) & 0xff,
        (blockIndex >> 8) & 0xff,
        blockIndex & 0xff,
      ];
      var u = hmac.convert(block).bytes;
      final accumulator = List<int>.from(u);

      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < accumulator.length; j++) {
          accumulator[j] ^= u[j];
        }
      }

      result.addAll(accumulator);
      blockIndex++;
    }

    return result.sublist(0, keyLength);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}

/// Alias for compatibility with CryptoPinService naming.
typedef CryptoPinService = CryptoPinUtils;

abstract class PinCryptoWorker {
  Future<String> hashPin(String pin, String salt);
  Future<bool> verifyPin(String pin, String hash, String salt);
}

class IsolatePinCryptoWorker implements PinCryptoWorker {
  const IsolatePinCryptoWorker();

  @override
  Future<String> hashPin(String pin, String salt) =>
      CryptoPinUtils.hashPin(pin, salt);
  @override
  Future<bool> verifyPin(String pin, String hash, String salt) =>
      CryptoPinUtils.verifyPin(pin, hash, salt);
}
