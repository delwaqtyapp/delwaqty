// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CatalogCategory _$CatalogCategoryFromJson(Map<String, dynamic> json) =>
    _CatalogCategory(
      id: json['id'] as String,
      merchantId: json['merchantId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      imageUrl: json['imageUrl'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isVisible: json['isVisible'] as bool? ?? true,
    );

Map<String, dynamic> _$CatalogCategoryToJson(_CatalogCategory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'merchantId': instance.merchantId,
      'name': instance.name,
      'description': instance.description,
      'icon': instance.icon,
      'imageUrl': instance.imageUrl,
      'sortOrder': instance.sortOrder,
      'isVisible': instance.isVisible,
    };
