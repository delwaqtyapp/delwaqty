import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';

/// Resolves the Provider app's merchant/provider account id.
///
/// Backend contract (migrations 005/003): the `merchants` row `id` equals the
/// authenticated user's `id` (`get_user_merchant_id(uid)` = `SELECT id FROM
/// merchants WHERE id = uid`). RLS then restricts every query to the caller's
/// own merchant, so ownership is enforced server-side and never trusted from a
/// client-supplied id.
final providerMerchantIdProvider = Provider<String>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState is AuthAuthenticated ? authState.user.id : '';
});
