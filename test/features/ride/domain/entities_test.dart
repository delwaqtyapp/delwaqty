import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/ride/domain/entities/ride.dart';

void main() {
  final now = DateTime(2025, 6, 15);

  group('RideStatus', () {
    test('enum has all values', () {
      expect(RideStatus.values.length, 6);
      expect(RideStatus.searching.name, 'searching');
      expect(RideStatus.matched.name, 'matched');
      expect(RideStatus.arrived.name, 'arrived');
      expect(RideStatus.inTrip.name, 'inTrip');
      expect(RideStatus.completed.name, 'completed');
      expect(RideStatus.cancelled.name, 'cancelled');
    });

    test('isTerminal returns true for completed and cancelled', () {
      expect(RideStatus.completed.isTerminal, isTrue);
      expect(RideStatus.cancelled.isTerminal, isTrue);
      expect(RideStatus.searching.isTerminal, isFalse);
      expect(RideStatus.matched.isTerminal, isFalse);
      expect(RideStatus.arrived.isTerminal, isFalse);
      expect(RideStatus.inTrip.isTerminal, isFalse);
    });

    test('isActive returns true for non-terminal statuses', () {
      expect(RideStatus.searching.isActive, isTrue);
      expect(RideStatus.matched.isActive, isTrue);
      expect(RideStatus.arrived.isActive, isTrue);
      expect(RideStatus.inTrip.isActive, isTrue);
      expect(RideStatus.completed.isActive, isFalse);
      expect(RideStatus.cancelled.isActive, isFalse);
    });

    test('canTransitionTo returns correct transitions', () {
      expect(RideStatus.searching.canTransitionTo(RideStatus.matched), isTrue);
      expect(RideStatus.searching.canTransitionTo(RideStatus.cancelled), isTrue);
      expect(RideStatus.searching.canTransitionTo(RideStatus.inTrip), isFalse);

      expect(RideStatus.matched.canTransitionTo(RideStatus.arrived), isTrue);
      expect(RideStatus.matched.canTransitionTo(RideStatus.cancelled), isTrue);
      expect(RideStatus.matched.canTransitionTo(RideStatus.completed), isFalse);

      expect(RideStatus.arrived.canTransitionTo(RideStatus.inTrip), isTrue);
      expect(RideStatus.arrived.canTransitionTo(RideStatus.cancelled), isTrue);
      expect(RideStatus.arrived.canTransitionTo(RideStatus.completed), isFalse);

      expect(RideStatus.inTrip.canTransitionTo(RideStatus.completed), isTrue);
      expect(RideStatus.inTrip.canTransitionTo(RideStatus.cancelled), isTrue);
      expect(RideStatus.inTrip.canTransitionTo(RideStatus.searching), isFalse);

      expect(RideStatus.completed.canTransitionTo(RideStatus.cancelled), isFalse);
      expect(RideStatus.cancelled.canTransitionTo(RideStatus.matched), isFalse);
    });
  });

  group('RideType', () {
    test('enum has all values', () {
      expect(RideType.values.length, 6);
      expect(RideType.economy.name, 'economy');
      expect(RideType.comfort.name, 'comfort');
      expect(RideType.premium.name, 'premium');
      expect(RideType.xl.name, 'xl');
      expect(RideType.motorbike.name, 'motorbike');
      expect(RideType.taxi.name, 'taxi');
    });

    test('passengerCapacity returns correct values', () {
      expect(RideType.economy.passengerCapacity, 4);
      expect(RideType.comfort.passengerCapacity, 4);
      expect(RideType.premium.passengerCapacity, 4);
      expect(RideType.xl.passengerCapacity, 6);
      expect(RideType.motorbike.passengerCapacity, 1);
      expect(RideType.taxi.passengerCapacity, 4);
    });

    test('luggageCapacity returns correct values', () {
      expect(RideType.economy.luggageCapacity, 2);
      expect(RideType.comfort.luggageCapacity, 2);
      expect(RideType.premium.luggageCapacity, 3);
      expect(RideType.xl.luggageCapacity, 4);
      expect(RideType.motorbike.luggageCapacity, 0);
      expect(RideType.taxi.luggageCapacity, 2);
    });
  });

  group('Ride', () {
    test('fromJson creates Ride from JSON', () {
      final json = {
        'id': 'r1',
        'riderId': 'u1',
        'driverId': 'd1',
        'driverName': 'Mohamed',
        'driverPhone': '+20123456789',
        'driverPhoto': 'https://example.com/photo.jpg',
        'vehicleType': 'Toyota',
        'vehiclePlate': 'ABC 123',
        'vehicleColor': 'White',
        'pickupLatitude': 30.0444,
        'pickupLongitude': 31.2357,
        'pickupAddress': 'Cairo Tower',
        'dropoffLatitude': 30.0131,
        'dropoffLongitude': 31.2089,
        'dropoffAddress': 'Cairo Airport',
        'rideType': 'economy',
        'status': 'searching',
        'fare': 50.0,
        'baseFare': 10.0,
        'distanceFare': 30.0,
        'timeFare': 10.0,
        'surgeMultiplier': 1.5,
        'discountAmount': 5.0,
        'promoCode': 'SAVE10',
        'paymentMethod': 'cash',
        'paymentStatus': 'pending',
        'pickupOtp': '1234',
        'currency': 'EGP',
        'distance': 12.5,
        'estimatedMinutes': 25,
        'driverLatitude': 30.0440,
        'driverLongitude': 31.2360,
        'createdAt': now.toIso8601String(),
        'matchedAt': null,
        'arrivedAt': null,
        'startedAt': null,
        'completedAt': null,
        'cancelledAt': null,
        'cancellationReason': null,
        'isSharedTrip': false,
        'emergencyContactId': null,
      };

      final ride = Ride.fromJson(json);
      expect(ride.id, 'r1');
      expect(ride.riderId, 'u1');
      expect(ride.driverId, 'd1');
      expect(ride.driverName, 'Mohamed');
      expect(ride.pickupLatitude, 30.0444);
      expect(ride.pickupLongitude, 31.2357);
      expect(ride.pickupAddress, 'Cairo Tower');
      expect(ride.dropoffLatitude, 30.0131);
      expect(ride.dropoffLongitude, 31.2089);
      expect(ride.dropoffAddress, 'Cairo Airport');
      expect(ride.rideType, RideType.economy);
      expect(ride.status, RideStatus.searching);
      expect(ride.fare, 50.0);
      expect(ride.baseFare, 10.0);
      expect(ride.distanceFare, 30.0);
      expect(ride.timeFare, 10.0);
      expect(ride.surgeMultiplier, 1.5);
      expect(ride.discountAmount, 5.0);
      expect(ride.promoCode, 'SAVE10');
      expect(ride.paymentMethod, 'cash');
      expect(ride.paymentStatus, 'pending');
      expect(ride.pickupOtp, '1234');
      expect(ride.currency, 'EGP');
      expect(ride.distance, 12.5);
      expect(ride.estimatedMinutes, 25);
      expect(ride.isSharedTrip, false);
    });

    test('toJson serializes correctly', () {
      final ride = Ride(
        id: 'r1',
        riderId: 'u1',
        pickupLatitude: 30.0444,
        pickupLongitude: 31.2357,
        pickupAddress: 'Cairo Tower',
        dropoffLatitude: 30.0131,
        dropoffLongitude: 31.2089,
        dropoffAddress: 'Cairo Airport',
        createdAt: now,
      );

      final json = ride.toJson();
      expect(json['id'], 'r1');
      expect(json['riderId'], 'u1');
      expect(json['rideType'], 'economy');
      expect(json['status'], 'searching');
      expect(json['surgeMultiplier'], 1.0);
      expect(json['discountAmount'], 0.0);
      expect(json['paymentMethod'], 'cash');
      expect(json['paymentStatus'], 'pending');
      expect(json['currency'], 'EGP');
      expect(json['isSharedTrip'], false);
    });

    test('fromJson roundtrip preserves data', () {
      final original = Ride(
        id: 'r1',
        riderId: 'u1',
        driverId: 'd1',
        driverName: 'Mohamed',
        pickupLatitude: 30.0444,
        pickupLongitude: 31.2357,
        pickupAddress: 'Cairo Tower',
        dropoffLatitude: 30.0131,
        dropoffLongitude: 31.2089,
        dropoffAddress: 'Cairo Airport',
        rideType: RideType.comfort,
        status: RideStatus.inTrip,
        fare: 75.0,
        baseFare: 15.0,
        distanceFare: 45.0,
        timeFare: 15.0,
        surgeMultiplier: 1.5,
        discountAmount: 10.0,
        promoCode: 'RIDE20',
        paymentMethod: 'wallet',
        paymentStatus: 'paid',
        pickupOtp: '5678',
        currency: 'EGP',
        distance: 20.0,
        estimatedMinutes: 35,
        isSharedTrip: true,
        createdAt: now,
      );

      final restored = Ride.fromJson(original.toJson());
      expect(restored, original);
    });

    test('equality works correctly', () {
      final a = Ride(
        id: 'r1',
        riderId: 'u1',
        pickupLatitude: 30.0444,
        pickupLongitude: 31.2357,
        pickupAddress: 'Cairo Tower',
        dropoffLatitude: 30.0131,
        dropoffLongitude: 31.2089,
        dropoffAddress: 'Cairo Airport',
        createdAt: now,
      );
      final b = Ride(
        id: 'r1',
        riderId: 'u1',
        pickupLatitude: 30.0444,
        pickupLongitude: 31.2357,
        pickupAddress: 'Cairo Tower',
        dropoffLatitude: 30.0131,
        dropoffLongitude: 31.2089,
        dropoffAddress: 'Cairo Airport',
        createdAt: now,
      );
      final c = Ride(
        id: 'r2',
        riderId: 'u2',
        pickupLatitude: 0,
        pickupLongitude: 0,
        pickupAddress: 'Other',
        dropoffLatitude: 0,
        dropoffLongitude: 0,
        dropoffAddress: 'Other',
        createdAt: now,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith creates modified copy', () {
      final ride = Ride(
        id: 'r1',
        riderId: 'u1',
        pickupLatitude: 30.0444,
        pickupLongitude: 31.2357,
        pickupAddress: 'Cairo Tower',
        dropoffLatitude: 30.0131,
        dropoffLongitude: 31.2089,
        dropoffAddress: 'Cairo Airport',
        createdAt: now,
      );

      final updated = ride.copyWith(
        status: RideStatus.matched,
        driverId: 'd1',
        driverName: 'Ali',
        fare: 60.0,
      );
      expect(updated.status, RideStatus.matched);
      expect(updated.driverId, 'd1');
      expect(updated.driverName, 'Ali');
      expect(updated.fare, 60.0);
      expect(updated.id, 'r1');
      expect(ride.status, RideStatus.searching);
    });

    test('defaults are applied correctly', () {
      final ride = Ride(
        id: 'r1',
        riderId: 'u1',
        pickupLatitude: 30.0444,
        pickupLongitude: 31.2357,
        pickupAddress: 'Cairo Tower',
        dropoffLatitude: 30.0131,
        dropoffLongitude: 31.2089,
        dropoffAddress: 'Cairo Airport',
        createdAt: now,
      );

      expect(ride.rideType, RideType.economy);
      expect(ride.status, RideStatus.searching);
      expect(ride.surgeMultiplier, 1.0);
      expect(ride.discountAmount, 0.0);
      expect(ride.paymentMethod, 'cash');
      expect(ride.paymentStatus, 'pending');
      expect(ride.currency, 'EGP');
      expect(ride.isSharedTrip, false);
      expect(ride.driverId, isNull);
      expect(ride.driverName, isNull);
      expect(ride.fare, isNull);
      expect(ride.baseFare, isNull);
      expect(ride.promoCode, isNull);
    });
  });
}
