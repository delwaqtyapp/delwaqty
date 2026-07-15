// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FavoriteImpl _$$FavoriteImplFromJson(Map<String, dynamic> json) =>
    _$FavoriteImpl(
      id: json['id'] as String,
      targetId: json['targetId'] as String,
      type: $enumDecode(_$FavoriteTypeEnumMap, json['type']),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$FavoriteImplToJson(_$FavoriteImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'targetId': instance.targetId,
      'type': _$FavoriteTypeEnumMap[instance.type]!,
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$FavoriteTypeEnumMap = {
  FavoriteType.merchant: 'merchant',
  FavoriteType.product: 'product',
};
