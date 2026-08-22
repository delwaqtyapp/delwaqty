import 'dart:typed_data';

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

  Future<String> uploadTopupProof({
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  });

  Future<String> getTopupProofSignedUrl(String path);
}
