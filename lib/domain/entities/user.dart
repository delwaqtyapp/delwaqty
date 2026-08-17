import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:delwaqty/domain/enums/user_type.dart';
import 'package:delwaqty/domain/enums/verification_status.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class User with _$User {
  const factory User({
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
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
