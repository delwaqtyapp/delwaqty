import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/member_management/domain/entities/member.dart';
import 'package:delwaqty/features/member_management/domain/repositories/member_repository.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return ref.watch(supabaseMemberRepositoryProvider);
});

final supabaseMemberRepositoryProvider = Provider<SupabaseMemberRepositoryImpl>((ref) {
  return SupabaseMemberRepositoryImpl(
    ref.watch(supabaseClientProvider),
  );
});

final supabaseMemberDataSourceProvider = Provider<SupabaseMemberDataSource>((ref) {
  return SupabaseMemberDataSource(ref.watch(supabaseMemberDataSourceProvider));
});

final memberListProvider =
    FutureProvider.autoDispose<List<Member>>((ref) async {
  final repo = ref.read(memberRepositoryProvider);
  return await repo.listMembers();
});

/// State notifier for member operations list with filters and pagination
class MemberOpsListNotifier extends StateNotifier<List<Member>> {
  MemberOpsListNotifier(this.ref) : super([]) {
    _load(); // Load initial data
  }

  final Ref ref;
  Map<String, dynamic> _filters = {
    'search': '',
    'role': null,
    'userType': null,
    'accountStatus': null,
    'verificationStatus': null,
    'serviceCategory': null,
    'sanctionStatus': null,
    'sort': 'newest',
    'limit': 25,
    'offset': 0,
  };

  @override
  void dispose() {
    super.dispose();
  }

  void setFilters(Map<String, dynamic> newFilters) {
    _filters.addAll(newFilters);
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(memberRepositoryProvider);
    final result = await repo.memberOpsList(
      search: _filters['search'] as String?,
      role: _filters['role'] as String?,
      userType: _filters['userType'] as String?,
      accountStatus: _filters['accountStatus'] as String?,
      verificationStatus: _filters['verificationStatus'] as String?,
      serviceCategory: _filters['serviceCategory'] as String?,
      sanctionStatus: _filters['sanctionStatus'] as String?,
      sort: _filters['sort'] as String?,
      cursorCreatedAt: _filters['cursorCreatedAt'] as DateTime?,
      cursorId: _filters['cursorId'] as DateTime?,
      offset: _filters['offset'] as int,
      limit: _filters['limit'] as int,
    );
    state = result;
  }
}

final memberOpsProvider =
    StateNotifierProvider<MemberOpsListNotifier>((ref) {
  return MemberOpsListNotifier(ref);
});

final memberOpsCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.read(memberRepositoryProvider);
  return await repo.memberOpsCount();
});

final memberOpsProfileProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, memberId) async {
  final repo = ref.read(memberRepositoryProvider);
  return await repo.getMemberOpsProfile(memberId);
});

final memberFinancialSummaryProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, memberId) async {
  final repo = ref.read(memberRepositoryProvider);
  return await repo.memberFinancialSummary(memberId);
});

final memberProfileProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, memberId) async {
  final repo = ref.read(memberRepositoryProvider);
  return await repo.getMemberProfile(memberId);
});

final memberStatusProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, memberId) async {
  final repo = ref.read(memberRepositoryProvider);
  return await repo.getMemberStatus(memberId);
});

final memberTimelineProvider =
    FutureProvider.autoDispose
        .family<List<Map<String, dynamic>>, String>((ref, memberId) async {
  final repo = ref.read(memberRepositoryProvider);
  return await repo.getMemberTimeline(memberId);
});