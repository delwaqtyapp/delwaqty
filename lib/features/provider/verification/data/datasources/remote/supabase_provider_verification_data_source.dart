import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class ProviderVerificationDataSource {
  ProviderVerificationDataSource(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> getMyVerification() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return <String, dynamic>{};
    final row = await _client
        .from('users')
        .select(
          'verification_status, rejection_reason, id_card_url, profile_photo_url',
        )
        .eq('id', uid)
        .maybeSingle();
    return Map<String, dynamic>.from(row ?? <String, dynamic>{});
  }

  Future<Map<String, dynamic>> submitVerification(
    String idCardUrl,
    String profilePhotoUrl,
  ) async {
    final res = await _client.rpc(
      'provider_submit_verification',
      params: {
        'p_id_card_url': idCardUrl,
        'p_profile_photo_url': profilePhotoUrl,
      },
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<void> reapplyVerification(
    String idCardUrl,
    String profilePhotoUrl,
  ) async {
    await _client.rpc(
      'reapply_verification',
      params: {
        'p_id_card_url': idCardUrl,
        'p_profile_photo_url': profilePhotoUrl,
      },
    );
  }

  Future<String> uploadDoc(String name, Uint8List bytes) async {
    final uid = _client.auth.currentUser?.id ?? 'anon';
    final path = 'verification/$uid/$name';
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
