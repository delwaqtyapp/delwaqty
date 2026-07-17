import 'package:delwaqty/domain/entities/user.dart';

abstract class UserRepository {
  Future<User> getCurrentUser();
  Future<User> getUserById(String id);
  Future<User> updateUser({
    required String id,
    required Map<String, dynamic> data,
  });
  Future<void> deleteUser(String id);
  Future<void> updateLanguage({
    required String userId,
    required String language,
  });
}
