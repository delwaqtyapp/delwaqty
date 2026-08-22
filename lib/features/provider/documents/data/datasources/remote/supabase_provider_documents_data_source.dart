import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class ProviderDocumentsDataSource {
  ProviderDocumentsDataSource(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> getDocuments() async {
    final res = await _client.rpc('provider_get_documents');
    final list = (res as List?) ?? <dynamic>[];
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> upsertDocument(
    String docType,
    String fileUrl,
  ) async {
    final res = await _client.rpc(
      'provider_upsert_document',
      params: {'p_doc_type': docType, 'p_file_url': fileUrl},
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<String> uploadDoc(String name, Uint8List bytes) async {
    final uid = _client.auth.currentUser?.id ?? 'anon';
    final path = 'provider_documents/$uid/$name';
    await _client.storage.from('profiles').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );
    return _client.storage.from('profiles').getPublicUrl(path);
  }
}
