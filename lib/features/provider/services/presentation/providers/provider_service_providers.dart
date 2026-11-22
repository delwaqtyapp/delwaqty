import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/provider/services/domain/provider_service_info.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';

/// The signed-in service provider's own service row (read only).
final providerServiceInfoProvider = FutureProvider<List<ProviderServiceInfo>>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  final uid = client.auth.currentUser?.id;
  if (uid == null || uid.isEmpty) return const [];
  final rows = await client
      .from('service_providers')
      .select(
        'category_type,name,description,hourly_rate,fixed_price_min,'
        'fixed_price_max,is_available,tags',
      )
      .eq('user_id', uid)
      .order('created_at');
  return (rows as List)
      .whereType<Map>()
      .map((e) => ProviderServiceInfo.fromJson(Map<String, dynamic>.from(e)))
      .toList();
});
