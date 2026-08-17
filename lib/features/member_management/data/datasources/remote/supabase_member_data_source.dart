import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/member_management/domain/entities/member.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';

final supabaseMemberDataSourceProvider = Provider<SupabaseMemberDataSource>(
  (ref) => SupabaseMemberDataSource(ref.watch(supabaseClientProvider)),
);

class SupabaseMemberDataSource {
  SupabaseMemberDataSource(this._client);

  final SupabaseClient _client;

  Future<List<Member>> listMembers({
    String? search,
    String? role,
    String? accountStatus,
    String? regionId,
    String? cursor,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{
      'p_limit': limit,
    };
    if (search != null && search.isNotEmpty) params['p_search'] = search;
    if (role != null) params['p_role'] = role;
    if (accountStatus != null) params['p_account_status'] = accountStatus;
    if (regionId != null) params['p_region_id'] = regionId;
    if (cursor != null) params['p_cursor'] = cursor;

    final data = await _client.rpc('list_members', params: params);
    final rows = (data as List?) ?? const [];
    return rows
        .map((r) => Member.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<Map<String, dynamic>?> getMemberProfile(String memberId) async {
    final data = await _client.rpc('get_member_profile', params: {
      'p_member_id': memberId,
    });
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> getMemberStatus(String memberId) async {
    final data = await _client.rpc('get_member_status', params: {
      'p_member_id': memberId,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> getMemberTimeline(
    String memberId, {
    String? cursor,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{
      'p_member_id': memberId,
      'p_limit': limit,
    };
    if (cursor != null) params['p_cursor'] = cursor;

    final data = await _client.rpc('get_member_timeline', params: params);
    final rows = (data as List?) ?? const [];
    return rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }
}
