import 'package:freezed_annotation/freezed_annotation.dart';

part 'catalog_category.freezed.dart';
part 'catalog_category.g.dart';

@freezed
abstract class CatalogCategory with _$CatalogCategory {
  const factory CatalogCategory({
    required String id,
    required String merchantId,
    required String name,
    String? description,
    String? icon,
    String? imageUrl,
    @Default(0) int sortOrder,
    @Default(true) bool isVisible,
  }) = _CatalogCategory;

  factory CatalogCategory.fromJson(Map<String, dynamic> json) =>
      _$CatalogCategoryFromJson(json);
}
