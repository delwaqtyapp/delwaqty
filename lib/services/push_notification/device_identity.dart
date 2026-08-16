import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdentity {
  static const String _prefsKey = 'delwaqty_device_id';
  static String? _cached;

  static Future<String> getOrCreate() async {
    final cached = _cached;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_prefsKey);
    if (id == null || id.isEmpty) {
      id = _randomUuidV4();
      await prefs.setString(_prefsKey, id);
    }
    _cached = id;
    return id;
  }

  @visibleForTesting
  static void debugResetForTest() {
    _cached = null;
  }

  static String _randomUuidV4() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
        '${hex(bytes[4])}${hex(bytes[5])}-${hex(bytes[6])}${hex(bytes[7])}-'
        '${hex(bytes[8])}${hex(bytes[9])}-${hex(bytes[10])}${hex(bytes[11])}'
        '${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }
}
