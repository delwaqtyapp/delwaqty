import 'package:delwaqty/features/member_management/domain/entities/member.dart';

abstract class MemberRepository {
  Future<List<Member>> listMembers({
    String? search,
    String? role,
    String? accountStatus,
    String? regionId,
    String? cursor,
    int limit = 20,
  });

  Future<Map<String, dynamic>?> getMemberProfile(String memberId);

  Future<Map<String, dynamic>> getMemberStatus(String memberId);

  Future<List<Map<String, dynamic>>> getMemberTimeline(
    String memberId, {
    String? cursor,
    int limit = 20,
  });

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
  });

  Future<int> memberOpsCount({
    String? search,
    String? role,
    String? userType,
    String? accountStatus,
    String? verificationStatus,
    String? serviceCategory,
    String? regionId,
    String? sanctionStatus,
  });

  Future<Map<String, dynamic>?> getMemberOpsProfile(String memberId);

  Future<Map<String, dynamic>?> memberFinancialSummary(String memberId);
}
