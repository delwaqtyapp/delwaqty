import 'dart:typed_data';

import 'package:delwaqty/core/errors/exceptions.dart';
import '../../data/datasources/remote/supabase_provider_verification_data_source.dart';

abstract class ProviderVerificationRepository {
  Future<Map<String, dynamic>> getMyVerification();
  Future<Map<String, dynamic>> submitVerification(
    String idCardUrl,
    String profilePhotoUrl,
  );
  Future<void> reapplyVerification(
    String idCardUrl,
    String profilePhotoUrl,
  );
  Future<String> uploadDoc(String name, Uint8List bytes);
}

class ProviderVerificationRepositoryImpl
    implements ProviderVerificationRepository {
  ProviderVerificationRepositoryImpl(this._source);

  final ProviderVerificationDataSource _source;

  @override
  Future<Map<String, dynamic>> getMyVerification() async {
    try {
      return await _source.getMyVerification();
    } catch (e) {
      throw ServerException(message: _message(e));
    }
  }

  @override
  Future<Map<String, dynamic>> submitVerification(
    String idCardUrl,
    String profilePhotoUrl,
  ) async {
    try {
      return await _source.submitVerification(idCardUrl, profilePhotoUrl);
    } catch (e) {
      throw ServerException(message: _message(e));
    }
  }

  @override
  Future<void> reapplyVerification(
    String idCardUrl,
    String profilePhotoUrl,
  ) async {
    try {
      await _source.reapplyVerification(idCardUrl, profilePhotoUrl);
    } catch (e) {
      throw ServerException(message: _message(e));
    }
  }

  @override
  Future<String> uploadDoc(String name, Uint8List bytes) async {
    try {
      return await _source.uploadDoc(name, bytes);
    } catch (e) {
      throw ServerException(message: _message(e));
    }
  }

  String _message(Object e) =>
      e is ServerException ? e.message : 'Verification error: $e';
}
