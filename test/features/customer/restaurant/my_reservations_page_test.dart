import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/reservation.dart';
import 'package:delwaqty/features/customer/restaurant/presentation/pages/my_reservations_page.dart';

void main() {
  group('isReservationCancellable', () {
    test('pending and confirmed are cancellable', () {
      expect(isReservationCancellable(ReservationStatus.pending), isTrue);
      expect(isReservationCancellable(ReservationStatus.confirmed), isTrue);
    });

    test('seated, completed and cancelled are not', () {
      for (final s in [
        ReservationStatus.seated,
        ReservationStatus.completed,
        ReservationStatus.cancelled,
      ]) {
        expect(isReservationCancellable(s), isFalse, reason: s.name);
      }
    });
  });
}
