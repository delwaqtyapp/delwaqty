import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/domain/repositories/user_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final getCurrentUserUseCaseProvider = Provider<GetCurrentUserUseCase>((ref) {
  return GetCurrentUserUseCase(ref.watch(userRepositoryProvider));
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  throw UnimplementedError(
    'UserRepository must be overridden at the data layer',
  );
});

class GetCurrentUserUseCase {
  GetCurrentUserUseCase(this._repository);

  final UserRepository _repository;

  Future<User> call() => _repository.getCurrentUser();
}

final getUserByIdUseCaseProvider = Provider<GetUserByIdUseCase>((ref) {
  return GetUserByIdUseCase(ref.watch(userRepositoryProvider));
});

class GetUserByIdUseCase {
  GetUserByIdUseCase(this._repository);

  final UserRepository _repository;

  Future<User> call(String id) => _repository.getUserById(id);
}
