import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../services/supabase/supabase_service.dart';
import '../../data/datasources/remote/supabase_provider_verification_data_source.dart';
import '../../domain/repositories/provider_verification_repository.dart';

final providerVerificationDataSourceProvider =
    Provider<ProviderVerificationDataSource>(
  (ref) => ProviderVerificationDataSource(ref.watch(supabaseClientProvider)),
);

final providerVerificationRepositoryProvider =
    Provider<ProviderVerificationRepository>(
  (ref) => ProviderVerificationRepositoryImpl(
    ref.watch(providerVerificationDataSourceProvider),
  ),
);

final providerVerificationProvider = FutureProvider<Map<String, dynamic>>(
  (ref) => ref.watch(providerVerificationRepositoryProvider).getMyVerification(),
);
