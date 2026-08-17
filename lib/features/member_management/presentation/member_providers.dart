import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/member_management/domain/entities/member.dart';
import 'package:delwaqty/features/member_management/domain/repositories/member_repository.dart';
import 'package:delwaqty/features/member_management/data/repositories/supabase_member_repository_impl.dart';

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return ref.watch(supabaseMemberRepositoryProvider);
});

final memberListProvider =
    FutureProvider.autoDispose<List<Member>>((ref) async {
  final repo = ref.read(memberRepositoryProvider);
  return repo.listMembers();
});

final memberProfileProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, memberId) async {
  final repo = ref.read(memberRepositoryProvider);
  return repo.getMemberProfile(memberId);
});

final memberStatusProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, memberId) async {
  final repo = ref.read(memberRepositoryProvider);
  return repo.getMemberStatus(memberId);
});

final memberTimelineProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, memberId) async {
  final repo = ref.read(memberRepositoryProvider);
  return repo.getMemberTimeline(memberId);
});
