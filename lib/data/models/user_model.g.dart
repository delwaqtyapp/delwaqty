// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserModelImpl _$$UserModelImplFromJson(Map<String, dynamic> json) =>
    _$UserModelImpl(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String?,
      username: json['username'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      language: json['language'] as String? ?? 'en',
      isOnboarded: json['isOnboarded'] as bool? ?? false,
      isBiometricEnabled: json['isBiometricEnabled'] as bool? ?? false,
      role: json['role'] as String? ?? 'customer',
      userType:
          $enumDecodeNullable(_$UserTypeEnumMap, json['userType']) ??
          UserType.customer,
      verificationStatus:
          $enumDecodeNullable(
            _$VerificationStatusEnumMap,
            json['verificationStatus'],
          ) ??
          VerificationStatus.pending,
      idCardUrl: json['idCardUrl'] as String?,
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$UserModelImplToJson(_$UserModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'fullName': instance.fullName,
      'username': instance.username,
      'phone': instance.phone,
      'avatarUrl': instance.avatarUrl,
      'language': instance.language,
      'isOnboarded': instance.isOnboarded,
      'isBiometricEnabled': instance.isBiometricEnabled,
      'role': instance.role,
      'userType': _$UserTypeEnumMap[instance.userType]!,
      'verificationStatus':
          _$VerificationStatusEnumMap[instance.verificationStatus]!,
      'idCardUrl': instance.idCardUrl,
      'profilePhotoUrl': instance.profilePhotoUrl,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

const _$UserTypeEnumMap = {
  UserType.customer: 'customer',
  UserType.provider: 'provider',
  UserType.delivery: 'delivery',
};

const _$VerificationStatusEnumMap = {
  VerificationStatus.pending: 'pending',
  VerificationStatus.approved: 'approved',
  VerificationStatus.rejected: 'rejected',
};
