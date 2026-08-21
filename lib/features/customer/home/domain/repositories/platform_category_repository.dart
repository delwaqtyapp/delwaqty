import 'dart:typed_data';
import 'package:delwaqty/features/customer/home/domain/entities/platform_category.dart';

abstract interface class PlatformCategoryRepository {
  Future<List<PlatformCategory>> getActiveCategories();
  Future<List<PlatformCategory>> getAllCategories();
  Future<PlatformCategory?> getCategoryById(String id);
  Future<PlatformCategory> createCategory({
    required String name,
    String? nameAr,
    String? nameEn,
    String? icon,
    int sortOrder = 0,
    bool isActive = true,
  });
  Future<PlatformCategory> updateCategory({
    required String id,
    String? name,
    String? nameAr,
    String? nameEn,
    String? icon,
    int? sortOrder,
    bool? isActive,
  });
  Future<void> deleteCategory(String id);
  Future<String?> uploadCategoryImage({
    required String categoryId,
    required Uint8List imageBytes,
    required String fileName,
  });
  Future<void> deleteCategoryImage(String imageUrl);
}
