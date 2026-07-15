/// Session management for the Delwaqty platform.
///
/// Handles creation, validation, refresh, and expiration of user sessions.
/// Publishes an event when a session expires so the UI can react.
library;

import 'dart:async';

/// Represents an active user session.
class Session {
  /// Creates a [Session].
  const Session({
    required this.userId,
    required this.token,
    required this.createdAt,
    required this.expiresAt,
  });

  /// The authenticated user's ID.
  final String userId;

  /// The authentication token (JWT, opaque token, etc.).
  final String token;

  /// When this session was created.
  final DateTime createdAt;

  /// When this session expires.
  final DateTime expiresAt;

  /// Whether the session has expired.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Remaining lifetime of the session.
  Duration get remainingLifetime => expiresAt.isAfter(DateTime.now())
      ? expiresAt.difference(DateTime.now())
      : Duration.zero;

  @override
  String toString() => 'Session(userId: $userId, expired: $isExpired)';
}

/// Abstract interface for session management.
abstract class SessionManager {
  /// Creates a new session for the given [userId] with the provided [token].
  Session createSession(String userId, String token, Duration expiresIn);

  /// Returns the current session, or null if none exists.
  Session? getSession();

  /// Attempts to refresh the current session and returns the new session,
  /// or null if no session exists or refresh fails.
  Future<Session?> refreshSession();

  /// Whether the current session has expired.
  bool isExpired();

  /// Invalidates (clears) the current session.
  void invalidate();

  /// A stream that emits null whenever the session expires.
  Stream<void> onSessionExpired();

  /// Returns the current token, or null if no session exists.
  String? getToken();
}

/// Default in-memory implementation of [SessionManager].
class InMemorySessionManager extends SessionManager {
  Session? _currentSession;
  final StreamController<void> _expirationController =
      StreamController<void>.broadcast();

  @override
  Session createSession(String userId, String token, Duration expiresIn) {
    final now = DateTime.now();
    _currentSession = Session(
      userId: userId,
      token: token,
      createdAt: now,
      expiresAt: now.add(expiresIn),
    );
    return _currentSession!;
  }

  @override
  Session? getSession() {
    if (_currentSession != null && _currentSession!.isExpired) {
      _onExpired();
      return null;
    }
    return _currentSession;
  }

  @override
  Future<Session?> refreshSession() async {
    if (_currentSession == null) return null;
    if (_currentSession!.isExpired) {
      _onExpired();
      return null;
    }
    final now = DateTime.now();
    _currentSession = Session(
      userId: _currentSession!.userId,
      token: _currentSession!.token,
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 1)),
    );
    return _currentSession;
  }

  @override
  bool isExpired() => _currentSession?.isExpired ?? true;

  @override
  void invalidate() {
    _currentSession = null;
  }

  @override
  Stream<void> onSessionExpired() => _expirationController.stream;

  @override
  String? getToken() {
    final session = getSession();
    return session?.token;
  }

  void _onExpired() {
    _currentSession = null;
    _expirationController.add(null);
  }
}

/// No-op session manager for tests.
class NoOpSessionManager extends SessionManager {
  @override
  Session createSession(String userId, String token, Duration expiresIn) {
    return Session(
      userId: userId,
      token: token,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(expiresIn),
    );
  }

  @override
  Session? getSession() => null;

  @override
  Future<Session?> refreshSession() async => null;

  @override
  bool isExpired() => true;

  @override
  void invalidate() {}

  @override
  Stream<void> onSessionExpired() => const Stream.empty();

  @override
  String? getToken() => null;
}
