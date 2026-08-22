import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/provider/availability/data/datasources/remote/supabase_provider_availability_data_source.dart';
import 'package:delwaqty/features/provider/availability/domain/repositories/provider_availability_repository.dart';

final providerAvailabilityDataSourceProvider =
    Provider<ProviderAvailabilityDataSource>((ref) {
      return ProviderAvailabilityDataSource(ref.watch(supabaseClientProvider));
    });

final providerAvailabilityRepositoryProvider =
    Provider<ProviderAvailabilityRepository>((ref) {
      return ProviderAvailabilityRepositoryImpl(
        ref.watch(providerAvailabilityDataSourceProvider),
      );
    });

final providerAvailabilityProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(providerAvailabilityRepositoryProvider).getAvailability();
});
