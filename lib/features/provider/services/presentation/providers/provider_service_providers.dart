import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/provider/capability/presentation/providers/provider_capability_providers.dart';
import 'package:delwaqty/features/provider/services/domain/provider_service_info.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';

/// Reads the selected service profile's data. One place to swap the price
/// source later (the admin pricing RPC `provider_get_my_pricing`).
abstract class ProviderServiceRepository {
  /// Single service row of a legacy account (no business profiles).
  Future<String?> legacyServiceProviderId();

  /// The service and its prices for ONE service provider id.
  Future<List<ProviderServiceInfo>> servicesFor(String serviceProviderId);

  /// Bookings of ONE service provider id.
  Future<List<Map<String, dynamic>>> bookingsFor(String serviceProviderId);
}

class SupabaseProviderServiceRepository implements ProviderServiceRepository {
  SupabaseProviderServiceRepository(this._ref);
  final Ref _ref;

  @override
  Future<String?> legacyServiceProviderId() async {
    final raw = await _ref
        .read(supabaseClientProvider)
        .rpc('resolve_my_service_provider');
    final id = raw as String? ?? '';
    return id.isEmpty ? null : id;
  }

  @override
  Future<List<ProviderServiceInfo>> servicesFor(
    String serviceProviderId,
  ) async {
    // Same effective rates as customer browsing and checkout.
    final rows = await _ref
        .read(supabaseClientProvider)
        .from('service_providers_with_effective_pricing')
        .select(
          'category_type,name,description,hourly_rate:effective_hourly_rate,'
          'fixed_price_min:effective_fixed_price_min,fixed_price_max:effective_fixed_price_max,is_available,tags',
        )
        .eq('id', serviceProviderId);
    return (rows as List)
        .whereType<Map>()
        .map((e) => ProviderServiceInfo.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> bookingsFor(
    String serviceProviderId,
  ) async {
    final res = await _ref
        .read(supabaseClientProvider)
        .from('service_bookings')
        .select()
        .eq('provider_id', serviceProviderId)
        .order('created_at', ascending: false);
    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}

final providerServiceRepositoryProvider = Provider<ProviderServiceRepository>(
  (ref) => SupabaseProviderServiceRepository(ref),
);

/// The selected service profile's service and prices (read only).
final providerServiceInfoProvider = FutureProvider<List<ProviderServiceInfo>>((
  ref,
) async {
  final spId = await ref.watch(
    providerSelectedServiceProviderIdProvider.future,
  );
  if (spId == null) return const [];
  return ref.watch(providerServiceRepositoryProvider).servicesFor(spId);
});

/// Bookings of the selected service profile. Keyed by it, so switching the
/// active profile or the account never shows another profile's jobs.
final providerServiceBookingsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      final spId = await ref.watch(
        providerSelectedServiceProviderIdProvider.future,
      );
      if (spId == null) return const [];
      return ref.watch(providerServiceRepositoryProvider).bookingsFor(spId);
    });
