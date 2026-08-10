// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'merchant.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MerchantImpl _$$MerchantImplFromJson(Map<String, dynamic> json) =>
    _$MerchantImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      type: $enumDecode(_$MerchantTypeEnumMap, json['type']),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String?,
      city: json['city'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      imageUrl: json['imageUrl'] as String?,
      description: json['description'] as String?,
      isOpenNow: json['isOpenNow'] as bool? ?? false,
      isVerified: json['isVerified'] as bool? ?? false,
      isFeatured: json['isFeatured'] as bool? ?? false,
      deliveryAvailable: json['deliveryAvailable'] as bool? ?? false,
      pickupAvailable: json['pickupAvailable'] as bool? ?? false,
      estimatedDeliveryMinutes: (json['estimatedDeliveryMinutes'] as num?)
          ?.toInt(),
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble(),
      minimumOrder: (json['minimumOrder'] as num?)?.toDouble(),
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$MerchantImplToJson(_$MerchantImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': _$MerchantTypeEnumMap[instance.type]!,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'address': instance.address,
      'city': instance.city,
      'rating': instance.rating,
      'ratingCount': instance.ratingCount,
      'imageUrl': instance.imageUrl,
      'description': instance.description,
      'isOpenNow': instance.isOpenNow,
      'isVerified': instance.isVerified,
      'isFeatured': instance.isFeatured,
      'deliveryAvailable': instance.deliveryAvailable,
      'pickupAvailable': instance.pickupAvailable,
      'estimatedDeliveryMinutes': instance.estimatedDeliveryMinutes,
      'deliveryFee': instance.deliveryFee,
      'minimumOrder': instance.minimumOrder,
      'tags': instance.tags,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

const _$MerchantTypeEnumMap = {
  MerchantType.restaurant: 'restaurant',
  MerchantType.grocery: 'grocery',
  MerchantType.supermarket: 'supermarket',
  MerchantType.fruits: 'fruits',
  MerchantType.meat: 'meat',
  MerchantType.seafood: 'seafood',
  MerchantType.pharmacy: 'pharmacy',
  MerchantType.bakery: 'bakery',
  MerchantType.sweets: 'sweets',
  MerchantType.flowers: 'flowers',
  MerchantType.clothing: 'clothing',
  MerchantType.shoes: 'shoes',
  MerchantType.electronics: 'electronics',
  MerchantType.mobile: 'mobile',
  MerchantType.furniture: 'furniture',
  MerchantType.fashion: 'fashion',
  MerchantType.appliances: 'appliances',
  MerchantType.home: 'home',
  MerchantType.cafe: 'cafe',
  MerchantType.petShop: 'petShop',
  MerchantType.fitness: 'fitness',
  MerchantType.gas: 'gas',
  MerchantType.carwash: 'carwash',
  MerchantType.other: 'other',
};
