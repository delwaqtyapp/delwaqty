import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

/// The single place where an exception becomes text a person reads.
///
/// Data and domain layers are allowed to stringify the original failure -
/// `ServerException(message: e.toString())` keeps the Postgres text and the
/// PostgREST code, which is genuinely useful in a log. Nothing above the display
/// boundary may render it. `appErrorMessage` therefore never returns the raw
/// error: it classifies the failure and returns a localized sentence, so an
/// operator is told what went wrong for them ("no connection", "not allowed")
/// instead of being handed SQL.
///
/// The classifier is deliberately duck-typed rather than importing
/// `postgrest`/`dart:io`: it must compile for the Flutter-web admin target as
/// well as Android, so `dart:io` is out and the concrete transport types are
/// recognised by name.
enum AppErrorKind {
  network,
  timeout,
  unauthenticated,
  forbidden,
  notFound,
  conflict,
  server,
  unknown,
}

const Map<String, AppErrorKind> _transportNames = <String, AppErrorKind>{
  'SocketException': AppErrorKind.network,
  'HttpException': AppErrorKind.network,
  'ClientException': AppErrorKind.network,
  'HandshakeException': AppErrorKind.network,
  'TlsException': AppErrorKind.network,
  'TimeoutException': AppErrorKind.timeout,
};

AppErrorKind classifyAppError(Object? error) {
  if (error is NetworkException) return AppErrorKind.network;
  if (error is TimeoutException) return AppErrorKind.timeout;
  if (error is RateLimitException) return AppErrorKind.server;
  if (error is AuthException) {
    return error.statusCode == 403 ? AppErrorKind.forbidden : AppErrorKind.unauthenticated;
  }
  if (error is ServerException || error is CacheException) {
    return AppErrorKind.server;
  }
  if (error is UnexpectedException) return AppErrorKind.server;

  final typeName = error.runtimeType.toString();
  for (final entry in _transportNames.entries) {
    if (typeName == entry.key || typeName.endsWith('.${entry.key}')) {
      return entry.value;
    }
  }

  // PostgREST and raw Postgres both carry a machine code we can act on without
  // importing their packages.
  final code = _readStringField(error, 'code');
  if (code != null && code.isNotEmpty) {
    if (code == '42501') return AppErrorKind.forbidden;
    if (code == 'PGRST116') return AppErrorKind.notFound;
    if (code == 'PGRST301') return AppErrorKind.unauthenticated;
    if (code == '23505' || code.startsWith('23')) return AppErrorKind.conflict;
    if (code == '57014' || code == '55P03' || code == '53300') {
      return AppErrorKind.timeout;
    }
    if (code == 'PGRST' || code.startsWith('42')) return AppErrorKind.server;
  }

  final message = _readStringField(error, 'message') ?? error.toString();
  final lowered = message.toLowerCase();
  if (lowered.contains('failed to fetch') ||
      lowered.contains('network') ||
      lowered.contains('connection') ||
      lowered.contains('socket')) {
    return AppErrorKind.network;
  }
  if (lowered.contains('timeout') || lowered.contains('timed out')) {
    return AppErrorKind.timeout;
  }
  if (lowered.contains('jwt') || lowered.contains('not authenticated')) {
    return AppErrorKind.unauthenticated;
  }
  if (lowered.contains('row-level security') || lowered.contains('permission')) {
    return AppErrorKind.forbidden;
  }
  return AppErrorKind.unknown;
}

dynamic _readStringField(Object? error, String name) {
  if (error == null) return null;
  try {
    final dynamic value = error as dynamic;
    final Object? field = name == 'code' ? value.code : value.message;
    return field is String ? field : null;
  } on NoSuchMethodError {
    return null;
  }
}

/// Localized, user-safe text for [error]. Never contains the raw exception.
String appErrorMessage(AppLocalizations l10n, Object? error) {
  switch (classifyAppError(error)) {
    case AppErrorKind.network:
      return l10n.noConnection;
    case AppErrorKind.timeout:
      return l10n.errorTimeout;
    case AppErrorKind.unauthenticated:
      return l10n.errorUnauthenticated;
    case AppErrorKind.forbidden:
      return l10n.errorForbidden;
    case AppErrorKind.notFound:
      return l10n.errorNotFound;
    case AppErrorKind.conflict:
      return l10n.errorConflict;
    case AppErrorKind.server:
      return l10n.errorServerIssue;
    case AppErrorKind.unknown:
      return l10n.somethingWentWrong;
  }
}

/// Convenience wrapper for call sites that hold a [BuildContext].
String appErrorText(BuildContext context, Object? error) =>
    appErrorMessage(AppLocalizations.of(context), error);

/// The technical text, for logs only. Never render this in the UI.
String appErrorDetail(Object? error) => error?.toString() ?? '';