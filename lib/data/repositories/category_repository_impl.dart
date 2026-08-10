import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/home/domain/entities/platform_category.dart';
import 'package:delwaqty/features/home/domain/repositories/platform_category_repository.dart';
import 'package:delwaqty/data/datasources/remote/supabase_category_data_source.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

final categoryRepositoryImplProvider = Provider<CategoryRepositoryImpl>((ref) {
  return CategoryRepositoryImpl(
    ref.watch(supabaseCategoryDataSourceProvider),
    ref.watch(loggerProvider),
  );
});

final platformCategoryRepositoryProvider = Provider<PlatformCategoryRepository>(
  (ref) => ref.watch(categoryRepositoryImplProvider),
);

class CategoryRepositoryImpl implements PlatformCategoryRepository {
  CategoryRepositoryImpl(this._dataSource, this._logger);

  final SupabaseCategoryDataSource _dataSource;
  final AppLogger _logger;

  @override
  Future<List<PlatformCategory>> getActiveCategories() async {
    try {
      return await _dataSource.getActiveCategories();
    } catch (e) {
      _logger.e('Failed to get active categories', e);
      rethrow;
    }
  }

  @override
  Future<List<PlatformCategory>> getAllCategories() async {
    try {
      return await _dataSource.getAllCategories();
    } catch (e) {
      _logger.e('Failed to get all categories', e);
      rethrow;
    }
  }

  @override
  Future<PlatformCategory?> getCategoryById(String id) async {
    try {
      return await _dataSource.getCategoryById(id);
    } catch (e) {
      _logger.e('Failed to get category: $id', e);
      rethrow;
    }
  }

  @override
  Future<PlatformCategory> createCategory({
    required String name,
    String? nameAr,
    String? nameEn,
    String? icon,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    try {
      return await _dataSource.createCategory(
        name: name,
        nameAr: nameAr,
        nameEn: nameEn,
        icon: icon,
        sortOrder: sortOrder,
        isActive: isActive,
      );
    } catch (e) {
      _logger.e('Failed to create category', e);
      rethrow;
    }
  }

  @override
  Future<PlatformCategory> updateCategory({
    required String id,
    String? name,
    String? nameAr,
    String? nameEn,
    String? icon,
    int? sortOrder,
    bool? isActive,
  }) async {
    try {
      return await _dataSource.updateCategory(
        id: id,
        name: name,
        nameAr: nameAr,
        nameEn: nameEn,
        icon: icon,
        sortOrder: sortOrder,
        isActive: isActive,
      );
    } catch (e) {
      _logger.e('Failed to update category: $id', e);
      rethrow;
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    try {
      return await _dataSource.deleteCategory(id);
    } catch (e) {
      _logger.e('Failed to delete category: $id', e);
      rethrow;
    }
  }

  @override
  Future<String?> uploadCategoryImage({
    required String categoryId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      final url = await _dataSource.uploadCategoryImage(
        categoryId: categoryId,
        imageBytes: imageBytes,
        fileName: fileName,
      );
      if (url != null) {
        await _dataSource.updateCategory(id: categoryId, imageUrl: url);
      }
      return url;
    } catch (e) {
      _logger.e('Failed to upload category image', e);
      rethrow;
    }
  }

  @override
  Future<void> deleteCategoryImage(String imageUrl) async {
    try {
      await _dataSource.deleteCategoryImage(imageUrl);
    } catch (e) {
      _logger.e('Failed to delete category image', e);
    }
  }
}
