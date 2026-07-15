/// Data encryption service for the Delwaqty platform.
///
/// Provides symmetric encryption/decryption, password hashing with salt,
/// and secure random generation. Implementations may use AES, bcrypt, or
/// platform-native cryptographic APIs.
library;

import 'dart:math';
import 'dart:convert';

/// Abstract interface for encryption operations.
abstract class EncryptionService {
  /// Encrypts [plaintext] and returns the ciphertext string.
  String encrypt(String plaintext);

  /// Decrypts [ciphertext] and returns the plaintext string.
  String decrypt(String ciphertext);

  /// Produces a one-way hash of [data].
  String hash(String data);

  /// Generates a cryptographically secure random salt.
  String generateSalt();

  /// Hashes [password] with the given [salt].
  String hashPassword(String password, String salt);

  /// Verifies [password] against the stored [hash] and [salt].
  bool verifyPassword(String password, String salt, String hash);

  /// Generates a cryptographically secure random string of [length] characters.
  String generateSecureRandom(int length);
}

/// XOR-based encryption for demonstration purposes.
///
/// **WARNING**: This is NOT production-grade encryption. Replace with a
/// proper AES implementation or platform-level cryptography.
class XorEncryptionService extends EncryptionService {
  /// Creates an [XorEncryptionService] with the given [secretKey].
  XorEncryptionService({required this.secretKey});

  /// The key used for XOR operations.
  final String secretKey;

  @override
  String encrypt(String plaintext) {
    final keyBytes = utf8.encode(secretKey);
    final dataBytes = utf8.encode(plaintext);
    final encrypted = <int>[
      for (var i = 0; i < dataBytes.length; i++)
        dataBytes[i] ^ keyBytes[i % keyBytes.length],
    ];
    return base64Encode(encrypted);
  }

  @override
  String decrypt(String ciphertext) {
    final keyBytes = utf8.encode(secretKey);
    final dataBytes = base64Decode(ciphertext);
    final decrypted = <int>[
      for (var i = 0; i < dataBytes.length; i++)
        dataBytes[i] ^ keyBytes[i % keyBytes.length],
    ];
    return utf8.decode(decrypted);
  }

  @override
  String hash(String data) {
    // Simple DJB2 hash for demonstration. Replace with SHA-256 in production.
    var hash = 5381;
    for (final byte in utf8.encode(data)) {
      hash = ((hash << 5) + hash + byte) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  @override
  String generateSalt() {
    return generateSecureRandom(16);
  }

  @override
  String hashPassword(String password, String salt) {
    return hash('$salt:$password');
  }

  @override
  bool verifyPassword(String password, String salt, String hash) {
    return hashPassword(password, salt) == hash;
  }

  @override
  String generateSecureRandom(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
