import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/member_management/domain/entities/member.dart';
import 'package:delwaqty/features/member_management/domain/repositories/member_repository.dart';
import 'package:delwaqty/features/member_management/data/datasources/remote/supabase_member_data_source.dart';

final supabaseMemberRepositoryProvider = Provider<MemberRepository>((ref) {
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
    try {
      return await _dataSource.listMembers(
        search: search,
        role: role,
        accountStatus: accountStatus,
        regionId: regionId,
        cursor: cursor,
        limit: limit,
      );
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>?> getMemberProfile(String memberId) async {
    try {
      return await _dataSource.getMemberProfile(memberId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> getMemberStatus(String memberId) async {
    try {
      return await _dataSource.getMemberStatus(memberId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getMemberTimeline(
    String memberId, {
    String? cursor,
    int limit = 20,
  }) async {
    try {
      return await _dataSource.getMemberTimeline(
        memberId,
        cursor: cursor,
        limit: limit,
      );
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
