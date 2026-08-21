import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/reservation.dart';

final supabaseReservationDataSourceProvider =
    Provider<SupabaseReservationDataSource>((ref) {
      return SupabaseReservationDataSource(ref.watch(supabaseClientProvider));
    });

class SupabaseReservationDataSource {
  SupabaseReservationDataSource(this._client);
  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  Reservation _fromRow(Map<String, dynamic> row) => Reservation(
    id: row['id'] as String,
    userId: row['user_id'] as String,
    merchantId: row['merchant_id'] as String,
    branchId: row['branch_id'] as String?,
    partySize: row['party_size'] as int,
    reservationTime: DateTime.parse(row['reservation_time'] as String),
    specialRequests: row['special_requests'] as String?,
    tableNumber: row['table_number'] as String?,
    durationMinutes: row['duration_minutes'] as int? ?? 120,
    status: ReservationStatus.values.firstWhere(
      (s) => s.name == row['status'],
      orElse: () => ReservationStatus.pending,
    ),
    createdAt: DateTime.parse(row['created_at'] as String),
  );

  Future<List<Reservation>> getReservations(
    String merchantId, {
    ReservationStatus? status,
  }) async {
    var query = _client
        .from('reservations')
        .select()
        .eq('merchant_id', merchantId);
    if (status != null) query = query.eq('status', status.name);
    final data = await query.order('reservation_time', ascending: false);
    return (data as List)
        .map((r) => _fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<Reservation>> getUserReservations(
    String userId, {
    ReservationStatus? status,
  }) async {
    var query = _client.from('reservations').select().eq('user_id', userId);
    if (status != null) query = query.eq('status', status.name);
    final data = await query.order('reservation_time', ascending: false);
    return (data as List)
        .map((r) => _fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<Reservation?> getReservationById(String id) async {
    final data = await _client
        .from('reservations')
        .select()
        .eq('id', id)
        .maybeSingle();
    return data != null ? _fromRow(data) : null;
  }

  Future<Reservation> createReservation(Reservation reservation) async {
    final userId = _userId;
    if (userId == null) throw Exception('User not authenticated');
    final data = await _client
        .from('reservations')
        .insert({
          'user_id': userId,
          'merchant_id': reservation.merchantId,
          'branch_id': reservation.branchId,
          'party_size': reservation.partySize,
          'reservation_time': reservation.reservationTime.toIso8601String(),
          'special_requests': reservation.specialRequests,
          'table_number': reservation.tableNumber,
          'duration_minutes': reservation.durationMinutes,
          'status': reservation.status.name,
        })
        .select()
        .single();
    return _fromRow(data);
  }

  Future<Reservation> updateReservation(
    String id,
    ReservationStatus status,
  ) async {
    final data = await _client
        .from('reservations')
        .update({'status': status.name})
        .eq('id', id)
        .select()
        .single();
    return _fromRow(data);
  }

  Future<Reservation> modifyReservation({
    required String reservationId,
    int? partySize,
    DateTime? reservationTime,
    String? specialRequests,
    String? tableNumber,
  }) async {
    final update = <String, dynamic>{};
    if (partySize != null) update['party_size'] = partySize;
    if (reservationTime != null)
      update['reservation_time'] = reservationTime.toIso8601String();
    if (specialRequests != null) update['special_requests'] = specialRequests;
    if (tableNumber != null) update['table_number'] = tableNumber;
    if (update.isEmpty) return (await getReservationById(reservationId))!;
    final data = await _client
        .from('reservations')
        .update(update)
        .eq('id', reservationId)
        .select()
        .single();
    return _fromRow(data);
  }

  Future<Reservation> cancelReservation(
    String reservationId, {
    String? reason,
  }) async {
    final update = <String, dynamic>{
      'status': ReservationStatus.cancelled.name,
    };
    if (reason != null) update['special_requests'] = 'CANCELLED: $reason';
    final data = await _client
        .from('reservations')
        .update(update)
        .eq('id', reservationId)
        .select()
        .single();
    return _fromRow(data);
  }

  Future<List<ReservationSlot>> getAvailableSlots({
    required String merchantId,
    required DateTime date,
    required int partySize,
    String? branchId,
  }) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    var query = _client
        .from('reservations')
        .select()
        .eq('merchant_id', merchantId)
        .gte('reservation_time', dayStart.toIso8601String())
        .lt('reservation_time', dayEnd.toIso8601String())
        .not('status', 'eq', 'cancelled');
    if (branchId != null) query = query.eq('branch_id', branchId);
    final data = await query;
    final bookedTimes = (data as List)
        .map((r) => DateTime.parse(r['reservation_time'] as String))
        .toList();
    final slots = <ReservationSlot>[];
    for (var hour = 10; hour < 23; hour++) {
      for (var minute = 0; minute < 60; minute += 30) {
        final slotTime = DateTime(
          date.year,
          date.month,
          date.day,
          hour,
          minute,
        );
        final isBooked = bookedTimes.any(
          (bt) => bt.difference(slotTime).abs() < const Duration(minutes: 90),
        );
        slots.add(
          ReservationSlot(
            time: slotTime,
            tableNumber: 'T${hour - 10}-${minute == 0 ? "A" : "B"}',
            capacity: partySize,
            isAvailable: !isBooked,
          ),
        );
      }
    }
    return slots;
  }
}
