import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/provider/financial/data/datasources/remote/supabase_financial_data_source.dart';
import 'package:delwaqty/features/provider/financial/domain/repositories/financial_repository.dart';
import 'package:delwaqty/features/provider/financial/data/repositories/financial_repository_impl.dart';
import 'package:delwaqty/features/provider/financial/domain/entities/financial_entities.dart';

final providerFinancialRepositoryProvider =
    Provider<ProviderFinancialRepository>((ref) {
      return ProviderFinancialRepositoryImpl(
        ref.watch(providerFinancialDataSourceProvider),
      );
    });

final financialSummaryProvider = FutureProvider<FinancialSummary>((ref) =>
    ref.watch(providerFinancialRepositoryProvider).getMyFinancialSummary());

final graceProvider = FutureProvider<GraceInfo>((ref) =>
    ref.watch(providerFinancialRepositoryProvider).getMyGrace());

final topupRequestsProvider = FutureProvider<List<TopupRequest>>((ref) =>
    ref.watch(providerFinancialRepositoryProvider).getMyTopupRequests());

final receiverProvider = FutureProvider<Map<String, dynamic>>((ref) =>
    ref.watch(providerFinancialRepositoryProvider).resolveReceiver());
