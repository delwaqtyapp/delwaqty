import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/admin/member_management/domain/entities/member.dart';
import 'package:delwaqty/features/admin/member_management/domain/repositories/member_repository.dart';
import 'package:delwaqty/features/admin/member_management/data/datasources/remote/supabase_member_data_source.dart';

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return ref.watch(supabaseMemberRepositoryProvider);
});

final supabaseMemberRepositoryProvider = Provider<SupabaseMemberRepositoryImpl>((ref) {
  return SupabaseMemberRepositoryImpl(
    ref.watch(supabaseMemberDataSourceProvider),
  );
});

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
    final result = await _dataSource.getMemberProfile(memberId);
    return result ?? {};
  }

  @override
  Future<List<Map<String, dynamic>>> getMemberTimeline(String memberId,
      {String? cursor, int limit = 20}) async {
    return await _dataSource.getMemberTimeline(memberId, cursor: cursor, limit: limit);
  }

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
      limit: limit,
      offset: offset,
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
