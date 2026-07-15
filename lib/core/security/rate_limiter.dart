/// Rate limiting for the Delwaqty platform.
///
/// Protects endpoints from abuse by tracking request counts within
/// configurable time windows.
library;

/// Abstract interface for rate limiting.
abstract class RateLimiter {
  /// Checks whether a request under [key] is allowed within the given
  /// [window] for the specified [limit].
  ///
  /// Returns true if the request is allowed.
  bool check(String key, int limit, Duration window);

  /// Returns the number of remaining allowed requests for [key].
  int remaining(String key, int limit, Duration window);

  /// Resets the counter for [key].
  void reset(String key);
}

/// In-memory sliding-window implementation of [RateLimiter].
class InMemoryRateLimiter extends RateLimiter {
  final Map<String, _WindowEntry> _entries = {};

  @override
  bool check(String key, int limit, Duration window) {
    final entry = _getOrCreate(key);
    final now = DateTime.now();
    entry.pruneBefore(now, window);
    if (entry.count >= limit) return false;
    entry.add(now);
    return true;
  }

  @override
  int remaining(String key, int limit, Duration window) {
    final entry = _getOrCreate(key);
    final now = DateTime.now();
    entry.pruneBefore(now, window);
    return (limit - entry.count).clamp(0, limit);
  }

  @override
  void reset(String key) {
    _entries.remove(key);
  }

  _WindowEntry _getOrCreate(String key) {
    return _entries.putIfAbsent(key, _WindowEntry.new);
  }
}

/// Tracks timestamps within a sliding window.
class _WindowEntry {
  final List<DateTime> _timestamps = [];

  int get count => _timestamps.length;

  void add(DateTime timestamp) {
    _timestamps.add(timestamp);
  }

  void pruneBefore(DateTime now, Duration window) {
    final cutoff = now.subtract(window);
    _timestamps.removeWhere((t) => t.isBefore(cutoff));
  }
}

/// No-op rate limiter that always allows requests.
class NoOpRateLimiter extends RateLimiter {
  @override
  bool check(String key, int limit, Duration window) => true;

  @override
  int remaining(String key, int limit, Duration window) => limit;

  @override
  void reset(String key) {}
}
