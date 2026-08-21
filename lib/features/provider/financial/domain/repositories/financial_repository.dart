import 'package:delwaqty/features/provider/financial/domain/entities/financial_entities.dart';

abstract class ProviderFinancialRepository {
  Future<FinancialSummary> getMyFinancialSummary();

  Future<GraceInfo> getMyGrace();

  Future<List<TopupRequest>> getMyTopupRequests();

  Future<Map<String, dynamic>> resolveReceiver();

  Future<Map<String, dynamic>> createTopupRequest({
    required double amount,
    required String paymentMethod,
    String? transferReference,
    String? proofPath,
    String? message,
  });
}
