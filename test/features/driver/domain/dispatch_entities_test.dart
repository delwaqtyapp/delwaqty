import 'package:flutter_test/flutter_test.dart';

import 'package:delwaqty/features/customer/ride/domain/entities/ride.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/ride_offer.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/driver_stats.dart';

void main() {
  group('RideStatusX', () {
    test('allows legal forward transitions', () {
      expect(RideStatus.searching.canTransitionTo(RideStatus.matched), isTrue);
      expect(RideStatus.matched.canTransitionTo(RideStatus.arrived), isTrue);
      expect(RideStatus.arrived.canTransitionTo(RideStatus.inTrip), isTrue);
      expect(RideStatus.inTrip.canTransitionTo(RideStatus.completed), isTrue);
    });

    test('allows cancellation from every active state', () {
      expect(RideStatus.searching.canTransitionTo(RideStatus.cancelled), isTrue);
      expect(RideStatus.matched.canTransitionTo(RideStatus.cancelled), isTrue);
      expect(RideStatus.arrived.canTransitionTo(RideStatus.cancelled), isTrue);
      expect(RideStatus.inTrip.canTransitionTo(RideStatus.cancelled), isTrue);
    });

    test('rejects illegal transitions', () {
      expect(RideStatus.searching.canTransitionTo(RideStatus.inTrip), isFalse);
      expect(RideStatus.matched.canTransitionTo(RideStatus.completed), isFalse);
      expect(RideStatus.arrived.canTransitionTo(RideStatus.matched), isFalse);
    });

    test('terminal states cannot transition anywhere', () {
      for (final next in RideStatus.values) {
        expect(RideStatus.completed.canTransitionTo(next), isFalse);
        expect(RideStatus.cancelled.canTransitionTo(next), isFalse);
      }
    });

    test('isTerminal and isActive are complementary', () {
      expect(RideStatus.completed.isTerminal, isTrue);
      expect(RideStatus.cancelled.isTerminal, isTrue);
      expect(RideStatus.searching.isActive, isTrue);
      expect(RideStatus.inTrip.isActive, isTrue);
      expect(RideStatus.completed.isActive, isFalse);
    });
  });

  group('RideOffer', () {
    RideOffer build({required DateTime expiresAt}) => RideOffer(
          requestId: 'req',
          rideId: 'ride',
          driverId: 'drv',
          rideType: RideType.economy,
          pickupLatitude: 30.0,
          pickupLongitude: 31.0,
          pickupAddress: 'A',
          dropoffLatitude: 30.1,
          dropoffLongitude: 31.1,
          dropoffAddress: 'B',
          fare: 85.5,
          currency: 'EGP',
          distanceKm: 5.0,
          pickupDistanceKm: 1.2,
          etaMinutes: 4,
          offeredAt: DateTime.now(),
          expiresAt: expiresAt,
        );

    test('estimatedEarnings equals fare', () {
      final offer = build(expiresAt: DateTime.now().add(const Duration(seconds: 20)));
      expect(offer.estimatedEarnings, 85.5);
    });

    test('remaining is positive before expiry', () {
      final offer = build(expiresAt: DateTime.now().add(const Duration(seconds: 15)));
      expect(offer.remaining.inSeconds, greaterThan(0));
      expect(offer.isExpired, isFalse);
    });

    test('expired offer clamps remaining to zero', () {
      final offer = build(expiresAt: DateTime.now().subtract(const Duration(seconds: 5)));
      expect(offer.remaining, Duration.zero);
      expect(offer.isExpired, isTrue);
    });
  });

  group('DriverStats', () {
    test('empty has zeroed values', () {
      const stats = DriverStats.empty;
      expect(stats.todayRides, 0);
      expect(stats.todayEarnings, 0);
      expect(stats.balance, 0);
      expect(stats.totalTrips, 0);
    });
  });
}
