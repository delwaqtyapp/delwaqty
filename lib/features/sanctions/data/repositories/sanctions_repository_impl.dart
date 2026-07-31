import 'package:delwaqty/features/sanctions/domain/entities/sanction.dart';
import 'package:delwaqty/features/sanctions/domain/repositories/sanctions_repository.dart';
import 'package:delwaqty/features/sanctions/data/datasources/remote/supabase_sanctions_data_source.dart';

class SanctionsRepositoryImpl implements SanctionsRepository {
  final SupabaseSanctionsDataSource _dataSource;

  SanctionsRepositoryImpl(this._dataSource);

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
  Future<Sanction> createSanction(Sanction sanction) {
    return _dataSource.createSanction(sanction);
  }

  @override
  Future<Sanction> updateSanction(String id, Map<String, dynamic> updates) {
    return _dataSource.updateSanction(id, updates);
  }

  @override
  Future<void> revokeSanction(String id) {
    return _dataSource.revokeSanction(id);
  }
}
