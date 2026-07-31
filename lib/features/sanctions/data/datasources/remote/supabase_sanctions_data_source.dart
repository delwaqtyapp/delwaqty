import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/sanctions/domain/entities/sanction.dart';

class SupabaseSanctionsDataSource {
  final SupabaseClient _client;

  SupabaseSanctionsDataSource(this._client);

  Future<List<Sanction>> getSanctions({bool? active}) async {
    var query = _client.from('sanctions').select();
    if (active != null) query = query.eq('is_active', active);
    final rows = await query.order('created_at', ascending: false);
    return rows.map((r) => Sanction.fromJson(r)).toList();
  }

  Future<List<Sanction>> getUserSanctions(String targetUserId) async {
    final rows = await _client
        .from('sanctions')
        .select()
        .eq('target_user_id', targetUserId)
        .order('created_at', ascending: false);
    return rows.map((r) => Sanction.fromJson(r)).toList();
  }

  Future<Sanction> getSanctionById(String id) async {
    final row = await _client.from('sanctions').select().eq('id', id).single();
    return Sanction.fromJson(row);
  }

  Future<Sanction> createSanction(Sanction sanction) async {
    await _client.from('sanctions').insert(sanction.toJson());
    return sanction;
  }

  Future<Sanction> updateSanction(String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('sanctions').update(updates).eq('id', id);
    return getSanctionById(id);
  }

  Future<void> revokeSanction(String id) async {
    await _client.from('sanctions').update({
      'is_active': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }
}
