/// Performance monitoring abstraction for the Delwaqty platform.
///
/// Provides named traces, custom metrics, and timing instrumentation
/// so implementations can target Firebase Performance, DataDog, or a
/// local profiling tool.
library;

/// Abstract interface for performance monitoring.
abstract class PerformanceMonitor {
  /// Starts a named trace and returns the [Trace] handle.
  Trace startTrace(String name);

  /// Records a named metric with the given [value].
  void recordMetric(String name, int value);

  /// Records a named timing with the given [duration].
  void recordTiming(String name, Duration duration);
}

/// Represents an in-progress or completed performance trace.
abstract class Trace {
  /// Adds a sub-counter to this trace.
  void incrementCounter(String counterName, {int incrementBy = 1});

  /// Adds a custom attribute to this trace.
  void putAttribute(String key, String value);

  /// Stops the trace and reports it.
  void stop();
}

/// In-memory implementation that stores traces and metrics for inspection.
class DebugPerformanceMonitor extends PerformanceMonitor {
  final List<DebugTrace> _traces = [];
  final List<RecordedMetric> _metrics = [];

  /// All traces that have been started.
  List<DebugTrace> get traces => List.unmodifiable(_traces);

  /// All recorded metrics.
  List<RecordedMetric> get metrics => List.unmodifiable(_metrics);

  @override
  Trace startTrace(String name) {
    final trace = DebugTrace(name);
    _traces.add(trace);
    return trace;
  }

  @override
  void recordMetric(String name, int value) {
    _metrics.add(RecordedMetric(name: name, value: value, timestamp: DateTime.now()));
  }

  @override
  void recordTiming(String name, Duration duration) {
    _metrics.add(RecordedMetric(
      name: name,
      value: duration.inMilliseconds,
      timestamp: DateTime.now(),
    ));
  }
}

/// A debug trace that records its state in memory.
class DebugTrace implements Trace {
  /// Creates a [DebugTrace].
  DebugTrace(this.name);

  /// The trace name.
  final String name;

  final Map<String, int> _counters = {};
  final Map<String, String> _attributes = {};
  bool _stopped = false;

  /// Whether this trace has been stopped.
  bool get isStopped => _stopped;

  /// Counter values at the time of stop.
  Map<String, int> get counters => Map.unmodifiable(_counters);

  /// Attributes at the time of stop.
  Map<String, String> get attributes => Map.unmodifiable(_attributes);

  @override
  void incrementCounter(String counterName, {int incrementBy = 1}) {
    _counters[counterName] = (_counters[counterName] ?? 0) + incrementBy;
  }

  @override
  void putAttribute(String key, String value) {
    _attributes[key] = value;
  }

  @override
  void stop() {
    _stopped = true;
  }
}

/// A single recorded metric data point.
class RecordedMetric {
  /// Creates a [RecordedMetric].
  const RecordedMetric({
    required this.name,
    required this.value,
    required this.timestamp,
  });

  /// The metric name.
  final String name;

  /// The metric value.
  final int value;

  /// When the metric was recorded.
  final DateTime timestamp;
}

/// No-op performance monitor for tests.
class NoOpPerformanceMonitor extends PerformanceMonitor {
  @override
  Trace startTrace(String name) => _NoOpTrace();

  @override
  void recordMetric(String name, int value) {}

  @override
  void recordTiming(String name, Duration duration) {}
}

class _NoOpTrace implements Trace {
  @override
  void incrementCounter(String counterName, {int incrementBy = 1}) {}

  @override
  void putAttribute(String key, String value) {}

  @override
  void stop() {}
}

/// Firebase Performance implementation of [PerformanceMonitor].
class FirebasePerformanceMonitor extends PerformanceMonitor {
  FirebasePerformanceMonitor(this._performance);

  final dynamic _performance;

  @override
  Trace startTrace(String name) {
    final trace = _performance.newTrace(name);
    trace.start();
    return FirebaseTrace(trace);
  }

  @override
  void recordMetric(String name, int value) {
    final trace = _performance.newTrace(name);
    trace.start();
    trace.setMetric(name, value);
    trace.stop();
  }

  @override
  void recordTiming(String name, Duration duration) {
    final trace = _performance.newTrace(name);
    trace.start();
    trace.setMetric('${name}_ms', duration.inMilliseconds);
    trace.stop();
  }
}

/// Firebase Performance trace wrapper.
class FirebaseTrace implements Trace {
  FirebaseTrace(this._trace);

  final dynamic _trace;

  @override
  void incrementCounter(String counterName, {int incrementBy = 1}) {
    _trace.incrementCounter(counterName, incrementBy);
  }

  @override
  void putAttribute(String key, String value) {
    _trace.putAttribute(key, value);
  }

  @override
  void stop() {
    _trace.stop();
  }
}
