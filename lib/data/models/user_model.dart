import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:delwaqty/domain/entities/user.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required String email,
    String? fullName,
    String? phone,
    String? avatarUrl,
    @Default('en') String language,
    @Default(false) bool isOnboarded,
    @Default('customer') String role,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _UserModel;

  const UserModel._();

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  factory UserModel.fromSupabase(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: (json['full_name'] ?? json['name']) as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      language: json['language'] as String? ?? 'en',
      isOnboarded: json['is_onboarded'] as bool? ?? false,
      role: json['role'] as String? ?? 'customer',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  User toEntity() => User(
    id: id,
    email: email,
    fullName: fullName,
    phone: phone,
    avatarUrl: avatarUrl,
    language: language,
    isOnboarded: isOnboarded,
    role: role,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  Map<String, dynamic> toSupabaseJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'phone': phone,
    'avatar_url': avatarUrl,
    'language': language,
    'is_onboarded': isOnboarded,
    'role': role,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}
