/// Service health checking for the Delwaqty platform.
///
/// Allows registration of named health checks (database, network, cache, etc.)
/// and aggregate querying of overall service health.
library;

/// The result status of a health check.
enum HealthStatus {
  /// The service is healthy.
  healthy,

  /// The service is degraded but operational.
  degraded,

  /// The service is unhealthy.
  unhealthy,

  /// The check has not run yet or timed out.
  unknown,
}

/// The result of a single health check.
class HealthCheckResult {
  /// Creates a [HealthCheckResult].
  const HealthCheckResult({
    required this.name,
    required this.status,
    this.message,
    this.duration,
    this.details,
  });

  /// Creates a healthy result.
  const HealthCheckResult.healthy(
    String name, {
    String? message,
    Duration? duration,
  }) : this(
         name: name,
         status: HealthStatus.healthy,
         message: message,
         duration: duration,
       );

  /// Creates an unhealthy result.
  const HealthCheckResult.unhealthy(
    String name, {
    String? message,
    Duration? duration,
  }) : this(
         name: name,
         status: HealthStatus.unhealthy,
         message: message,
         duration: duration,
       );

  /// Creates a degraded result.
  const HealthCheckResult.degraded(
    String name, {
    String? message,
    Duration? duration,
  }) : this(
         name: name,
         status: HealthStatus.degraded,
         message: message,
         duration: duration,
       );

  /// Creates an unknown result.
  const HealthCheckResult.unknown(String name, {String? message})
    : this(name: name, status: HealthStatus.unknown, message: message);

  /// The check name.
  final String name;

  /// The result status.
  final HealthStatus status;

  /// Optional human-readable message.
  final String? message;

  /// Duration the check took to run.
  final Duration? duration;

  /// Additional details.
  final Map<String, dynamic>? details;
}

/// A function that performs a health check and returns a [HealthCheckResult].
typedef HealthCheckFunction = Future<HealthCheckResult> Function();

/// Abstract interface for health checking.
abstract class HealthCheckService {
  /// Registers a health check under the given [name].
  void registerCheck(String name, HealthCheckFunction check);

  /// Runs all registered checks and returns a map of name → result.
  Future<Map<String, HealthCheckResult>> runAll();

  /// Runs a single check by [name].
  Future<HealthCheckResult> runCheck(String name);

  /// Returns true if all checks pass with [HealthStatus.healthy].
  Future<bool> isHealthy();
}

/// Default implementation of [HealthCheckService].
class DefaultHealthCheckService extends HealthCheckService {
  final Map<String, HealthCheckFunction> _checks = {};

  @override
  void registerCheck(String name, HealthCheckFunction check) {
    _checks[name] = check;
  }

  @override
  Future<Map<String, HealthCheckResult>> runAll() async {
    final results = <String, HealthCheckResult>{};
    for (final entry in _checks.entries) {
      results[entry.key] = await _safeRun(entry.key, entry.value);
    }
    return results;
  }

  @override
  Future<HealthCheckResult> runCheck(String name) async {
    final check = _checks[name];
    if (check == null) {
      return HealthCheckResult.unknown(name, message: 'Check not registered');
    }
    return _safeRun(name, check);
  }

  @override
  Future<bool> isHealthy() async {
    final results = await runAll();
    return results.values.every(
      (r) =>
          r.status == HealthStatus.healthy || r.status == HealthStatus.degraded,
    );
  }

  Future<HealthCheckResult> _safeRun(
    String name,
    HealthCheckFunction check,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await check();
      stopwatch.stop();
      return result.duration == null
          ? HealthCheckResult(
              name: result.name,
              status: result.status,
              message: result.message,
              duration: stopwatch.elapsed,
              details: result.details,
            )
          : result;
    } catch (e) {
      stopwatch.stop();
      return HealthCheckResult.unhealthy(
        name,
        message: e.toString(),
        duration: stopwatch.elapsed,
      );
    }
  }
}

/// No-op health check service for tests.
class NoOpHealthCheckService extends HealthCheckService {
  @override
  void registerCheck(String name, HealthCheckFunction check) {}

  @override
  Future<Map<String, HealthCheckResult>> runAll() async => {};

  @override
  Future<HealthCheckResult> runCheck(String name) async =>
      HealthCheckResult.unknown(name);

  @override
  Future<bool> isHealthy() async => true;
}
