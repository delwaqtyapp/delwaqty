import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/deep_link/deep_link_resolver.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

/// Observes inbound deep links on the `io.delwaqty://` custom scheme.
///
/// supabase_flutter owns the auth-callback exchange (PKCE) on its own
/// [AppLinks] subscription; this service adds a complementary, allowlisted
/// listener that only classifies the URI into a [DeepLinkRoute]. It records
/// the last received route so the router can consult it after the session
/// resolves (cold start / app already running).
class DeepLinkService {
DeepLinkService({
    required this._appLinks,
    required this._logger,
    this._overrideStream,
  });

  final AppLinks _appLinks;
  final AppLogger _logger;
  final Stream<Uri?>? _overrideStream;

  StreamSubscription<Uri?>? _subscription;

  final StreamController<DeepLinkRoute> _routes = StreamController.broadcast();

  /// Broadcast stream of allowlisted deep-link routes as they arrive.
  Stream<DeepLinkRoute> get routes => _routes.stream;

  late final Future<DeepLinkRoute?> _initial = _captureInitial();

  /// The first allowlisted route that launched the app (multiple listeners
  /// are safe; each call returns the same captured value).
  Future<DeepLinkRoute?> get initialRoute => _initial;

  void start() {
    if (_subscription != null) return;
    _subscription = (_overrideStream ?? _appLinks.uriLinkStream).listen(
      (uri) {
        if (uri == null) return;
        final route = DeepLinkResolver.resolve(uri.toString());
        if (route == null) return;
        _logger.i('Deep link: ${uri.toString()} -> $route');
        if (!_routes.isClosed) _routes.add(route);
      },
      onError: (Object err, StackTrace st) {
        _logger.w('Deep link stream error: $err');
      },
    );
  }

  Future<DeepLinkRoute?> _captureInitial() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri == null) return null;
      return DeepLinkResolver.resolve(uri.toString());
    } catch (e) {
      _logger.w('Failed to read initial deep link: $e');
      return null;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _routes.close();
  }
}

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final service = DeepLinkService(
    appLinks: AppLinks(),
    logger: ref.watch(loggerProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});