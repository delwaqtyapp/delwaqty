import 'package:delwaqty/domain/entities/user.dart';

/// Shared client-side admin gate (Phase 2.2, ADR-055).
///
/// Mirrors the server-side canonical `public.is_admin()` (migration 016):
/// `users.role IN ('admin', 'owner')`. This is UI state only — the server
/// (RLS / SECURITY DEFINER RPCs) remains the authorization authority.
bool isAdminRoleString(String? role) => role == 'admin' || role == 'owner';

bool isAdminUser(User user) => isAdminRoleString(user.role);

extension AdminAccess on User {
  bool get isAdmin => isAdminUser(this);
}
