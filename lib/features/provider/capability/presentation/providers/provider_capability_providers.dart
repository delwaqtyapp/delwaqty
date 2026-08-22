import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/core/auth/platform_capabilities.dart';
import 'package:delwaqty/features/provider/capability/domain/provider_capability.dart';

/// Resolves the Provider app account's raw database classification.
///
/// Canonical source of truth (backend contract):
///   - `merchants.id` equals the auth user id (`get_user_merchant_id`).
///   - `service_providers.user_id` equals the auth user id.
/// We try `merchants.type` first, then `service_providers.category_type`.
/// RLS restricts these rows to the caller's own account, so ownership is
/// enforced server-side and never trusted from a client-supplied value.
///
/// The global Owner (users.role='owner') is granted every provider capability
/// without needing a merchant/service_provider row, so the same Auth identity
/// works across all four apps. Backend RLS remains authoritative for real ops.
final providerRawCategoryProvider = FutureProvider<String>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final uid = client.auth.currentUser?.id;
  if (uid == null || uid.isEmpty) return 'unknown';

  if (await isOwnerByRole(client, uid)) return 'owner';

  final merchant = await client
      .from('merchants')
      .select('type')
      .eq('id', uid)
      .maybeSingle();
  if (merchant != null && merchant['type'] is String) {
    return merchant['type'] as String;
  }

  final sp = await client
      .from('service_providers')
      .select('category_type')
      .eq('user_id', uid)
      .maybeSingle();
  if (sp != null && sp['category_type'] is String) {
    return sp['category_type'] as String;
  }

  return 'unknown';
});

/// The provider's canonical category (normalized from the raw DB value).
final providerCategoryProvider = Provider<ProviderCategory>((ref) {
  final raw = ref.watch(providerRawCategoryProvider).valueOrNull;
  return ProviderCategory.normalize(raw);
});

/// The resolved capability set for the current provider account.
///
/// UX composition only — every sensitive action must still be protected by
/// RLS / RPC authorization / ownership / region scope on the backend.
final providerCapabilitiesProvider = Provider<Set<ProviderCapability>>((ref) {
  return resolveCapabilities(ref.watch(providerCategoryProvider));
});
