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
}
