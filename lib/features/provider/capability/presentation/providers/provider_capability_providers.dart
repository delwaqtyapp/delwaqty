import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/core/auth/platform_capabilities.dart';
import 'package:delwaqty/core/module/shell_customization.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/provider/services/presentation/providers/provider_service_providers.dart';
import 'package:delwaqty/features/provider/capability/domain/provider_capability.dart';
import 'package:delwaqty/features/provider/capability/domain/provider_profile.dart';

class ProviderBusinessProfile {
  const ProviderBusinessProfile({
    required this.id,
    required this.categoryType,
    required this.displayName,
    required this.status,
    this.merchantId,
    this.serviceProviderId,
    this.rejectionReason,
  });

  factory ProviderBusinessProfile.fromJson(Map<String, dynamic> json) =>
      ProviderBusinessProfile(
        id: json['id']?.toString() ?? '',
        categoryType: (json['category_type'] as String? ?? 'restaurant').trim(),
        displayName: (json['display_name'] as String? ?? '').trim(),
        status: (json['status'] as String? ?? 'pending').trim(),
        merchantId: json['merchant_id'] as String?,
        serviceProviderId: json['service_provider_id'] as String?,
        rejectionReason: json['rejection_reason'] as String?,
      );

  final String id;
  final String categoryType;
  final String displayName;
  final String status;
  final String? merchantId;
  final String? serviceProviderId;
  final String? rejectionReason;

  bool get isApproved => status == 'approved';
}

class ProviderProfilesState {
  const ProviderProfilesState({
    this.isOwner = false,
    this.activeCategory = 'restaurant',
    this.profiles = const [],
  });

  final bool isOwner;
  final String activeCategory;
  final List<ProviderBusinessProfile> profiles;
}

/// The authenticated account id. Every identity-dependent provider below
/// watches this, so signing out of account A and into account B can never
/// serve A's cached profile, tabs, services or bookings.
final providerUidProvider = Provider<String?>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth is AuthAuthenticated) {
    final id = auth.user.id;
    return id.isEmpty ? null : id;
  }
  return null;
});

final providerProfilesProvider = FutureProvider<ProviderProfilesState>((
  ref,
) async {
  final uid = ref.watch(providerUidProvider);
  if (uid == null) {
    return const ProviderProfilesState();
  }
  final client = ref.watch(supabaseClientProvider);
  // Errors propagate: a failed lookup must NOT look like "no profiles",
  // otherwise the provider app would guess a category.
  final raw = await client.rpc('get_my_provider_profiles');
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    final listRaw = map['profiles'];
    final profiles = listRaw is List
        ? listRaw
              .whereType<Map>()
              .map(
                (e) => ProviderBusinessProfile.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
        : <ProviderBusinessProfile>[];
    return ProviderProfilesState(
      isOwner: map['is_owner'] == true,
      activeCategory:
          (map['active_category'] as String?)?.trim().isNotEmpty == true
          ? (map['active_category'] as String).trim()
          : 'restaurant',
      profiles: profiles,
    );
  }
  return const ProviderProfilesState();
});

/// Resolves the Provider app account's active raw database classification.
///
/// Honors `providerProfilesProvider.activeCategory` so both the global Owner
/// (for full platform evaluation) and approved multi-service providers can
/// switch seamlessly between verticals in one app.
final providerRawCategoryProvider = FutureProvider<String>((ref) async {
  final uid = ref.watch(providerUidProvider);
  if (uid == null) return 'unknown';
  final client = ref.watch(supabaseClientProvider);

  final profilesState = await ref.watch(providerProfilesProvider.future);
  if (profilesState.profiles.isNotEmpty &&
      profilesState.activeCategory.isNotEmpty) {
    return profilesState.activeCategory;
  }

  if (await isOwnerByRole(client, uid)) return 'owner';

  String? merchantId;
  try {
    final resolved = await client.rpc('resolve_my_merchant');
    if (resolved is String && resolved.isNotEmpty) {
      merchantId = resolved;
    }
  } catch (_) {}

  final merchant = merchantId != null
      ? await client
            .from('merchants')
            .select('type')
            .eq('id', merchantId)
            .maybeSingle()
      : await client
            .from('merchants')
            .select('type')
            .or('id.eq.$uid,owner_user_id.eq.$uid')
            .maybeSingle();
  if (merchant != null && merchant['type'] is String) {
    return merchant['type'] as String;
  }

  final sp = await client
      .from('service_providers')
      .select('category_type')
      .eq('user_id', uid)
      .order('created_at')
      .limit(1)
      .maybeSingle();
  if (sp != null && sp['category_type'] is String) {
    return sp['category_type'] as String;
  }

  try {
    final userRow = await client
        .from('users')
        .select('role')
        .eq('id', uid)
        .maybeSingle();
    return unprovisionedCategoryForRole(userRow?['role'] as String?);
  } catch (_) {}

  return 'unknown';
});

/// Category for an account with a bare role and no merchant or service row:
/// always unknown. A provider is not only home services (doctor, nurse,
/// teacher, barber...), so guessing 'home_services' here opened the wrong
/// surfaces for every unprovisioned professional account. Unknown fails
/// closed (dashboard + money only) until provisioning writes a real row.
String unprovisionedCategoryForRole(String? role) => 'unknown';

/// The provider's canonical category (normalized from the raw DB value).
final providerCategoryProvider = Provider<ProviderCategory>((ref) {
  final raw = ref.watch(providerRawCategoryProvider).value;
  return ProviderCategory.normalize(raw);
});

/// The resolved capability set for the current provider account.
final providerCapabilitiesProvider = Provider<Set<ProviderCapability>>((ref) {
  return resolveCapabilities(ref.watch(providerCategoryProvider));
});

/// The operating profile (tabs, menu, flags, wording) for the signed-in
/// account. Neutral until the account type is known so no type-specific tab
/// flashes and disappears.
final providerProfileProvider = Provider<ProviderProfile>((ref) {
  final raw = ref.watch(providerRawCategoryProvider);
  if (raw.hasError && raw.value == null) return ProviderProfile.failed();
  final value = raw.value;
  if (value == null) return ProviderProfile.loading();
  return ProviderProfile.forCategory(ProviderCategory.normalize(value));
});

/// The service_providers row of the SELECTED approved business profile (not
/// "the first row by created_at"). `null` when the active profile is not a
/// service profile or has no provisioned service row.
final providerSelectedServiceProviderIdProvider = FutureProvider<String?>((
  ref,
) async {
  final uid = ref.watch(providerUidProvider);
  if (uid == null) return null;
  final state = await ref.watch(providerProfilesProvider.future);
  if (state.profiles.isEmpty) {
    // Legacy account without business profiles: single service row.
    return ref
        .watch(providerServiceRepositoryProvider)
        .legacyServiceProviderId();
  }
  final active = state.activeCategory.toLowerCase();
  for (final p in state.profiles) {
    if (p.categoryType.toLowerCase() == active &&
        (p.isApproved || state.isOwner) &&
        (p.serviceProviderId ?? '').isNotEmpty) {
      return p.serviceProviderId;
    }
  }
  return null;
});

/// Shell configuration derived from [providerProfileProvider]. The provider
/// app overrides `shellNavConfigProvider` with this.
final providerShellNavConfigProvider = Provider<ShellNavConfig>((ref) {
  return ref.watch(providerProfileProvider).toShellNavConfig();
});

/// Drawer filter derived from [providerProfileProvider].
final providerDrawerFilterProvider = Provider<bool Function(String)>((ref) {
  return ref.watch(providerProfileProvider).allowsDrawerEntry;
});
