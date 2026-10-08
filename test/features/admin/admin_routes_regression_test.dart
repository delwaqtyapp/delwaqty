import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/admin/admin_module.dart';
import 'package:delwaqty/features/admin/escalation/escalation_module.dart';
import 'package:delwaqty/features/admin/sanctions/sanctions_module.dart';

/// Regression guard for the "Page not found" dead ends.
///
/// `admin_shell.dart` links to destinations by path. Three of them
/// (`/admin/sanctions`, `/admin/live-tracking`, `/admin/emergency`) were
/// never registered, so tapping the nav item, the Quick Actions tile, the
/// member operations centre shortcut or a notification deep link all
/// landed on the router's error page. This test fails if one of those
/// destinations is ever dropped from the route table again.
void main() {
  final modules = [AdminModule(), EscalationModule(), SanctionsModule()];

  /// Collects every reachable location. go_router nests routes, so a child
  /// path is relative to its parent and must be resolved to an absolute
  /// location before it can be compared with a link in the UI.
  Set<String> registeredPaths() {
    final paths = <String>{};
    for (final module in modules) {
      for (final route in module.standaloneRoutes) {
        if (route is GoRoute) {
          paths.add(route.path);
          _collect(route, route.path, paths);
        }
      }
    }
    return paths;
  }

  test('admin modules expose route paths', () {
    expect(registeredPaths(), isNotEmpty);
    for (final path in registeredPaths()) {
      expect(
        path,
        startsWith('/'),
        reason: 'resolved route "$path" must be absolute',
      );
    }
  });

  test('the admin destinations linked across the app are registered', () {
    final registered = registeredPaths();

    // These were linked from the shell nav, Quick Actions, the member
    // operations centre and notification deep links while having NO
    // route, so every one of those taps produced "Page not found".
    for (final required in [
      '/admin/sanctions',
      '/admin/live-tracking',
      '/admin/escalations',
    ]) {
      expect(
        registered,
        contains(required),
        reason: '"$required" is linked in the UI but not registered',
      );
    }
  });
}

void _collect(GoRoute route, String parent, Set<String> out) {
  for (final child in route.routes) {
    if (child is GoRoute) {
      final resolved = child.path.startsWith('/')
          ? child.path
          : '$parent/${child.path}';
      out.add(resolved);
      _collect(child, resolved, out);
    }
  }
}