import 'package:supabase_flutter/supabase_flutter.dart';

class ProviderAvailabilityDataSource {
  final SupabaseClient _client;
  ProviderAvailabilityDataSource(this._client);

  Future<Map<String, dynamic>> getAvailability() async {
    final res = await _client.rpc('provider_get_availability');
    if (res == null) return {'is_open': true, 'schedule': []};
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> setAvailability(bool isOpen) async {
    final res = await _client.rpc(
      'provider_set_availability',
      params: {'p_is_open': isOpen},
    );
    return Map<String, dynamic>.from(res as Map);
  }
}
