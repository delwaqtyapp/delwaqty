/// UUID generation utility for the Delwaqty platform.
///
/// Generates RFC-4122 v4 UUIDs, validates existing strings, and provides
/// a nil UUID constant.
library;

import 'dart:math';

/// Utility class for UUID operations.
///
/// All methods are static – no instantiation required.
class UuidGenerator {
  UuidGenerator._();

  /// The nil (all-zeros) UUID: `00000000-0000-0000-0000-000000000000`.
  static const String nilUuid = '00000000-0000-0000-0000-000000000000';

  static final _rng = Random.secure();

  /// Generates a random UUID v4 string.
  ///
  /// Example output: `a3f2b8c1-4d5e-6f7a-8b9c-0d1e2f3a4b5c`.
  static String generate() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));

    // Set version 4 (0100 in high nibble of byte 6).
    bytes[6] = (bytes[6] & 0x0F) | 0x40;

    // Set variant 10 (RFC 4122) in high bits of byte 8.
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    return _format(bytes);
  }

  /// Returns true if [value] is a valid UUID string.
  static bool isValid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }

  /// Returns the nil UUID constant.
  static String nil() => nilUuid;

  static String _format(List<int> bytes) {
    String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
        '${hex(bytes[4])}${hex(bytes[5])}-'
        '${hex(bytes[6])}${hex(bytes[7])}-'
        '${hex(bytes[8])}${hex(bytes[9])}-'
        '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }
}
