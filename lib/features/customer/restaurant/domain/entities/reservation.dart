import 'package:freezed_annotation/freezed_annotation.dart';

part 'reservation.freezed.dart';
part 'reservation.g.dart';

enum ReservationStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('confirmed')
  confirmed,
  @JsonValue('seated')
  seated,
  @JsonValue('completed')
  completed,
  @JsonValue('cancelled')
  cancelled,
}

@freezed
abstract class Reservation with _$Reservation {
  const factory Reservation({
    required String id,
    required String userId,
    required String merchantId,
    String? branchId,
    required int partySize,
    required DateTime reservationTime,
    String? specialRequests,
    String? tableNumber,
    @Default(120) int durationMinutes,
    @Default(ReservationStatus.pending) ReservationStatus status,
    required DateTime createdAt,
  }) = _Reservation;

  factory Reservation.fromJson(Map<String, dynamic> json) =>
      _$ReservationFromJson(json);
}

@freezed
abstract class ReservationSlot with _$ReservationSlot {
  const factory ReservationSlot({
    required DateTime time,
    required String tableNumber,
    required int capacity,
    required bool isAvailable,
  }) = _ReservationSlot;

  factory ReservationSlot.fromJson(Map<String, dynamic> json) =>
      _$ReservationSlotFromJson(json);
}
