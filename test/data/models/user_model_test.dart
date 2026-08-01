import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/data/models/user_model.dart';
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
          'created_at': testDateIso,
          'updated_at': testDateIso,
        };
        final model = UserModel.fromSupabase(supabaseJson);
        expect(model.id, 'user-123');
        expect(model.fullName, 'John Doe');
        expect(model.username, 'john_doe');
        expect(model.language, 'ar');
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
