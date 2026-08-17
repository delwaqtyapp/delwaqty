import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/domain/enums/user_type.dart';
import 'package:delwaqty/domain/enums/verification_status.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required String email,
    String? fullName,
    String? username,
    String? phone,
    String? avatarUrl,
    @Default('en') String language,
    @Default(false) bool isOnboarded,
    @Default(false) bool isBiometricEnabled,
    @Default('customer') String role,
    @Default(UserType.customer) UserType userType,
    @Default(VerificationStatus.pending) VerificationStatus verificationStatus,
    String? idCardUrl,
    String? profilePhotoUrl,
    String? tradeLicenseUrl,
    String? drivingLicenseUrl,
    DateTime? dateOfBirth,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _UserModel;

  const UserModel._();

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  factory UserModel.fromSupabase(Map<String, dynamic> json) {
    final role = json['role'] as String? ?? 'customer';
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: (json['full_name'] ?? json['name']) as String?,
      username: json['username'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      language: json['language'] as String? ?? 'en',
      isOnboarded: json['is_onboarded'] as bool? ?? false,
      isBiometricEnabled: json['is_biometric_enabled'] as bool? ?? false,
      role: role,
      userType: UserType.fromCode(
        (json['user_type'] ?? json['role']) as String?,
      ),
      verificationStatus: VerificationStatus.fromCode(
        _verificationCode(json, role),
      ),
      idCardUrl: json['id_card_url'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      tradeLicenseUrl: json['trade_license_url'] as String?,
      drivingLicenseUrl: json['driving_license_url'] as String?,
      dateOfBirth: _parseDateOfBirth(json['date_of_birth']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  static String _verificationCode(Map<String, dynamic> json, String role) {
    final value = json['verification_status'] as String?;
    if (value != null && value.isNotEmpty) return value;
    final userType = UserType.fromCode(
      (json['user_type'] ?? role) as String?,
    );
    return userType == UserType.customer ? 'approved' : 'pending';
  }

  static DateTime? _parseDateOfBirth(dynamic value) {
    if (value == null || value is! String || value.isEmpty) return null;
    final date = DateTime.tryParse(value);
    if (date == null) return null;
    return DateTime(date.year, date.month, date.day);
  }

  User toEntity() => User(
    id: id,
    email: email,
    fullName: fullName,
    username: username,
    phone: phone,
    avatarUrl: avatarUrl,
    language: language,
    isOnboarded: isOnboarded,
    isBiometricEnabled: isBiometricEnabled,
    role: role,
    userType: userType,
    verificationStatus: verificationStatus,
    idCardUrl: idCardUrl,
    profilePhotoUrl: profilePhotoUrl,
    tradeLicenseUrl: tradeLicenseUrl,
    drivingLicenseUrl: drivingLicenseUrl,
    dateOfBirth: dateOfBirth,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  Map<String, dynamic> toInsertJson() {
    final json = <String, dynamic>{
      'id': id,
      'email': email,
      'full_name': fullName,
      'language': language,
      'is_onboarded': isOnboarded,
      'is_biometric_enabled': isBiometricEnabled,
      'role': role,
      'user_type': userType.code,
      'verification_status': verificationStatus.code,
    };
    if (username != null) json['username'] = username;
    if (phone != null) json['phone'] = phone;
    if (avatarUrl != null) json['avatar_url'] = avatarUrl;
    if (idCardUrl != null) json['id_card_url'] = idCardUrl;
    if (profilePhotoUrl != null) json['profile_photo_url'] = profilePhotoUrl;
    if (tradeLicenseUrl != null) json['trade_license_url'] = tradeLicenseUrl;
    if (drivingLicenseUrl != null) json['driving_license_url'] = drivingLicenseUrl;
    return json;
  }

  Map<String, dynamic> toUpdateJson() {
    final json = <String, dynamic>{
      'full_name': fullName,
      'language': language,
      'is_onboarded': isOnboarded,
      'is_biometric_enabled': isBiometricEnabled,
      'role': role,
      'user_type': userType.code,
      'verification_status': verificationStatus.code,
    };
    if (username != null) json['username'] = username;
    if (phone != null) json['phone'] = phone;
    if (avatarUrl != null) json['avatar_url'] = avatarUrl;
    if (idCardUrl != null) json['id_card_url'] = idCardUrl;
    if (profilePhotoUrl != null) json['profile_photo_url'] = profilePhotoUrl;
    if (tradeLicenseUrl != null) json['trade_license_url'] = tradeLicenseUrl;
    if (drivingLicenseUrl != null) json['driving_license_url'] = drivingLicenseUrl;
    return json;
  }

  Map<String, dynamic> toSupabaseJson() => toInsertJson();
}
