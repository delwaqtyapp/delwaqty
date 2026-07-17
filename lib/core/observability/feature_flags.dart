/// Feature flag system for the Delwaqty platform.
///
/// Supports typed flag access, remote refresh, change streams, and
/// per-flag defaults for graceful degradation.
library;

import 'dart:async';

/// The value of a feature flag.
class FeatureFlagValue {
  /// Boolean value.
  const FeatureFlagValue.bool(this.boolValue)
    : stringValue = null,
      intValue = null,
      doubleValue = null,
      _type = _FlagType.bool;

  /// String value.
  const FeatureFlagValue.string(this.stringValue)
    : boolValue = null,
      intValue = null,
      doubleValue = null,
      _type = _FlagType.string;

  /// Integer value.
  const FeatureFlagValue.integer(this.intValue)
    : boolValue = null,
      stringValue = null,
      doubleValue = null,
      _type = _FlagType.integer;

  /// Double value.
  const FeatureFlagValue.floating(this.doubleValue)
    : boolValue = null,
      stringValue = null,
      intValue = null,
      _type = _FlagType.double;

  final bool? boolValue;
  final String? stringValue;
  final int? intValue;
  final double? doubleValue;
  final _FlagType _type;

  /// Whether this is a boolean flag.
  bool get isBool => _type == _FlagType.bool;

  /// Whether this is a string flag.
  bool get isString => _type == _FlagType.string;

  /// Whether this is an integer flag.
  bool get isInt => _type == _FlagType.integer;

  /// Whether this is a double flag.
  bool get isDouble => _type == _FlagType.double;
}

enum _FlagType { bool, string, integer, double }

/// Event emitted when a flag value changes.
class FeatureFlagEvent {
  /// Creates a [FeatureFlagEvent].
  const FeatureFlagEvent({required this.flagName, required this.newValue});

  /// The name of the flag that changed.
  final String flagName;

  /// The new value of the flag.
  final FeatureFlagValue? newValue;

  @override
  String toString() => 'FeatureFlagEvent($flagName: $newValue)';
}

/// Abstract interface for feature flags.
abstract class FeatureFlags {
  /// Returns whether the flag is enabled (boolean true).
  bool isEnabled(String flagName);

  /// Returns a boolean flag value, falling back to [defaultValue].
  bool getBool(String flagName, bool defaultValue);

  /// Returns a string flag value, falling back to [defaultValue].
  String getString(String flagName, String defaultValue);

  /// Returns an integer flag value, falling back to [defaultValue].
  int getInt(String flagName, int defaultValue);

  /// Returns a double flag value, falling back to [defaultValue].
  double getDouble(String flagName, double defaultValue);

  /// Fetches the latest flag values from the remote provider.
  Future<void> refresh();

  /// A stream of flag-change events.
  Stream<FeatureFlagEvent> onFlagChanged(String flagName);

  /// Registers a local default value for the flag.
  void registerDefault(String flagName, FeatureFlagValue value);
}

/// In-memory implementation of [FeatureFlags].
///
/// Flags can be set directly for testing or seeded with defaults.
class InMemoryFeatureFlags extends FeatureFlags {
  final Map<String, FeatureFlagValue> _flags = {};
  final Map<String, FeatureFlagValue> _defaults = {};
  final Map<String, StreamController<FeatureFlagEvent>> _controllers = {};

  @override
  bool isEnabled(String flagName) => getBool(flagName, false);

  @override
  bool getBool(String flagName, bool defaultValue) {
    final value = _resolve(flagName);
    if (value != null && value.isBool) return value.boolValue ?? defaultValue;
    return defaultValue;
  }

  @override
  String getString(String flagName, String defaultValue) {
    final value = _resolve(flagName);
    if (value != null && value.isString)
      return value.stringValue ?? defaultValue;
    return defaultValue;
  }

  @override
  int getInt(String flagName, int defaultValue) {
    final value = _resolve(flagName);
    if (value != null && value.isInt) return value.intValue ?? defaultValue;
    return defaultValue;
  }

  @override
  double getDouble(String flagName, double defaultValue) {
    final value = _resolve(flagName);
    if (value != null && value.isDouble)
      return value.doubleValue ?? defaultValue;
    return defaultValue;
  }

  @override
  Future<void> refresh() async {
    // No remote source in the in-memory implementation.
  }

  @override
  Stream<FeatureFlagEvent> onFlagChanged(String flagName) {
    return _getController(flagName).stream;
  }

  @override
  void registerDefault(String flagName, FeatureFlagValue value) {
    _defaults[flagName] = value;
  }

  /// Sets a flag value and notifies listeners.
  void setFlag(String flagName, FeatureFlagValue value) {
    _flags[flagName] = value;
    _getController(
      flagName,
    ).add(FeatureFlagEvent(flagName: flagName, newValue: value));
  }

  /// Removes a flag so it falls back to the default.
  void removeFlag(String flagName) {
    _flags.remove(flagName);
  }

  FeatureFlagValue? _resolve(String flagName) {
    return _flags[flagName] ?? _defaults[flagName];
  }

  StreamController<FeatureFlagEvent> _getController(String flagName) {
    return _controllers.putIfAbsent(
      flagName,
      () => StreamController<FeatureFlagEvent>.broadcast(),
    );
  }
}
