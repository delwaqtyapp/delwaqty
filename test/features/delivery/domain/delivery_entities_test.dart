import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/delivery_order.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/delivery_pricing.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/delivery_request.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/driver_capability.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/merchant_profile.dart';

void main() {
  group('DeliveryOrder', () {
    test('fromJson roundtrip', () {
      final now = DateTime.utc(2026, 7, 18);
      final o = DeliveryOrder(
        id: 'del1',
        serviceType: 'food_delivery',
        merchantId: 'm1',
        merchantName: 'Pizza Place',
        riderId: 'r1',
        driverId: 'd1',
        driverName: 'Ahmed',
        driverPhone: '+20123456789',
        pickupLatitude: 30.0444,
        pickupLongitude: 31.2357,
        pickupAddress: 'Downtown Cairo',
        pickupNotes: 'Ring bell twice',
        dropoffLatitude: 30.0131,
        dropoffLongitude: 31.2089,
        dropoffAddress: 'Nasr City',
        dropoffNotes: 'Leave at door',
        priority: 'express',
        status: 'inTrip',
        fare: 50.0,
        deliveryFee: 25.0,
        currency: 'EGP',
        distance: 12.5,
        estimatedMinutes: 30,
        itemsSummary: '2x Margherita, 1x Cola',
        weightKg: 3.5,
        signatureRequired: true,
        otpRequired: false,
        deliveryProofUrl: 'https://storage.example.com/proof.jpg',
        scheduledAt: now,
        createdAt: now,
        matchedAt: now,
        arrivedAt: now,
        startedAt: now,
      );
      final json = o.toJson();
      final restored = DeliveryOrder.fromJson(json);
      expect(restored.id, 'del1');
      expect(restored.serviceType, 'food_delivery');
      expect(restored.merchantId, 'm1');
      expect(restored.driverName, 'Ahmed');
      expect(restored.pickupLatitude, 30.0444);
      expect(restored.dropoffAddress, 'Nasr City');
      expect(restored.priority, 'express');
      expect(restored.status, 'inTrip');
      expect(restored.fare, 50.0);
      expect(restored.deliveryFee, 25.0);
      expect(restored.distance, 12.5);
      expect(restored.itemsSummary, '2x Margherita, 1x Cola');
      expect(restored.weightKg, 3.5);
      expect(restored.signatureRequired, true);
      expect(restored.otpRequired, false);
      expect(restored.deliveryProofUrl, 'https://storage.example.com/proof.jpg');
    });

    test('default values', () {
      final o = DeliveryOrder(
        id: 'del1',
        serviceType: 'courier',
        pickupLatitude: 30.0,
        pickupLongitude: 31.0,
        dropoffLatitude: 30.1,
        dropoffLongitude: 31.1,
        createdAt: DateTime(2026),
      );
      expect(o.merchantId, isNull);
      expect(o.riderId, isNull);
      expect(o.driverId, isNull);
      expect(o.pickupAddress, '');
      expect(o.dropoffAddress, '');
      expect(o.priority, 'standard');
      expect(o.status, 'searching');
      expect(o.currency, 'EGP');
      expect(o.signatureRequired, false);
      expect(o.otpRequired, true);
      expect(o.deliveryProofUrl, isNull);
      expect(o.scheduledAt, isNull);
    });

    test('all service types', () {
      final types = [
        'ride', 'food_delivery', 'grocery_delivery', 'pharmacy_delivery',
        'marketplace_delivery', 'courier', 'package_delivery',
        'document_delivery', 'flower_delivery', 'retail_delivery',
      ];
      for (final t in types) {
        final o = DeliveryOrder(
          id: 'del1',
          serviceType: t,
          pickupLatitude: 30.0,
          pickupLongitude: 31.0,
          dropoffLatitude: 30.1,
          dropoffLongitude: 31.1,
          createdAt: DateTime(2026),
        );
        expect(o.serviceType, t);
      }
    });

    test('delivery statuses', () {
      final statuses = [
        'searching', 'matched', 'arrived', 'inTrip',
        'completed', 'cancelled',
      ];
      for (final s in statuses) {
        final o = DeliveryOrder(
          id: 'del1',
          serviceType: 'courier',
          pickupLatitude: 30.0,
          pickupLongitude: 31.0,
          dropoffLatitude: 30.1,
          dropoffLongitude: 31.1,
          status: s,
          createdAt: DateTime(2026),
        );
        expect(o.status, s);
      }
    });

    test('priority types', () {
      for (final p in ['standard', 'priority', 'express']) {
        final o = DeliveryOrder(
          id: 'del1',
          serviceType: 'courier',
          pickupLatitude: 30.0,
          pickupLongitude: 31.0,
          dropoffLatitude: 30.1,
          dropoffLongitude: 31.1,
          priority: p,
          createdAt: DateTime(2026),
        );
        expect(o.priority, p);
      }
    });

    test('fromJson with minimal fields', () {
      final json = {
        'id': 'del2',
        'serviceType': 'courier',
        'pickupLatitude': 30.0,
        'pickupLongitude': 31.0,
        'dropoffLatitude': 30.1,
        'dropoffLongitude': 31.1,
        'createdAt': '2026-07-18T00:00:00.000Z',
      };
      final o = DeliveryOrder.fromJson(json);
      expect(o.id, 'del2');
      expect(o.serviceType, 'courier');
      expect(o.signatureRequired, false);
      expect(o.otpRequired, true);
    });
  });

  group('DeliveryPricingModel', () {
    test('calculateFee standard', () {
      const p = DeliveryPricingModel(
        serviceType: 'food_delivery',
        baseFee: 15.0,
        perKm: 5.0,
        perKg: 2.0,
        minimumFee: 25.0,
        priorityMultiplier: 1.5,
        expressMultiplier: 2.0,
      );
      final fee = p.calculateFee(10.0, weightKg: 2.0, priority: 'standard');
      expect(fee, 69.0); // 15 + (5*10) + (2*2) = 69
    });

    test('calculateFee priority multiplier', () {
      const p = DeliveryPricingModel(
        serviceType: 'food_delivery',
        baseFee: 15.0,
        perKm: 5.0,
        perKg: 2.0,
        minimumFee: 25.0,
        priorityMultiplier: 1.5,
        expressMultiplier: 2.0,
      );
      final fee = p.calculateFee(10.0, weightKg: 2.0, priority: 'priority');
      expect(fee, 103.50); // (15 + 50 + 4) * 1.5 = 103.5
    });

    test('calculateFee express multiplier', () {
      const p = DeliveryPricingModel(
        serviceType: 'food_delivery',
        baseFee: 15.0,
        perKm: 5.0,
        perKg: 2.0,
        minimumFee: 25.0,
        priorityMultiplier: 1.5,
        expressMultiplier: 2.0,
      );
      final fee = p.calculateFee(10.0, weightKg: 2.0, priority: 'express');
      expect(fee, 138.0); // (15 + 50 + 4) * 2 = 138
    });

    test('calculateFee enforces minimum', () {
      const p = DeliveryPricingModel(
        serviceType: 'courier',
        baseFee: 10.0,
        perKm: 1.0,
        minimumFee: 25.0,
      );
      final fee = p.calculateFee(1.0);
      expect(fee, 25.0); // 10 + 1 = 11 < 25, so minimum applies
    });

    test('default values', () {
      const p = DeliveryPricingModel(
        serviceType: 'courier',
        baseFee: 10.0,
        perKm: 2.0,
        minimumFee: 15.0,
      );
      expect(p.perKg, 0);
      expect(p.priorityMultiplier, 1.0);
      expect(p.expressMultiplier, 1.5);
      expect(p.currency, 'EGP');
    });
  });

  group('DeliveryRequest', () {
    test('remaining into the future', () {
      final now = DateTime.now();
      final r = DeliveryRequest(
        id: 'req1',
        deliveryId: 'del1',
        driverId: 'd1',
        status: 'pending',
        distanceKm: 3.5,
        etaMinutes: 8,
        offeredAt: now,
        expiresAt: now.add(const Duration(seconds: 25)),
      );
      expect(r.remaining.inSeconds, closeTo(25, 1));
      expect(r.isExpired, false);
    });

    test('expired request', () {
      final r = DeliveryRequest(
        id: 'req2',
        deliveryId: 'del2',
        driverId: 'd2',
        status: 'pending',
        offeredAt: DateTime(2026, 1, 1),
        expiresAt: DateTime(2026, 1, 1),
      );
      expect(r.remaining, Duration.zero);
      expect(r.isExpired, true);
    });

    test('optional fields nullable', () {
      final r = DeliveryRequest(
        id: 'req3',
        deliveryId: 'del3',
        driverId: 'd3',
        status: 'pending',
        offeredAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(seconds: 30)),
      );
      expect(r.distanceKm, isNull);
      expect(r.etaMinutes, isNull);
    });
  });

  group('DriverCapability', () {
    test('fromJson roundtrip', () {
      final c = DriverCapability(
        driverId: 'd1',
        serviceTypes: ['ride', 'food_delivery', 'courier'],
        acceptsDeliveries: true,
        maxDeliveryDistanceKm: 25.0,
        maxWeightKg: 30.0,
      );
      final json = c.toJson();
      final restored = DriverCapability.fromJson(json);
      expect(restored.driverId, 'd1');
      expect(restored.serviceTypes, ['ride', 'food_delivery', 'courier']);
      expect(restored.acceptsDeliveries, true);
      expect(restored.maxDeliveryDistanceKm, 25.0);
      expect(restored.maxWeightKg, 30.0);
    });

    test('default values', () {
      const c = DriverCapability(driverId: 'd1');
      expect(c.serviceTypes, ['ride']);
      expect(c.acceptsDeliveries, false);
      expect(c.maxDeliveryDistanceKm, 15.0);
      expect(c.maxWeightKg, 20.0);
    });
  });

  group('MerchantProfile', () {
    test('fromJson roundtrip', () {
      final now = DateTime.utc(2026, 7, 18);
      final m = MerchantProfile(
        id: 'mp1',
        merchantId: 'm1',
        userId: 'u1',
        serviceTypes: ['food_delivery', 'grocery_delivery'],
        acceptsDirectDispatch: true,
        averagePrepTimeMinutes: 20,
        maxDeliveryRadiusKm: 8.0,
        autoAcceptOrders: true,
        isActive: true,
        createdAt: now,
      );
      final json = m.toJson();
      final restored = MerchantProfile.fromJson(json);
      expect(restored.id, 'mp1');
      expect(restored.merchantId, 'm1');
      expect(restored.userId, 'u1');
      expect(restored.serviceTypes, ['food_delivery', 'grocery_delivery']);
      expect(restored.acceptsDirectDispatch, true);
      expect(restored.averagePrepTimeMinutes, 20);
      expect(restored.maxDeliveryRadiusKm, 8.0);
      expect(restored.autoAcceptOrders, true);
      expect(restored.isActive, true);
    });

    test('default values', () {
      final m = MerchantProfile(
        id: 'mp1',
        merchantId: 'm1',
        userId: 'u1',
        createdAt: DateTime(2026),
      );
      expect(m.serviceTypes, ['food_delivery']);
      expect(m.acceptsDirectDispatch, true);
      expect(m.averagePrepTimeMinutes, 15);
      expect(m.maxDeliveryRadiusKm, 5.0);
      expect(m.autoAcceptOrders, false);
      expect(m.isActive, true);
    });
  });
}
