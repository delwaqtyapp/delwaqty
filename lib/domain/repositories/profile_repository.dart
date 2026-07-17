import 'dart:async';
import 'package:delwaqty/domain/entities/user.dart';

abstract class ProfileRepository {
  Future<User> getProfile(String userId);
  Future<User> updateProfile({
    required String userId,
    required Map<String, dynamic> data,
  });
  Future<String> uploadAvatar({
    required String userId,
    required List<int> bytes,
    required String fileName,
  });
  Stream<User> watchProfile(String userId);
}
