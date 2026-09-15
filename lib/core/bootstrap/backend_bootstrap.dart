import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Coordinates the startup of network-dependent services without
/// blocking the first frame.
///
/// The first frame (splash screen) is rendered immediately, while
/// [ready] only completes once Firebase/Supabase/connectivity finished
/// starting up — or gave up. It ALWAYS completes, so the UI can never
/// hang on a network call.
class BackendBootstrap {
  final Completer<void> _ready = Completer<void>();

  /// Resolves (successfully or not) once backend initialization finished,
  /// timed out, or failed. Never throws on its own.
  Future<void> get ready => _ready.future;

  void complete() {
    if (!_ready.isCompleted) _ready.complete();
  }
}

final backendBootstrapProvider = Provider<BackendBootstrap>((ref) {
  return BackendBootstrap();
});