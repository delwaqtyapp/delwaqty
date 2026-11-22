import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/auth/admin_access.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';

/// Whether the signed-in admin's admin_management row is active.
/// A suspended admin keeps users.role='admin' (passes the client gate) but
/// every backend call is denied; the admin app routes them to a clear
/// suspended screen instead of a shell full of zeros.
enum AdminAccountStatus { unknown, active, suspended, notRegistered }

final adminAccountStatusProvider = FutureProvider<AdminAccountStatus>((
  ref,
) async {
  final authState = ref.watch(authStateProvider);
  final user = authState is AuthAuthenticated ? authState.user : null;
  if (user == null || !user.isAdmin) return AdminAccountStatus.notRegistered;
  // The owner is never suspended and need not have an admin_management row.
  if (user.role == 'owner') return AdminAccountStatus.active;
  try {
    final row = await ref
        .watch(supabaseClientProvider)
        .from('admin_management')
        .select('is_active')
        .eq('admin_id', user.id)
        .maybeSingle();
    if (row == null) return AdminAccountStatus.notRegistered;
    return (row['is_active'] as bool?) == false
        ? AdminAccountStatus.suspended
        : AdminAccountStatus.active;
  } catch (_) {
    // Fail open: a transient read error must not lock a healthy admin out.
    return AdminAccountStatus.unknown;
  }
});
