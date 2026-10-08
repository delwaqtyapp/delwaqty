import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Signed-URL lifetime for private identity documents: long enough for the
/// admin verification console to open the file, short enough that a leaked
/// link expires on its own.
const int _signedUrlSeconds = 3600;


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

  /// Uploads an identity scan (national ID) for verification.
///
/// This used to write into the PUBLIC `profiles` bucket through
/// `getPublicUrl`, which made every provider's identity document a
/// world-readable link. Identity documents now live in the private
/// `identity-documents` bucket (migration 103) under an owner-scoped
/// path, and are referenced with a short-lived signed URL.
Future<String> uploadDoc(String name, Uint8List bytes) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Must be authenticated to upload verification docs');
    }
    const bucket = 'identity-documents';
    final path = '$uid/verification/$name';
    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );
    final signed = await _client.storage.from(bucket).createSignedUrl(
      path,
      _signedUrlSeconds,
    );
    return signed;
  }
}
