// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'car_product.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CarProduct _$CarProductFromJson(Map<String, dynamic> json) => _CarProduct(
      id: json['id'] as String,
      sellerId: json['sellerId'] as String,
      driverId: json['driverId'] as String?,
      merchantId: json['merchantId'] as String?,
      category: json['category'] as String? ?? 'car',
      make: json['make'] as String?,
      model: json['model'] as String?,
      year: json['year'] as int?,
      color: json['color'] as String?,
      seats: json['seats'] as int? ?? 4,
      photoUrl: json['photoUrl'] as String?,
      city: json['city'] as String,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      description: json['description'] as String?,
      isAvailable: json['isAvailable'] as bool? ?? true,
      isVerified: json['isVerified'] as bool? ?? false,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$CarProductToJson(_CarProduct instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sellerId': instance.sellerId,
      'driverId': instance.driverId,
      'merchantId': instance.merchantId,
      'category': instance.category,
      'make': instance.make,
      'model': instance.model,
      'year': instance.year,
      'color': instance.color,
      'seats': instance.seats,
      'photoUrl': instance.photoUrl,
      'city': instance.city,
      'price': instance.price,
      'description': instance.description,
      'isAvailable': instance.isAvailable,
      'isVerified': instance.isVerified,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'createdAt': instance.createdAt.toIso8601String(),
    };