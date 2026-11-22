import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/core/bootstrap/backend_bootstrap.dart';

/// Resets the ENTIRE provider container whenever the authenticated Supabase
/// user id changes (logout, login, or switching accounts on the same
/// device/document). Without this, Riverpod caches from the previous
/// account (member lists, admin data, carts) survive a logout/login without
/// a page reload - a cross-account data leak on shared phones and POS
/// devices. A keyed ProviderScope rebuild is the only reset that provably
/// covers every user-scoped provider and in-memory cache.
class AuthScopeGate extends StatefulWidget {
  const AuthScopeGate({
    super.key,
    required this.bootstrap,
    required this.overrides,
    required this.child,
  });

  final BackendBootstrap bootstrap;
  final List<Override> overrides;
  final Widget child;

  @override
  State<AuthScopeGate> createState() => _AuthScopeGateState();
}

class _AuthScopeGateState extends State<AuthScopeGate> {
  StreamSubscription<AuthState>? _sub;
  String? _userId = _readUserId();

  static String? _readUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      // Supabase not initialized yet (backends boot in the background).
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    widget.bootstrap.ready.then((_) {
      if (!mounted) return;
      // A session may have been restored while the backend was booting.
      final restored = _readUserId();
      if (restored != _userId) setState(() => _userId = restored);
      _sub ??= Supabase.instance.client.auth.onAuthStateChange.listen((event) {
        final id = event.session?.user.id;
        // Token refreshes keep the same id and must NOT rebuild the app;
        // only an actual user change (incl. null on logout) resets state.
        if (id != _userId && mounted) {
          setState(() => _userId = id);
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      key: ValueKey<String?>(_userId),
      overrides: widget.overrides,
      child: widget.child,
    );
  }
}
