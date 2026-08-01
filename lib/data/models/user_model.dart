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
    String? username,
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
      username: json['username'] as String?,
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
    username: username,
    phone: phone,
    avatarUrl: avatarUrl,
    language: language,
    isOnboarded: isOnboarded,
    role: role,
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
      'role': role,
    };
    if (username != null) json['username'] = username;
    if (phone != null) json['phone'] = phone;
    if (avatarUrl != null) json['avatar_url'] = avatarUrl;
    return json;
  }

  Map<String, dynamic> toUpdateJson() {
    final json = <String, dynamic>{
      'full_name': fullName,
      'language': language,
      'is_onboarded': isOnboarded,
      'role': role,
    };
    if (username != null) json['username'] = username;
    if (phone != null) json['phone'] = phone;
    if (avatarUrl != null) json['avatar_url'] = avatarUrl;
    return json;
  }

  Map<String, dynamic> toSupabaseJson() => toInsertJson();
}
