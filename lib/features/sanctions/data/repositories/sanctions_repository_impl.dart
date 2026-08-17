import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/sanctions/domain/entities/sanction.dart';
import 'package:delwaqty/features/sanctions/domain/repositories/sanctions_repository.dart';
import 'package:delwaqty/features/sanctions/data/datasources/remote/supabase_sanctions_data_source.dart';

class SanctionsRepositoryImpl implements SanctionsRepository {
  SanctionsRepositoryImpl(this._dataSource);

  final SupabaseSanctionsDataSource _dataSource;

  @override
  Future<List<Sanction>> getSanctions({bool? active}) {
    return _dataSource.getSanctions(active: active);
  }

  @override
  Future<List<Sanction>> getUserSanctions(String targetUserId) {
    return _dataSource.getUserSanctions(targetUserId);
  }

  @override
  Future<Sanction> getSanctionById(String id) {
    return _dataSource.getSanctionById(id);
  }

  @override
  Future<String> issueSanction({
    required String memberId,
    required String sanctionType,
    required String reason,
    int durationDays = 0,
    double amount = 0,
    String? evidenceUrl,
  }) async {
    try {
      return await _dataSource.issueSanction(
        memberId: memberId,
        sanctionType: sanctionType,
        reason: reason,
        durationDays: durationDays,
        amount: amount,
        evidenceUrl: evidenceUrl,
      );
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> revokeSanction({
    required String sanctionId,
    required String reason,
  }) async {
    try {
      return await _dataSource.revokeSanction(
        sanctionId: sanctionId,
        reason: reason,
      );
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
