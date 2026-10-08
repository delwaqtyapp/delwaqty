import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:delwaqty/services/supabase/supabase_service.dart';

/// Resolves the Provider app's merchant/provider account id.
///
/// The caller's real `merchants.id`.
///
/// The old comment here claimed the merchants row id equals the auth uid, and
/// the old provider did exactly that. It is false: `merchants` is keyed by its
/// own id and linked to the owner through `owner_user_id`, so passing
/// `auth.uid()` as `merchant_id` filtered every merchant-scoped query on a
/// uuid that can never match a `merchants.id`. The id is now resolved
/// server-side (migration 109) and RLS still enforces ownership.
final providerMerchantIdProvider = FutureProvider<String>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  // merchants.id is NOT auth.uid(): the merchants table is keyed by its own
  // id and linked to the owner through owner_user_id, so passing the auth
  // uid as merchant_id made every merchant-scoped query return nothing.
  // The server resolves the real id (109_resolve_my_merchant).
  final id = await client.rpc('resolve_my_merchant');
  return id as String? ?? '';
});
