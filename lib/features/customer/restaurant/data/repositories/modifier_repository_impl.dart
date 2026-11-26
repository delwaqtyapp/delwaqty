import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/customer/restaurant/data/datasources/remote/supabase_modifier_data_source.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/product_modifier.dart';
import 'package:delwaqty/features/customer/restaurant/domain/repositories/modifier_repository.dart';

class ModifierRepositoryImpl implements ModifierRepository {
  ModifierRepositoryImpl(this._dataSource);
  final SupabaseModifierDataSource _dataSource;

  @override
  Future<List<ProductModifier>> getModifiers(String productId) async {
    try {
      return await _dataSource.getModifiers(productId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Map<String, Set<String>>> getRequiredGroupOptions(
    String productId,
  ) async {
    try {
      return await _dataSource.getRequiredGroupOptions(productId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<ModifierGroupInfo>> getModifierGroups(String productId) async {
    try {
      return await _dataSource.getModifierGroups(productId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
