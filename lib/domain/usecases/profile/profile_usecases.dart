import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/domain/repositories/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  throw UnimplementedError(
    'ProfileRepository must be overridden at the data layer',
  );
});

final getProfileUseCaseProvider = Provider<GetProfileUseCase>((ref) {
  return GetProfileUseCase(ref.watch(profileRepositoryProvider));
});

class GetProfileUseCase {
  GetProfileUseCase(this._repository);

  final ProfileRepository _repository;

  Future<User> call(String userId) => _repository.getProfile(userId);
}

final updateProfileUseCaseProvider = Provider<UpdateProfileUseCase>((ref) {
  return UpdateProfileUseCase(ref.watch(profileRepositoryProvider));
});

class UpdateProfileUseCase {
  UpdateProfileUseCase(this._repository);

  final ProfileRepository _repository;

  Future<User> call({
    required String userId,
    required Map<String, dynamic> data,
  }) {
    return _repository.updateProfile(userId: userId, data: data);
  }
}

final updateDateOfBirthUseCaseProvider =
    Provider<UpdateDateOfBirthUseCase>((ref) {
  return UpdateDateOfBirthUseCase(ref.watch(profileRepositoryProvider));
});

class UpdateDateOfBirthUseCase {
  UpdateDateOfBirthUseCase(this._repository);

  final ProfileRepository _repository;

  Future<User> call({
    required String userId,
    required DateTime? dateOfBirth,
  }) {
    return _repository.updateDateOfBirth(
      userId: userId,
      dateOfBirth: dateOfBirth,
    );
  }
}

final uploadAvatarUseCaseProvider = Provider<UploadAvatarUseCase>((ref) {
  return UploadAvatarUseCase(ref.watch(profileRepositoryProvider));
});

class UploadAvatarUseCase {
  UploadAvatarUseCase(this._repository);

  final ProfileRepository _repository;

  Future<String> call({
    required String userId,
    required List<int> bytes,
    required String fileName,
  }) {
    return _repository.uploadAvatar(
      userId: userId,
      bytes: bytes,
      fileName: fileName,
    );
  }
}

final uploadDocumentUseCaseProvider = Provider<UploadDocumentUseCase>((ref) {
  return UploadDocumentUseCase(ref.watch(profileRepositoryProvider));
});

class UploadDocumentUseCase {
  UploadDocumentUseCase(this._repository);

  final ProfileRepository _repository;

  Future<String> call({
    required String userId,
    required List<int> bytes,
    required String fileName,
  }) {
    return _repository.uploadDocument(
      userId: userId,
      bytes: bytes,
      fileName: fileName,
    );
  }
}

final watchProfileUseCaseProvider = StreamProvider.autoDispose
    .family<User, String>((ref, userId) {
      final repository = ref.watch(profileRepositoryProvider);
      return repository.watchProfile(userId);
    });
