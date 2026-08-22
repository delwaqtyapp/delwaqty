import 'dart:typed_data';

import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/provider/financial/data/datasources/remote/supabase_financial_data_source.dart';
import 'package:delwaqty/features/provider/financial/domain/entities/financial_entities.dart';
import 'package:delwaqty/features/provider/financial/domain/repositories/financial_repository.dart';

class ProviderFinancialRepositoryImpl implements ProviderFinancialRepository {
  ProviderFinancialRepositoryImpl(this._dataSource);
  final ProviderFinancialDataSource _dataSource;

  @override
  Future<FinancialSummary> getMyFinancialSummary() async {
    try {
      return await _dataSource.getMyFinancialSummary();
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<GraceInfo> getMyGrace() async {
    try {
      return await _dataSource.getMyGrace();
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<TopupRequest>> getMyTopupRequests() async {
    try {
      return await _dataSource.getMyTopupRequests();
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> resolveReceiver() async {
    try {
      return await _dataSource.resolveReceiver();
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> createTopupRequest({
    required double amount,
    required String paymentMethod,
    String? transferReference,
    String? proofPath,
    String? message,
  }) async {
    try {
      return await _dataSource.createTopupRequest(
        amount: amount,
        paymentMethod: paymentMethod,
        transferReference: transferReference,
        proofPath: proofPath,
        message: message,
      );
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<String> uploadTopupProof({
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      return await _dataSource.uploadTopupProof(
        fileName: fileName,
        bytes: bytes,
        contentType: contentType,
      );
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<String> getTopupProofSignedUrl(String path) async {
    try {
      return await _dataSource.getTopupProofSignedUrl(path);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
