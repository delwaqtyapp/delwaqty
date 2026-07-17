import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/restaurant/data/datasources/remote/supabase_modifier_data_source.dart';
import 'package:delwaqty/features/restaurant/domain/entities/product_modifier.dart';
import 'package:delwaqty/features/restaurant/domain/repositories/modifier_repository.dart';

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
  Future<ProductModifier> createModifier(ProductModifier modifier) async {
    try {
      return await _dataSource.createModifier(modifier);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ProductModifier> updateModifier(ProductModifier modifier) async {
    try {
      return await _dataSource.updateModifier(modifier);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> deleteModifier(String id) async {
    try {
      await _dataSource.deleteModifier(id);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
