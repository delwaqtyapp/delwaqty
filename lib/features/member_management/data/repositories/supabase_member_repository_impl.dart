import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/member_management/domain/entities/member.dart';
import 'package:delwaqty/features/member_management/data/repositories/member_repository.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return ref.watch(supabaseMemberRepositoryImplProvider);
});

final supabaseMemberRepositoryProvider = Provider<SupabaseMemberRepositoryImpl>((ref) {
  return SupabaseMemberRepositoryImpl(
    ref.watch(supabaseClientProvider),
  );
});

final supabaseMemberDataSourceProvider = Provider<SupabaseMemberDataSource>((ref) {
  return SupabaseMemberDataSource(ref.watch(supabaseMemberDataSourceProvider));
});

class SupabaseMemberDataSource {
  SupabaseMemberDataSource(this._client);
  final SupabaseClient _client;

  // Existing RPC methods
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

  Future<List<Map<String, dynamic>>> getMemberTimeline(String memberId,
      {String? cursor, int limit = 20}) async {
    final params = <String, dynamic>{
      'p_member_id': memberId,
      'p_limit': limit,
    };
    if (cursor != null) params['p_cursor'] = cursor;
    final data = await _client.rpc('get_member_timeline', params: params);
    final rows = (data as List?) ?? const [];
    return rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }

  // NEW member Ops RPCs
  Future<List<Member>> memberOpsList({
    String? search,
    String? role,
    String? userType,
    String? accountStatus,
    String? verificationStatus,
    String? serviceType,
    String? serviceCategory,
    String? regionId,
    String? sanctionStatus,
    String? sort,
    DateTime? cursorCreatedAt,
    DateTime? cursorId,
    int limit = 25,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'p_search': search,
      'p_role': role,
      'p_user_type': userType,
      'p_account_status': accountStatus,
      'p_verification_status': verificationStatus,
      'p_service_type': serviceType,
      'p_service_category': serviceCategory,
      'p_region_id': regionId,
      'p_sanction_status': sanctionStatus,
      'p_sort': sort,
      'p_cursor_created_at': cursorCreatedAt?.toIso8601String(),
      'p_cursor_id': cursorId?.toString(),
      'p_offset': offset,
      'p_limit': limit,
    };
    final data = await _client.rpc('member_ops_list', params: params);
    final List<dynamic> rows = data as List? ?? [];
    return rows.map((dynamic json) => Member.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  }

  Future<int> memberOpsCount({
    String? search,
    String? role,
    String? userType,
    String? accountStatus,
    String? verificationStatus,
    String? serviceCategory,
    String? regionId,
    String? sanctionStatus,
  }) async {
    final params = <String, dynamic>{
      'p_search': search,
      'p_role': role,
      'p_user_type': userType,
      'p_account_status': accountStatus,
      'p_verification_status': verificationStatus,
      'p_service_category': serviceCategory,
      'p_region_id': regionId,
      'p_sanction_status': sanctionStatus,
    };
    final result = await _client.rpc<dynamic>('member_ops_count', params: params);
    return (result as num?)?.toInt() ?? 0;
  }

  Future<Map<String, dynamic>?> getMemberOpsProfile(String memberId) async {
    final data = await _client.rpc('get_member_ops_profile', params: {
      'p_member_id': memberId,
    });
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>?> memberFinancialSummary(String memberId) async {
    final data = await _client.rpc('member_financial_summary', params: {
      'p_member_id': memberId,
    });
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }
}

class SupabaseMemberRepositoryImpl implements MemberRepository {
  SupabaseMemberRepositoryImpl(this._dataSource);

  final SupabaseMemberDataSource _dataSource;

  @override
  Future<List<Member>> listMembers({
    String? search,
    String? role,
    String? accountStatus,
    String? regionId,
    String? cursor,
    int limit = 20,
  }) async {
    return await _dataSource.listMembers(
      search: search,
      role: role,
      accountStatus: accountStatus,
      regionId: regionId,
      cursor: cursor,
      limit: limit,
    );
  }

  @override
  Future<Map<String, dynamic>?> getMemberProfile(String memberId) async {
    return await _dataSource.getMemberProfile(memberId);
  }

  @override
  Future<Map<String, dynamic>> getMemberStatus(String memberId) async {
    return await _dataSource.getMemberStatus(memberId);
  }

  @override
  Future<List<Map<String, dynamic>>> getMemberTimeline(String memberId,
      {String? cursor, int limit = 20}) async {
    return await _dataSource.getMemberTimeline(memberId, cursor: cursor, limit: limit);
  }

  // NEW repository methods
  @override
  Future<List<Member>> memberOpsList({
    String? search,
    String? role,
    String? userType,
    String? accountStatus,
    String? verificationStatus,
    String? serviceType,
    String? serviceCategory,
    String? regionId,
    String? sanctionStatus,
    String? sort,
    DateTime? cursorCreatedAt,
    DateTime? cursorId,
    int limit = 25,
    int offset = 0,
  }) async {
    return await _dataSource.memberOpsList(
      search: search,
      role: role,
      userType: userType,
      accountStatus: accountStatus,
      verificationStatus: verificationStatus,
      serviceType: serviceType,
      serviceCategory: serviceCategory,
      regionId: regionId,
      sanctionStatus: sanctionStatus,
      sort: sort,
      cursorCreatedAt: cursorCreatedAt,
      cursorId: cursorId,
      offset: offset,
      limit: limit,
    );
  }

  @override
  Future<int> memberOpsCount({
    String? search,
    String? role,
    String? userType,
    String? accountStatus,
    String? verificationStatus,
    String? serviceCategory,
    String? regionId,
    String? sanctionStatus,
  }) async {
    return await _dataSource.memberOpsCount(
      search: search,
      role: role,
      userType: userType,
      accountStatus: accountStatus,
      verificationStatus: verificationStatus,
      serviceCategory: serviceCategory,
      regionId: regionId,
      sanctionStatus: sanctionStatus,
    );
  }

  @override
  Future<Map<String, dynamic>?> getMemberOpsProfile(String memberId) async {
    return await _dataSource.getMemberOpsProfile(memberId);
  }

  @override
  Future<Map<String, dynamic>?> memberFinancialSummary(String memberId) async {
    return await _dataSource.memberFinancialSummary(memberId);
  }
}