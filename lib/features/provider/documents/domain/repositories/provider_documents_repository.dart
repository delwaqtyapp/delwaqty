import 'dart:typed_data';

import 'package:delwaqty/core/errors/exceptions.dart';
import '../../data/datasources/remote/supabase_provider_documents_data_source.dart';

abstract class ProviderDocumentsRepository {
  Future<List<Map<String, dynamic>>> getDocuments();
  Future<Map<String, dynamic>> upsertDocument(String docType, String fileUrl);
  Future<String> uploadDoc(String name, Uint8List bytes);
}

class ProviderDocumentsRepositoryImpl implements ProviderDocumentsRepository {
  ProviderDocumentsRepositoryImpl(this._source);

  final ProviderDocumentsDataSource _source;

  @override
  Future<List<Map<String, dynamic>>> getDocuments() async {
    try {
      return await _source.getDocuments();
    } catch (e) {
      throw ServerException(message: 'Failed to load documents: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> upsertDocument(
    String docType,
    String fileUrl,
  ) async {
    try {
      return await _source.upsertDocument(docType, fileUrl);
    } catch (e) {
      throw ServerException(message: 'Failed to upload document: $e');
    }
  }

  @override
  Future<String> uploadDoc(String name, Uint8List bytes) async {
    try {
      return await _source.uploadDoc(name, bytes);
    } catch (e) {
      throw ServerException(message: 'Failed to store document: $e');
    }
  }
}
