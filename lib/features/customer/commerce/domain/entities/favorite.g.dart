// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Favorite _$FavoriteFromJson(Map<String, dynamic> json) => _Favorite(
  id: json['id'] as String,
  targetId: json['targetId'] as String,
  type: $enumDecode(_$FavoriteTypeEnumMap, json['type']),
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$FavoriteToJson(_Favorite instance) => <String, dynamic>{
  'id': instance.id,
  'targetId': instance.targetId,
  'type': _$FavoriteTypeEnumMap[instance.type]!,
  'createdAt': instance.createdAt.toIso8601String(),
};

const _$FavoriteTypeEnumMap = {
  FavoriteType.merchant: 'merchant',
  FavoriteType.product: 'product',
};
