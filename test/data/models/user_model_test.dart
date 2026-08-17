import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/data/models/user_model.dart';
import 'package:delwaqty/domain/enums/user_type.dart';
import 'package:delwaqty/domain/enums/verification_status.dart';
import 'package:delwaqty/domain/entities/user.dart';

void main() {
  group('UserModel', () {
    final testDate = DateTime(2024, 1, 15, 10, 30);
    final testDateIso = testDate.toIso8601String();

    final testJson = <String, dynamic>{
      'id': 'user-123',
      'email': 'test@example.com',
      'fullName': 'John Doe',
      'username': 'john_doe',
      'phone': '+1234567890',
      'avatarUrl': 'https://example.com/avatar.jpg',
      'language': 'ar',
      'isOnboarded': true,
      'userType': 'provider',
      'verificationStatus': 'pending',
      'idCardUrl': 'https://example.com/id.jpg',
      'profilePhotoUrl': 'https://example.com/photo.jpg',
      'createdAt': testDateIso,
      'updatedAt': testDateIso,
    };

    group('fromJson', () {
      test('creates UserModel from JSON', () {
        final model = UserModel.fromJson(testJson);
        expect(model.id, 'user-123');
        expect(model.email, 'test@example.com');
        expect(model.fullName, 'John Doe');
        expect(model.username, 'john_doe');
        expect(model.phone, '+1234567890');
        expect(model.avatarUrl, 'https://example.com/avatar.jpg');
        expect(model.language, 'ar');
        expect(model.isOnboarded, isTrue);
        expect(model.userType, UserType.provider);
        expect(model.verificationStatus, VerificationStatus.pending);
        expect(model.idCardUrl, 'https://example.com/id.jpg');
        expect(model.profilePhotoUrl, 'https://example.com/photo.jpg');
        expect(model.createdAt, testDate);
        expect(model.updatedAt, testDate);
      });

      test('handles null optional fields', () {
        final json = <String, dynamic>{
          'id': 'user-123',
          'email': 'test@example.com',
          'fullName': null,
          'username': null,
          'phone': null,
          'avatarUrl': null,
          'language': null,
          'isOnboarded': null,
          'createdAt': testDateIso,
          'updatedAt': null,
        };
        final model = UserModel.fromJson(json);
        expect(model.fullName, isNull);
        expect(model.username, isNull);
        expect(model.phone, isNull);
        expect(model.avatarUrl, isNull);
        expect(model.language, 'en');
        expect(model.isOnboarded, isFalse);
        expect(model.updatedAt, isNull);
      });
    });

    group('fromSupabase', () {
      test('creates UserModel from Supabase snake_case JSON', () {
        final supabaseJson = <String, dynamic>{
          'id': 'user-123',
          'email': 'test@example.com',
          'full_name': 'John Doe',
          'username': 'john_doe',
          'phone': '+1234567890',
          'avatar_url': 'https://example.com/avatar.jpg',
          'language': 'ar',
          'is_onboarded': true,
          'user_type': 'delivery',
          'verification_status': 'rejected',
          'id_card_url': 'https://example.com/id.jpg',
          'profile_photo_url': 'https://example.com/photo.jpg',
          'date_of_birth': '1990-05-14',
          'created_at': testDateIso,
          'updated_at': testDateIso,
        };
        final model = UserModel.fromSupabase(supabaseJson);
        expect(model.id, 'user-123');
        expect(model.fullName, 'John Doe');
        expect(model.username, 'john_doe');
        expect(model.language, 'ar');
        expect(model.userType, UserType.delivery);
        expect(model.verificationStatus, VerificationStatus.rejected);
        expect(model.idCardUrl, 'https://example.com/id.jpg');
        expect(model.profilePhotoUrl, 'https://example.com/photo.jpg');
        expect(model.dateOfBirth, DateTime(1990, 5, 14));
      });

      test('parses date_of_birth from Supabase JSON as a date-only value', () {
        final supabaseJson = <String, dynamic>{
          'id': 'user-123',
          'email': 'test@example.com',
          'date_of_birth': '1985-12-03T00:00:00',
          'created_at': testDateIso,
        };
        final model = UserModel.fromSupabase(supabaseJson);
        expect(model.dateOfBirth, DateTime(1985, 12, 3));
      });

      test('defaults date_of_birth to null when missing', () {
        final supabaseJson = <String, dynamic>{
          'id': 'user-123',
          'email': 'test@example.com',
          'created_at': testDateIso,
        };
        final model = UserModel.fromSupabase(supabaseJson);
        expect(model.dateOfBirth, isNull);
      });

      test('maps is_biometric_enabled from Supabase JSON', () {
        final supabaseJson = <String, dynamic>{
          'id': 'user-123',
          'email': 'test@example.com',
          'is_biometric_enabled': true,
          'created_at': testDateIso,
        };
        final model = UserModel.fromSupabase(supabaseJson);
        expect(model.isBiometricEnabled, isTrue);
      });

      test('defaults is_biometric_enabled to false when missing', () {
        final supabaseJson = <String, dynamic>{
          'id': 'user-123',
          'email': 'test@example.com',
          'created_at': testDateIso,
        };
        final model = UserModel.fromSupabase(supabaseJson);
        expect(model.isBiometricEnabled, isFalse);
      });

      test('defaults customer verification status to approved', () {
        final supabaseJson = <String, dynamic>{
          'id': 'user-123',
          'email': 'test@example.com',
          'user_type': 'customer',
          'created_at': testDateIso,
        };
        final model = UserModel.fromSupabase(supabaseJson);
        expect(model.userType, UserType.customer);
        expect(model.verificationStatus, VerificationStatus.approved);
      });

      test('defaults provider verification status to pending', () {
        final supabaseJson = <String, dynamic>{
          'id': 'user-123',
          'email': 'test@example.com',
          'user_type': 'provider',
          'created_at': testDateIso,
        };
        final model = UserModel.fromSupabase(supabaseJson);
        expect(model.userType, UserType.provider);
        expect(model.verificationStatus, VerificationStatus.pending);
      });

      test('falls back to role when user_type is missing', () {
        final supabaseJson = <String, dynamic>{
          'id': 'user-123',
          'email': 'test@example.com',
          'role': 'delivery',
          'created_at': testDateIso,
        };
        final model = UserModel.fromSupabase(supabaseJson);
        expect(model.userType, UserType.delivery);
      });

      test('defaults language to en when null', () {
        final supabaseJson = <String, dynamic>{
          'id': 'user-123',
          'email': 'test@example.com',
          'full_name': null,
          'username': null,
          'phone': null,
          'avatar_url': null,
          'language': null,
          'is_onboarded': null,
          'created_at': testDateIso,
          'updated_at': null,
        };
        final model = UserModel.fromSupabase(supabaseJson);
        expect(model.language, 'en');
        expect(model.isOnboarded, isFalse);
      });
    });

    group('toJson', () {
      test('serializes to JSON with correct keys', () {
        final model = UserModel.fromJson(testJson);
        final json = model.toJson();
        expect(json['id'], 'user-123');
        expect(json['email'], 'test@example.com');
        expect(json['fullName'], 'John Doe');
        expect(json['createdAt'], testDateIso);
      });
    });

    group('toSupabaseJson', () {
      test('serializes to snake_case JSON for Supabase', () {
        final model = UserModel.fromJson(testJson);
        final json = model.toSupabaseJson();
        expect(json['id'], 'user-123');
        expect(json['full_name'], 'John Doe');
        expect(json['username'], 'john_doe');
        expect(json['avatar_url'], 'https://example.com/avatar.jpg');
        expect(json['user_type'], 'provider');
        expect(json['verification_status'], 'pending');
        expect(json['is_biometric_enabled'], isFalse);
        expect(json['id_card_url'], 'https://example.com/id.jpg');
        expect(json['profile_photo_url'], 'https://example.com/photo.jpg');
        expect(json.containsKey('created_at'), isFalse);
      });
    });

    group('toEntity', () {
      test('converts UserModel to domain User entity', () {
        final model = UserModel.fromJson(testJson);
        final entity = model.toEntity();
        expect(entity, isA<User>());
        expect(entity.id, model.id);
        expect(entity.email, model.email);
        expect(entity.fullName, model.fullName);
        expect(entity.username, model.username);
        expect(entity.phone, model.phone);
        expect(entity.avatarUrl, model.avatarUrl);
        expect(entity.language, model.language);
        expect(entity.isOnboarded, model.isOnboarded);
        expect(entity.isBiometricEnabled, model.isBiometricEnabled);
        expect(entity.userType, model.userType);
        expect(entity.verificationStatus, model.verificationStatus);
        expect(entity.idCardUrl, model.idCardUrl);
        expect(entity.profilePhotoUrl, model.profilePhotoUrl);
        expect(entity.dateOfBirth, model.dateOfBirth);
        expect(entity.createdAt, model.createdAt);
        expect(entity.updatedAt, model.updatedAt);
      });
    });

    group('equality', () {
      test('two identical models are equal', () {
        final model1 = UserModel.fromJson(testJson);
        final model2 = UserModel.fromJson(testJson);
        expect(model1, equals(model2));
      });

      test('two different models are not equal', () {
        final model1 = UserModel.fromJson(testJson);
        final differentJson = Map<String, dynamic>.from(testJson)
          ..['id'] = 'different-id';
        final model2 = UserModel.fromJson(differentJson);
        expect(model1, isNot(equals(model2)));
      });
    });
  });
}
