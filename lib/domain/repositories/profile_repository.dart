import 'dart:async';
import 'package:delwaqty/domain/entities/user.dart';

abstract class ProfileRepository {
  Future<User> getProfile(String userId);
  Future<User> updateProfile({
    required String userId,
    required Map<String, dynamic> data,
  });
  Future<User> updateDateOfBirth({
    required String userId,
    required DateTime? dateOfBirth,
  });
  Future<String> uploadAvatar({
    required String userId,
    required List<int> bytes,
    required String fileName,
  });
  Future<String> uploadDocument({
    required String userId,
    required List<int> bytes,
    required String fileName,
  });
  Stream<User> watchProfile(String userId);
}
