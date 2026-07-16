import 'package:delwaqty/features/restaurant/domain/entities/reservation.dart';

abstract interface class ReservationRepository {
  Future<List<Reservation>> getReservations(String merchantId, {ReservationStatus? status});
  Future<List<Reservation>> getUserReservations(String userId, {ReservationStatus? status});
  Future<Reservation?> getReservationById(String id);
  Future<Reservation> createReservation(Reservation reservation);
  Future<Reservation> updateReservation(String id, ReservationStatus status);
  Future<Reservation> modifyReservation({
    required String reservationId,
    int? partySize,
    DateTime? reservationTime,
    String? specialRequests,
    String? tableNumber,
  });
  Future<Reservation> cancelReservation(String reservationId, {String? reason});
  Future<List<ReservationSlot>> getAvailableSlots({
    required String merchantId,
    required DateTime date,
    required int partySize,
    String? branchId,
  });
}
