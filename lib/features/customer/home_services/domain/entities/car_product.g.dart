// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'car_product.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CarProduct _$CarProductFromJson(Map<String, dynamic> json) => _CarProduct(
      id: json['id'] as String,
      sellerId: json['seller_id'] as String,
      driverId: json['driver_id'] as String?,
      merchantId: json['merchant_id'] as String?,
      category: json['category'] as String? ?? 'car',
      make: json['make'] as String?,
      model: json['model'] as String?,
      year: json['year'] as int?,
      color: json['color'] as String?,
      seats: json['seats'] as int? ?? 4,
      photoUrl: json['photo_url'] as String?,
      city: json['city'] as String,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      description: json['description'] as String?,
      isAvailable: json['is_available'] as bool? ?? true,
      isVerified: json['is_verified'] as bool? ?? false,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$CarProductToJson(_CarProduct instance) =>
    <String, dynamic>{
      'id': instance.id,
      'seller_id': instance.sellerId,
      'driver_id': instance.driverId,
      'merchant_id': instance.merchantId,
      'category': instance.category,
      'make': instance.make,
      'model': instance.model,
      'year': instance.year,
      'color': instance.color,
      'seats': instance.seats,
      'photo_url': instance.photoUrl,
      'city': instance.city,
      'price': instance.price,
      'description': instance.description,
      'is_available': instance.isAvailable,
      'is_verified': instance.isVerified,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'created_at': instance.createdAt.toIso8601String(),
    };