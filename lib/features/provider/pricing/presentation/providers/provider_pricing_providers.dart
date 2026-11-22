import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/provider/pricing/data/datasources/remote/supabase_provider_pricing_data_source.dart';

final providerPricingDataSourceProvider = Provider<ProviderPricingDataSource>((
  ref,
) {
  return ProviderPricingDataSource(ref.watch(supabaseClientProvider));
});

final providerMyPricingProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(providerPricingDataSourceProvider).getMyPricing();
});
