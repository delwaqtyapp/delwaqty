import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/core/constants/app_constants.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/admin/financial/data/datasources/remote/supabase_admin_financial_data_source.dart';
import 'package:delwaqty/features/admin/financial/data/repositories/admin_financial_repository_impl.dart';
import 'package:delwaqty/features/admin/financial/domain/entities/admin_financial_entities.dart';
import 'package:delwaqty/features/admin/financial/domain/repositories/admin_financial_repository.dart';

final adminFinancialDataSourceProvider =
    Provider<AdminFinancialDataSource>((ref) {
      return AdminFinancialDataSource(ref.watch(supabaseClientProvider));
    });

final adminFinancialRepositoryProvider =
    Provider<AdminFinancialRepository>((ref) {
      return AdminFinancialRepositoryImpl(
        ref.watch(adminFinancialDataSourceProvider),
      );
    });

final adminTopupStatusFilterProvider = StateProvider<String?>((ref) => null);

final adminTopupRequestsProvider =
    FutureProvider<List<AdminTopupRequest>>((ref) {
      final repo = ref.watch(adminFinancialRepositoryProvider);
      return repo.listTopupRequests(ref.watch(adminTopupStatusFilterProvider));
    });

final adminCollectionSummaryProvider =
    FutureProvider<CollectionSummary>((ref) {
      return ref.watch(adminFinancialRepositoryProvider).collectionSummary();
    });

final adminCollectionsProvider =
    FutureProvider<List<CollectionRecord>>((ref) {
      return ref.watch(adminFinancialRepositoryProvider).listCollections();
    });

final adminSettlementsProvider =
    FutureProvider<List<SettlementRecord>>((ref) {
      return ref.watch(adminFinancialRepositoryProvider).listSettlements();
    });

final adminReceivingAccountsProvider =
    FutureProvider<List<ReceivingAccount>>((ref) {
      return ref
          .watch(adminFinancialRepositoryProvider)
          .listPlatformReceivingAccounts();
    });

final adminReceivingWalletsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
      return ref
          .watch(adminFinancialRepositoryProvider)
          .listAdminReceivingWallets();
    });

final adminIsOwnerProvider = Provider<bool>((ref) {
  final email = Supabase.instance.client.auth.currentUser?.email;
  return email == AppConstants.ownerEmail;
});

final graceTargetProvider = StateProvider<String>((ref) => '');

final graceAccountProvider = FutureProvider<GraceAccount?>((ref) {
  final target = ref.watch(graceTargetProvider).trim();
  if (target.isEmpty) return Future.value(null);
  return ref.watch(adminFinancialRepositoryProvider).getGrace(target);
});

final platformCollectionAuditProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(adminFinancialRepositoryProvider).platformCollectionAudit();
});

final platformSettlementAuditProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(adminFinancialRepositoryProvider).platformSettlementAudit();
});
