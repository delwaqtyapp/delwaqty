import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../services/supabase/supabase_service.dart';
import '../../data/datasources/remote/supabase_provider_documents_data_source.dart';
import '../../domain/repositories/provider_documents_repository.dart';

final providerDocumentsDataSourceProvider =
    Provider<ProviderDocumentsDataSource>(
  (ref) => ProviderDocumentsDataSource(ref.watch(supabaseClientProvider)),
);

final providerDocumentsRepositoryProvider =
    Provider<ProviderDocumentsRepository>(
  (ref) => ProviderDocumentsRepositoryImpl(
    ref.watch(providerDocumentsDataSourceProvider),
  ),
);

final providerDocumentsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(providerDocumentsRepositoryProvider).getDocuments(),
);

class ProviderDocType {
  const ProviderDocType(this.key, this.label);
  final String key;
  final String label;
}

const List<ProviderDocType> providerDocTypes = [
  ProviderDocType('identity', 'Identity'),
  ProviderDocType('license', 'Professional License'),
  ProviderDocType('certification', 'Certification'),
  ProviderDocType('insurance', 'Insurance'),
];
