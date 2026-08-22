import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Backend-authoritative operational context for the authenticated identity.
///
/// Values are derived server-side via `get_my_capabilities()` (which reads
/// users / drivers / service_providers / merchants rows). NO email or constant
/// is ever used to infer role. The Owner (users.role='owner') is eligible for
/// every context even before operational rows are materialized.
class PlatformCapabilities {
  final bool customer;
  final bool driver;
  final bool provider;
  final bool merchant;
  final bool admin;
  final bool owner;
  final bool canUseCustomer;
  final bool canUseDelivery;
  final bool canUseProvider;
  final bool canUseAdmin;

  const PlatformCapabilities({
    this.customer = false,
    this.driver = false,
    this.provider = false,
    this.merchant = false,
    this.admin = false,
    this.owner = false,
    this.canUseCustomer = false,
    this.canUseDelivery = false,
    this.canUseProvider = false,
    this.canUseAdmin = false,
  });

  factory PlatformCapabilities.fromJson(Map<String, dynamic> json) {
    return PlatformCapabilities(
      customer: json['customer'] as bool? ?? false,
      driver: json['driver'] as bool? ?? false,
      provider: json['provider'] as bool? ?? false,
      merchant: json['merchant'] as bool? ?? false,
      admin: json['admin'] as bool? ?? false,
      owner: json['owner'] as bool? ?? false,
      canUseCustomer:
          json['can_use_customer'] as bool? ?? (json['customer'] as bool? ?? false),
      canUseDelivery:
          json['can_use_delivery'] as bool? ?? (json['driver'] as bool? ?? false),
      canUseProvider: json['can_use_provider'] as bool? ??
          (json['provider'] as bool? ?? false),
      canUseAdmin:
          json['can_use_admin'] as bool? ?? (json['admin'] as bool? ?? false),
    );
  }
}

/// Pure, testable resolver answering "which operational contexts is this
/// identity eligible for" so the apps can route correctly. This is NEVER a
/// security boundary — backend RLS/RPCs remain authoritative.
class OwnerContextResolver {
  const OwnerContextResolver(this.caps);
  final PlatformCapabilities caps;

  bool get authorizedCustomer =>
      caps.canUseCustomer || caps.customer;
  bool get authorizedDelivery =>
      caps.canUseDelivery || caps.driver || caps.owner;
  bool get authorizedProvider =>
      caps.canUseProvider || caps.provider || caps.merchant || caps.owner;
  bool get authorizedAdmin => caps.canUseAdmin || caps.admin;

  List<String> get availableContexts {
    final list = <String>[];
    if (authorizedCustomer) list.add('customer');
    if (authorizedDelivery) list.add('delivery');
    if (authorizedProvider) list.add('provider');
    if (authorizedAdmin) list.add('admin');
    return list;
  }
}

/// Resolves the current identity's operational contexts from the backend.
/// When the identity is the Owner, it also triggers idempotent provisioning of
/// the required Delivery/Provider operational rows so the same Auth identity
/// works across all four apps. Failures degrade gracefully (no capability).
final platformCapabilitiesProvider =
    FutureProvider<PlatformCapabilities>((ref) async {
  try {
    final res =
        await Supabase.instance.client.rpc('get_my_capabilities');
    final caps = PlatformCapabilities.fromJson(
      (res as Map).cast<String, dynamic>(),
    );
    if (caps.owner) {
      try {
        await Supabase.instance.client
            .rpc('ensure_owner_operational_contexts');
      } catch (_) {
        // Best-effort; backend may not be migrated yet. Non-fatal.
      }
    }
    return caps;
  } catch (_) {
    return const PlatformCapabilities();
  }
});
