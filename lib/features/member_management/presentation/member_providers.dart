import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/member_management/domain/entities/member.dart';
import 'package:delwaqty/features/member_management/data/repositories/supabase_member_repository_impl.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';

final memberListProvider =
    FutureProvider.autoDispose<List<Member>>((ref) async {
  final repo = ref.watch(memberRepositoryProvider);
  return await repo.listMembers();
});

class MemberOpsListNotifier extends StateNotifier<List<Member>> {
  MemberOpsListNotifier(this.ref) : super([]) {
    _load();
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
      offset: _filters['offset'] as int,
      limit: _filters['limit'] as int,
    );
    state = result;
  }
}

final memberOpsProvider =
    StateNotifierProvider<MemberOpsListNotifier, List<Member>>((ref) {
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
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, memberId) async {
  final repo = ref.read(memberRepositoryProvider);
  return await repo.getMemberTimeline(memberId);
});

final memberComplaintsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, memberId) async {
  final client = ref.read(supabaseClientProvider);
  final data = await client
      .from('complaints')
      .select()
      .or('complainant_id.eq.$memberId,respondent_id.eq.$memberId')
      .order('created_at', ascending: false)
      .limit(50);
  return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

final memberSanctionsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, memberId) async {
  final client = ref.read(supabaseClientProvider);
  final data = await client
      .from('sanctions')
      .select()
      .eq('target_user_id', memberId)
      .order('created_at', ascending: false)
      .limit(50);
  return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

final memberSupportRoomsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, memberId) async {
  final client = ref.read(supabaseClientProvider);
  final data = await client
      .from('chat_rooms')
      .select()
      .contains('participant_ids', [memberId])
      .order('last_message_at', ascending: false)
      .limit(20);
  return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

final memberVerificationProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, memberId) async {
  final client = ref.read(supabaseClientProvider);
  final data = await client
      .from('verification_attempts')
      .select()
      .eq('user_id', memberId)
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();
  return data;
});

final memberOrdersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, memberId) async {
  final client = ref.read(supabaseClientProvider);
  final data = await client
      .from('orders')
      .select()
      .eq('user_id', memberId)
      .order('created_at', ascending: false)
      .limit(50);
  return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

final memberServiceBookingsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, memberId) async {
  final client = ref.read(supabaseClientProvider);
  final data = await client
      .from('service_bookings')
      .select()
      .eq('user_id', memberId)
      .order('created_at', ascending: false)
      .limit(50);
  return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

final memberDriverLocationProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, memberId) async {
  final client = ref.read(supabaseClientProvider);
  final driverRow = await client
      .from('drivers')
      .select('id')
      .eq('user_id', memberId)
      .limit(1)
      .maybeSingle();
  if (driverRow == null) return null;
  final driverId = driverRow['id'] as String;
  final data = await client
      .from('driver_locations')
      .select()
      .eq('driver_id', driverId)
      .order('updated_at', ascending: false)
      .limit(1)
      .maybeSingle();
  return data;
});
