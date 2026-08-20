import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/customer/restaurant/data/datasources/remote/supabase_reservation_data_source.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/reservation.dart';
import 'package:delwaqty/features/customer/restaurant/domain/repositories/reservation_repository.dart';

class ReservationRepositoryImpl implements ReservationRepository {
  ReservationRepositoryImpl(this._dataSource);
  final SupabaseReservationDataSource _dataSource;

  @override
  Future<List<Reservation>> getReservations(
    String merchantId, {
    ReservationStatus? status,
  }) async {
    try {
      return await _dataSource.getReservations(merchantId, status: status);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<Reservation>> getUserReservations(
    String userId, {
    ReservationStatus? status,
  }) async {
    try {
      return await _dataSource.getUserReservations(userId, status: status);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Reservation?> getReservationById(String id) async {
    try {
      return await _dataSource.getReservationById(id);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Reservation> createReservation(Reservation reservation) async {
    try {
      return await _dataSource.createReservation(reservation);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Reservation> updateReservation(
    String id,
    ReservationStatus status,
  ) async {
    try {
      return await _dataSource.updateReservation(id, status);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Reservation> modifyReservation({
    required String reservationId,
    int? partySize,
    DateTime? reservationTime,
    String? specialRequests,
    String? tableNumber,
  }) async {
    try {
      return await _dataSource.modifyReservation(
        reservationId: reservationId,
        partySize: partySize,
        reservationTime: reservationTime,
        specialRequests: specialRequests,
        tableNumber: tableNumber,
      );
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Reservation> cancelReservation(
    String reservationId, {
    String? reason,
  }) async {
    try {
      return await _dataSource.cancelReservation(reservationId, reason: reason);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<ReservationSlot>> getAvailableSlots({
    required String merchantId,
    required DateTime date,
    required int partySize,
    String? branchId,
  }) async {
    try {
      return await _dataSource.getAvailableSlots(
        merchantId: merchantId,
        date: date,
        partySize: partySize,
        branchId: branchId,
      );
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
