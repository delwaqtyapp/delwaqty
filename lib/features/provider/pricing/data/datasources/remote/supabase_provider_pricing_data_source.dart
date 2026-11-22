import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only access to the provider's own admin-managed pricing
/// (migration 397). Rates can only change through the admin RPCs.
class ProviderPricingDataSource {
  ProviderPricingDataSource(this._client);
  final SupabaseClient _client;

  Future<Map<String, dynamic>> getMyPricing() async {
    final res = await _client.rpc('provider_get_my_pricing');
    if (res == null) return {'items': const []};
    return Map<String, dynamic>.from(res as Map);
  }
}
