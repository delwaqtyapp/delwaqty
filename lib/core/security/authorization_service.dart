/// Role-based access control (RBAC) for the Delwaqty platform.
///
/// Provides permission and role queries, plus a resource-level
/// authorization check.
library;

/// Abstract interface for authorization.
abstract class AuthorizationService {
  /// Returns true if the current user holds the given [permission].
  bool hasPermission(String permission);

  /// Returns true if the current user has the given [role].
  bool hasRole(String role);

  /// Returns the list of roles assigned to the current user.
  List<String> getRoles();

  /// Returns the list of permissions assigned to the current user.
  List<String> getPermissions();

  /// Replaces the current set of roles and recomputes permissions.
  void setRoles(List<String> roles);

  /// Returns true if the current user may perform [action] on [resource].
  bool canAccess(String resource, String action);
}

/// Data class describing an access-control rule.
class AccessRule {
  /// Creates an [AccessRule].
  const AccessRule({
    required this.resource,
    required this.action,
    required this.roles,
  });

  /// The resource this rule applies to (e.g., 'orders').
  final String resource;

  /// The action this rule grants (e.g., 'read', 'write', 'delete').
  final String action;

  /// Roles that are allowed this action on this resource.
  final List<String> roles;
}

/// Default in-memory implementation of [AuthorizationService].
class InMemoryAuthorizationService extends AuthorizationService {
  /// Creates an [InMemoryAuthorizationService] with the given [rules] and
  /// initial [roles].
  InMemoryAuthorizationService({
    required List<AccessRule> rules,
    List<String> roles = const [],
    Map<String, List<String>> rolePermissions = const {},
  })  : _rules = List.unmodifiable(rules),
        _roles = List<String>.from(roles),
        _rolePermissions = Map.of(rolePermissions);

  final List<AccessRule> _rules;
  final List<String> _roles;
  final Map<String, List<String>> _rolePermissions;

  @override
  bool hasPermission(String permission) {
    return getPermissions().contains(permission);
  }

  @override
  bool hasRole(String role) => _roles.contains(role);

  @override
  List<String> getRoles() => List.unmodifiable(_roles);

  @override
  List<String> getPermissions() {
    final permissions = <String>{};
    for (final role in _roles) {
      final perms = _rolePermissions[role];
      if (perms != null) {
        permissions.addAll(perms);
      }
    }
    return permissions.toList();
  }

  @override
  void setRoles(List<String> roles) {
    _roles
      ..clear()
      ..addAll(roles);
  }

  @override
  bool canAccess(String resource, String action) {
    for (final rule in _rules) {
      if (rule.resource == resource && rule.action == action) {
        if (rule.roles.any(_roles.contains)) return true;
      }
    }
    return false;
  }
}

/// No-op authorization for tests – always grants access.
class NoOpAuthorizationService extends AuthorizationService {
  @override
  bool hasPermission(String permission) => true;

  @override
  bool hasRole(String role) => true;

  @override
  List<String> getRoles() => const ['admin'];

  @override
  List<String> getPermissions() => const ['*'];

  @override
  void setRoles(List<String> roles) {}

  @override
  bool canAccess(String resource, String action) => true;
}
