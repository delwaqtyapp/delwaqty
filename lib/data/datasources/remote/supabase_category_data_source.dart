import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/services/logger/app_logger.dart';
import 'package:delwaqty/features/customer/home/domain/entities/platform_category.dart';

final supabaseCategoryDataSourceProvider = Provider<SupabaseCategoryDataSource>(
  (ref) => SupabaseCategoryDataSource(
    ref.watch(supabaseClientProvider),
    ref.watch(loggerProvider),
  ),
);

class SupabaseCategoryDataSource {
  SupabaseCategoryDataSource(this._client, this._logger);

  final SupabaseClient _client;
  final AppLogger _logger;
  static const String _tableName = 'categories';
  static const String _bucketName = 'category-images';

  PlatformCategory _fromRow(Map<String, dynamic> row) {
    return PlatformCategory(
      id: row['id'] as String,
      name: row['name'] as String,
      nameAr: row['name_ar'] as String?,
      nameEn: row['name_en'] as String?,
      icon: row['icon'] as String?,
      imageUrl: row['image_url'] as String?,
      sortOrder: row['sort_order'] as int? ?? 0,
      isActive: row['is_active'] as bool? ?? true,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : null,
    );
  }

  Future<List<PlatformCategory>> getActiveCategories() async {
    try {
      final data = await _client
          .from(_tableName)
          .select()
          .eq('is_active', true)
          .order('sort_order');
      return (data as List)
          .map((row) => _fromRow(row as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      _logger.e('Failed to get active categories', e, stack);
      rethrow;
    }
  }

  Future<List<PlatformCategory>> getAllCategories() async {
    try {
      final data = await _client
          .from(_tableName)
          .select()
          .order('sort_order');
      return (data as List)
          .map((row) => _fromRow(row as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      _logger.e('Failed to get all categories', e, stack);
      rethrow;
    }
  }

  Future<PlatformCategory?> getCategoryById(String id) async {
    try {
      final data = await _client
          .from(_tableName)
          .select()
          .eq('id', id)
          .maybeSingle();
      if (data == null) return null;
      return _fromRow(data);
    } catch (e, stack) {
      _logger.e('Failed to get category: $id', e, stack);
      rethrow;
    }
  }

  Future<PlatformCategory> createCategory({
    required String name,
    String? nameAr,
    String? nameEn,
    String? icon,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    try {
      final data = await _client
          .from(_tableName)
          .insert({
            'name': name,
            'name_ar': nameAr,
            'name_en': nameEn,
            'icon': icon,
            'sort_order': sortOrder,
            'is_active': isActive,
          })
          .select()
          .single();
      return _fromRow(data);
    } catch (e, stack) {
      _logger.e('Failed to create category', e, stack);
      rethrow;
    }
  }

  Future<PlatformCategory> updateCategory({
    required String id,
    String? name,
    String? nameAr,
    String? nameEn,
    String? icon,
    int? sortOrder,
    bool? isActive,
    String? imageUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (nameAr != null) updates['name_ar'] = nameAr;
      if (nameEn != null) updates['name_en'] = nameEn;
      if (icon != null) updates['icon'] = icon;
      if (sortOrder != null) updates['sort_order'] = sortOrder;
      if (isActive != null) updates['is_active'] = isActive;
      if (imageUrl != null) updates['image_url'] = imageUrl;

      if (updates.isEmpty) {
        return (await getCategoryById(id))!;
      }

      final data = await _client
          .from(_tableName)
          .update(updates)
          .eq('id', id)
          .select()
          .single();
      return _fromRow(data);
    } catch (e, stack) {
      _logger.e('Failed to update category: $id', e, stack);
      rethrow;
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _client.from(_tableName).delete().eq('id', id);
    } catch (e, stack) {
      _logger.e('Failed to delete category: $id', e, stack);
      rethrow;
    }
  }

  Future<String?> uploadCategoryImage({
    required String categoryId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      final path = 'categories/$categoryId/$fileName';
      await _client.storage.from(_bucketName).uploadBinary(
            path,
            imageBytes,
            fileOptions: const FileOptions(upsert: true),
          );
      final url = _client.storage.from(_bucketName).getPublicUrl(path);
      return url;
    } catch (e, stack) {
      _logger.e('Failed to upload category image', e, stack);
      rethrow;
    }
  }

  Future<void> deleteCategoryImage(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      final bucketIndex = pathSegments.indexOf(_bucketName);
      if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
        final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
        await _client.storage.from(_bucketName).remove([filePath]);
      }
    } catch (e, stack) {
      _logger.e('Failed to delete category image', e, stack);
    }
  }
}
