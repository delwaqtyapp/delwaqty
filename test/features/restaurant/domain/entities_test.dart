import 'package:delwaqty/features/customer/restaurant/domain/entities/branch.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/delivery_zone.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/offer.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/order_tracking.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/product_inventory.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/product_modifier.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/reservation.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/restaurant_settings.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/working_hours.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2025, 6, 15);

  group('Branch', () {
    final json = <String, dynamic>{
      'id': 'b1',
      'merchantId': 'm1',
      'name': 'Main Branch',
      'address': '123 Main St',
      'latitude': 30.0,
      'longitude': 31.0,
      'phone': '+1234567890',
      'isActive': true,
      'isPrimary': true,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    test('fromJson creates Branch from JSON', () {
      final branch = Branch.fromJson(json);
      expect(branch.id, 'b1');
      expect(branch.merchantId, 'm1');
      expect(branch.name, 'Main Branch');
      expect(branch.address, '123 Main St');
      expect(branch.latitude, 30.0);
      expect(branch.longitude, 31.0);
      expect(branch.phone, '+1234567890');
      expect(branch.isActive, true);
      expect(branch.isPrimary, true);
      expect(branch.createdAt, now);
      expect(branch.updatedAt, now);
    });

    test('toJson serializes correctly', () {
      final branch = Branch(
        id: 'b1',
        merchantId: 'm1',
        name: 'Main Branch',
        address: '123 Main St',
        latitude: 30.0,
        longitude: 31.0,
        phone: '+1234567890',
        isPrimary: true,
        createdAt: now,
      );
      final json = branch.toJson();
      expect(json['id'], 'b1');
      expect(json['merchantId'], 'm1');
      expect(json['name'], 'Main Branch');
      expect(json['address'], '123 Main St');
      expect(json['latitude'], 30.0);
      expect(json['longitude'], 31.0);
      expect(json['phone'], '+1234567890');
      expect(json['isActive'], true);
      expect(json['isPrimary'], true);
    });

    test('fromJson roundtrip preserves data', () {
      final original = Branch.fromJson(json);
      final restored = Branch.fromJson(original.toJson());
      expect(restored, original);
    });

    test('defaults are applied correctly', () {
      final branch = Branch(
        id: 'b1',
        merchantId: 'm1',
        name: 'Test',
        createdAt: now,
      );
      expect(branch.isActive, true);
      expect(branch.isPrimary, false);
      expect(branch.address, isNull);
      expect(branch.latitude, isNull);
      expect(branch.longitude, isNull);
      expect(branch.phone, isNull);
      expect(branch.updatedAt, isNull);
    });

    test('equality works correctly', () {
      final a = Branch(id: 'b1', merchantId: 'm1', name: 'A', createdAt: now);
      final b = Branch(id: 'b1', merchantId: 'm1', name: 'A', createdAt: now);
      final c = Branch(id: 'b2', merchantId: 'm1', name: 'A', createdAt: now);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith creates modified copy', () {
      final branch = Branch(
        id: 'b1',
        merchantId: 'm1',
        name: 'Original',
        createdAt: now,
      );
      final modified = branch.copyWith(name: 'Modified', isPrimary: true);
      expect(modified.name, 'Modified');
      expect(modified.isPrimary, true);
      expect(modified.id, 'b1');
      expect(branch.name, 'Original');
    });
  });

  group('DeliveryZone', () {
    final json = <String, dynamic>{
      'id': 'dz1',
      'merchantId': 'm1',
      'name': 'Zone A',
      'radiusKm': 5.0,
      'deliveryFee': 3.5,
      'minimumOrder': 10.0,
      'estimatedMinutes': 25,
      'isActive': true,
      'createdAt': now.toIso8601String(),
    };

    test('fromJson creates DeliveryZone from JSON', () {
      final zone = DeliveryZone.fromJson(json);
      expect(zone.id, 'dz1');
      expect(zone.merchantId, 'm1');
      expect(zone.name, 'Zone A');
      expect(zone.radiusKm, 5.0);
      expect(zone.deliveryFee, 3.5);
      expect(zone.minimumOrder, 10.0);
      expect(zone.estimatedMinutes, 25);
      expect(zone.isActive, true);
      expect(zone.createdAt, now);
    });

    test('toJson serializes correctly', () {
      final zone = DeliveryZone(
        id: 'dz1',
        merchantId: 'm1',
        name: 'Zone A',
        radiusKm: 5.0,
        createdAt: now,
      );
      final json = zone.toJson();
      expect(json['id'], 'dz1');
      expect(json['merchantId'], 'm1');
      expect(json['name'], 'Zone A');
      expect(json['radiusKm'], 5.0);
    });

    test('fromJson roundtrip preserves data', () {
      final original = DeliveryZone.fromJson(json);
      final restored = DeliveryZone.fromJson(original.toJson());
      expect(restored, original);
    });

    test('defaults are applied correctly', () {
      final zone = DeliveryZone(
        id: 'dz1',
        merchantId: 'm1',
        name: 'Zone',
        radiusKm: 3.0,
        createdAt: now,
      );
      expect(zone.deliveryFee, 0.0);
      expect(zone.minimumOrder, 0.0);
      expect(zone.estimatedMinutes, 30);
      expect(zone.isActive, true);
    });

    test('equality works correctly', () {
      final a = DeliveryZone(
        id: 'dz1', merchantId: 'm1', name: 'A', radiusKm: 5.0, createdAt: now,
      );
      final b = DeliveryZone(
        id: 'dz1', merchantId: 'm1', name: 'A', radiusKm: 5.0, createdAt: now,
      );
      final c = DeliveryZone(
        id: 'dz2', merchantId: 'm1', name: 'A', radiusKm: 5.0, createdAt: now,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith creates modified copy', () {
      final zone = DeliveryZone(
        id: 'dz1', merchantId: 'm1', name: 'Original', radiusKm: 5.0, createdAt: now,
      );
      final modified = zone.copyWith(name: 'Modified', radiusKm: 10.0);
      expect(modified.name, 'Modified');
      expect(modified.radiusKm, 10.0);
      expect(modified.id, 'dz1');
      expect(zone.name, 'Original');
    });
  });

  group('Offer', () {
    final json = <String, dynamic>{
      'id': 'o1',
      'merchantId': 'm1',
      'branchId': 'b1',
      'categoryId': 'c1',
      'title': '20% Off',
      'description': 'All items',
      'discountType': 'percentage',
      'discountValue': 20.0,
      'minimumOrder': 15.0,
      'maximumDiscount': 50.0,
      'productIds': ['p1', 'p2'],
      'isActive': true,
      'isAutomatic': false,
      'startsAt': now.toIso8601String(),
      'expiresAt': now.add(const Duration(days: 7)).toIso8601String(),
      'createdAt': now.toIso8601String(),
    };

    test('fromJson creates Offer from JSON', () {
      final offer = Offer.fromJson(json);
      expect(offer.id, 'o1');
      expect(offer.merchantId, 'm1');
      expect(offer.branchId, 'b1');
      expect(offer.categoryId, 'c1');
      expect(offer.title, '20% Off');
      expect(offer.description, 'All items');
      expect(offer.discountType, 'percentage');
      expect(offer.discountValue, 20.0);
      expect(offer.minimumOrder, 15.0);
      expect(offer.maximumDiscount, 50.0);
      expect(offer.productIds, ['p1', 'p2']);
      expect(offer.isActive, true);
      expect(offer.isAutomatic, false);
      expect(offer.startsAt, now);
      expect(offer.expiresAt, now.add(const Duration(days: 7)));
      expect(offer.createdAt, now);
    });

    test('toJson serializes correctly', () {
      final offer = Offer(
        id: 'o1', merchantId: 'm1', title: '20% Off', discountValue: 20.0, createdAt: now,
      );
      final json = offer.toJson();
      expect(json['id'], 'o1');
      expect(json['merchantId'], 'm1');
      expect(json['title'], '20% Off');
      expect(json['discountValue'], 20.0);
    });

    test('fromJson roundtrip preserves data', () {
      final original = Offer.fromJson(json);
      final restored = Offer.fromJson(original.toJson());
      expect(restored, original);
    });

    test('defaults are applied correctly', () {
      final offer = Offer(
        id: 'o1', merchantId: 'm1', title: 'Test', discountValue: 10.0, createdAt: now,
      );
      expect(offer.discountType, 'percentage');
      expect(offer.minimumOrder, 0.0);
      expect(offer.productIds, isEmpty);
      expect(offer.isActive, true);
      expect(offer.isAutomatic, false);
      expect(offer.branchId, isNull);
      expect(offer.categoryId, isNull);
      expect(offer.maximumDiscount, isNull);
      expect(offer.startsAt, isNull);
      expect(offer.expiresAt, isNull);
    });

    test('equality works correctly', () {
      final a = Offer(id: 'o1', merchantId: 'm1', title: 'A', discountValue: 10.0, createdAt: now);
      final b = Offer(id: 'o1', merchantId: 'm1', title: 'A', discountValue: 10.0, createdAt: now);
      final c = Offer(id: 'o2', merchantId: 'm1', title: 'A', discountValue: 10.0, createdAt: now);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith creates modified copy', () {
      final offer = Offer(
        id: 'o1', merchantId: 'm1', title: 'Original', discountValue: 10.0, createdAt: now,
      );
      final modified = offer.copyWith(title: 'Modified', discountValue: 25.0);
      expect(modified.title, 'Modified');
      expect(modified.discountValue, 25.0);
      expect(modified.id, 'o1');
      expect(offer.title, 'Original');
    });
  });

  group('OrderTracking', () {
    final json = <String, dynamic>{
      'id': 'ot1',
      'orderId': 'order1',
      'status': 'preparing',
      'estimatedMinutes': 15,
      'notes': 'Extra sauce',
      'createdAt': now.toIso8601String(),
    };

    test('fromJson creates OrderTracking from JSON', () {
      final tracking = OrderTracking.fromJson(json);
      expect(tracking.id, 'ot1');
      expect(tracking.orderId, 'order1');
      expect(tracking.status, 'preparing');
      expect(tracking.estimatedMinutes, 15);
      expect(tracking.notes, 'Extra sauce');
      expect(tracking.createdAt, now);
    });

    test('toJson serializes correctly', () {
      final tracking = OrderTracking(
        id: 'ot1', orderId: 'order1', status: 'preparing', createdAt: now,
      );
      final json = tracking.toJson();
      expect(json['id'], 'ot1');
      expect(json['orderId'], 'order1');
      expect(json['status'], 'preparing');
    });

    test('fromJson roundtrip preserves data', () {
      final original = OrderTracking.fromJson(json);
      final restored = OrderTracking.fromJson(original.toJson());
      expect(restored, original);
    });

    test('defaults are applied correctly', () {
      final tracking = OrderTracking(
        id: 'ot1', orderId: 'order1', status: 'pending', createdAt: now,
      );
      expect(tracking.estimatedMinutes, isNull);
      expect(tracking.notes, isNull);
    });

    test('equality works correctly', () {
      final a = OrderTracking(id: 'ot1', orderId: 'order1', status: 'preparing', createdAt: now);
      final b = OrderTracking(id: 'ot1', orderId: 'order1', status: 'preparing', createdAt: now);
      final c = OrderTracking(id: 'ot2', orderId: 'order1', status: 'preparing', createdAt: now);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith creates modified copy', () {
      final tracking = OrderTracking(
        id: 'ot1', orderId: 'order1', status: 'pending', createdAt: now,
      );
      final modified = tracking.copyWith(status: 'delivered');
      expect(modified.status, 'delivered');
      expect(modified.id, 'ot1');
      expect(tracking.status, 'pending');
    });
  });

  group('ProductInventory', () {
    final json = <String, dynamic>{
      'id': 'pi1',
      'productId': 'p1',
      'merchantId': 'm1',
      'stockQuantity': 50,
      'reservedQuantity': 5,
      'lowStockThreshold': 10,
      'isInStock': true,
      'updatedAt': now.toIso8601String(),
    };

    test('fromJson creates ProductInventory from JSON', () {
      final inv = ProductInventory.fromJson(json);
      expect(inv.id, 'pi1');
      expect(inv.productId, 'p1');
      expect(inv.merchantId, 'm1');
      expect(inv.stockQuantity, 50);
      expect(inv.reservedQuantity, 5);
      expect(inv.lowStockThreshold, 10);
      expect(inv.isInStock, true);
      expect(inv.updatedAt, now);
    });

    test('toJson serializes correctly', () {
      const inv = ProductInventory(id: 'pi1', productId: 'p1', merchantId: 'm1');
      final json = inv.toJson();
      expect(json['id'], 'pi1');
      expect(json['productId'], 'p1');
      expect(json['merchantId'], 'm1');
    });

    test('fromJson roundtrip preserves data', () {
      final original = ProductInventory.fromJson(json);
      final restored = ProductInventory.fromJson(original.toJson());
      expect(restored, original);
    });

    test('defaults are applied correctly', () {
      const inv = ProductInventory(id: 'pi1', productId: 'p1', merchantId: 'm1');
      expect(inv.stockQuantity, 0);
      expect(inv.reservedQuantity, 0);
      expect(inv.lowStockThreshold, 10);
      expect(inv.isInStock, true);
      expect(inv.updatedAt, isNull);
    });

    test('equality works correctly', () {
      const a = ProductInventory(id: 'pi1', productId: 'p1', merchantId: 'm1');
      const b = ProductInventory(id: 'pi1', productId: 'p1', merchantId: 'm1');
      const c = ProductInventory(id: 'pi2', productId: 'p1', merchantId: 'm1');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith creates modified copy', () {
      const inv = ProductInventory(id: 'pi1', productId: 'p1', merchantId: 'm1');
      final modified = inv.copyWith(stockQuantity: 100, isInStock: true);
      expect(modified.stockQuantity, 100);
      expect(modified.isInStock, true);
      expect(modified.id, 'pi1');
    });
  });

  group('ProductModifier', () {
    final json = <String, dynamic>{
      'id': 'pm1',
      'productId': 'p1',
      'name': 'Extra Cheese',
      'description': 'Add extra cheese',
      'priceAdjustment': 2.5,
      'isAvailable': true,
      'sortOrder': 1,
      'createdAt': now.toIso8601String(),
    };

    test('fromJson creates ProductModifier from JSON', () {
      final mod = ProductModifier.fromJson(json);
      expect(mod.id, 'pm1');
      expect(mod.productId, 'p1');
      expect(mod.name, 'Extra Cheese');
      expect(mod.description, 'Add extra cheese');
      expect(mod.priceAdjustment, 2.5);
      expect(mod.isAvailable, true);
      expect(mod.sortOrder, 1);
      expect(mod.createdAt, now);
    });

    test('toJson serializes correctly', () {
      final mod = ProductModifier(
        id: 'pm1', productId: 'p1', name: 'Extra Cheese', createdAt: now,
      );
      final json = mod.toJson();
      expect(json['id'], 'pm1');
      expect(json['productId'], 'p1');
      expect(json['name'], 'Extra Cheese');
    });

    test('fromJson roundtrip preserves data', () {
      final original = ProductModifier.fromJson(json);
      final restored = ProductModifier.fromJson(original.toJson());
      expect(restored, original);
    });

    test('defaults are applied correctly', () {
      final mod = ProductModifier(
        id: 'pm1', productId: 'p1', name: 'Test', createdAt: now,
      );
      expect(mod.description, isNull);
      expect(mod.priceAdjustment, 0.0);
      expect(mod.isAvailable, true);
      expect(mod.sortOrder, 0);
    });

    test('equality works correctly', () {
      final a = ProductModifier(id: 'pm1', productId: 'p1', name: 'A', createdAt: now);
      final b = ProductModifier(id: 'pm1', productId: 'p1', name: 'A', createdAt: now);
      final c = ProductModifier(id: 'pm2', productId: 'p1', name: 'A', createdAt: now);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith creates modified copy', () {
      final mod = ProductModifier(
        id: 'pm1', productId: 'p1', name: 'Original', createdAt: now,
      );
      final modified = mod.copyWith(name: 'Modified', priceAdjustment: 3.0);
      expect(modified.name, 'Modified');
      expect(modified.priceAdjustment, 3.0);
      expect(modified.id, 'pm1');
      expect(mod.name, 'Original');
    });
  });

  group('Reservation', () {
    final json = <String, dynamic>{
      'id': 'r1',
      'userId': 'u1',
      'merchantId': 'm1',
      'branchId': 'b1',
      'partySize': 4,
      'reservationTime': now.toIso8601String(),
      'specialRequests': 'Window seat',
      'tableNumber': 'T5',
      'durationMinutes': 90,
      'status': 'confirmed',
      'createdAt': now.toIso8601String(),
    };

    test('fromJson creates Reservation from JSON', () {
      final res = Reservation.fromJson(json);
      expect(res.id, 'r1');
      expect(res.userId, 'u1');
      expect(res.merchantId, 'm1');
      expect(res.branchId, 'b1');
      expect(res.partySize, 4);
      expect(res.reservationTime, now);
      expect(res.specialRequests, 'Window seat');
      expect(res.tableNumber, 'T5');
      expect(res.durationMinutes, 90);
      expect(res.status, ReservationStatus.confirmed);
      expect(res.createdAt, now);
    });

    test('toJson serializes correctly', () {
      final res = Reservation(
        id: 'r1', userId: 'u1', merchantId: 'm1',
        partySize: 2, reservationTime: now, createdAt: now,
      );
      final json = res.toJson();
      expect(json['id'], 'r1');
      expect(json['userId'], 'u1');
      expect(json['partySize'], 2);
    });

    test('fromJson roundtrip preserves data', () {
      final original = Reservation.fromJson(json);
      final restored = Reservation.fromJson(original.toJson());
      expect(restored, original);
    });

    test('defaults are applied correctly', () {
      final res = Reservation(
        id: 'r1', userId: 'u1', merchantId: 'm1',
        partySize: 2, reservationTime: now, createdAt: now,
      );
      expect(res.branchId, isNull);
      expect(res.specialRequests, isNull);
      expect(res.tableNumber, isNull);
      expect(res.durationMinutes, 120);
      expect(res.status, ReservationStatus.pending);
    });

    test('equality works correctly', () {
      final a = Reservation(
        id: 'r1', userId: 'u1', merchantId: 'm1',
        partySize: 2, reservationTime: now, createdAt: now,
      );
      final b = Reservation(
        id: 'r1', userId: 'u1', merchantId: 'm1',
        partySize: 2, reservationTime: now, createdAt: now,
      );
      final c = Reservation(
        id: 'r2', userId: 'u1', merchantId: 'm1',
        partySize: 2, reservationTime: now, createdAt: now,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith creates modified copy', () {
      final res = Reservation(
        id: 'r1', userId: 'u1', merchantId: 'm1',
        partySize: 2, reservationTime: now, createdAt: now,
      );
      final modified = res.copyWith(
        partySize: 6, status: ReservationStatus.seated,
      );
      expect(modified.partySize, 6);
      expect(modified.status, ReservationStatus.seated);
      expect(modified.id, 'r1');
      expect(res.partySize, 2);
    });

    test('ReservationStatus enum has all values', () {
      expect(ReservationStatus.values.length, 5);
      expect(ReservationStatus.values[0], ReservationStatus.pending);
      expect(ReservationStatus.values[1], ReservationStatus.confirmed);
      expect(ReservationStatus.values[2], ReservationStatus.seated);
      expect(ReservationStatus.values[3], ReservationStatus.completed);
      expect(ReservationStatus.values[4], ReservationStatus.cancelled);
    });
  });

  group('ReservationSlot', () {
    final json = <String, dynamic>{
      'time': now.toIso8601String(),
      'tableNumber': 'T1',
      'capacity': 4,
      'isAvailable': true,
    };

    test('fromJson creates ReservationSlot from JSON', () {
      final slot = ReservationSlot.fromJson(json);
      expect(slot.time, now);
      expect(slot.tableNumber, 'T1');
      expect(slot.capacity, 4);
      expect(slot.isAvailable, true);
    });

    test('toJson serializes correctly', () {
      final slot = ReservationSlot(
        time: now, tableNumber: 'T1', capacity: 4, isAvailable: false,
      );
      final json = slot.toJson();
      expect(json['tableNumber'], 'T1');
      expect(json['capacity'], 4);
      expect(json['isAvailable'], false);
    });

    test('fromJson roundtrip preserves data', () {
      final original = ReservationSlot.fromJson(json);
      final restored = ReservationSlot.fromJson(original.toJson());
      expect(restored, original);
    });

    test('equality works correctly', () {
      final a = ReservationSlot(time: now, tableNumber: 'T1', capacity: 4, isAvailable: true);
      final b = ReservationSlot(time: now, tableNumber: 'T1', capacity: 4, isAvailable: true);
      final c = ReservationSlot(time: now, tableNumber: 'T2', capacity: 4, isAvailable: true);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('RestaurantSettings', () {
    final json = <String, dynamic>{
      'id': 'rs1',
      'merchantId': 'm1',
      'acceptsReservations': true,
      'hasDineIn': true,
      'hasTakeaway': true,
      'hasDelivery': false,
      'averagePrepTime': 20,
      'maxOrdersPerHour': 30,
      'autoAcceptOrders': true,
      'printerEnabled': true,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    test('fromJson creates RestaurantSettings from JSON', () {
      final settings = RestaurantSettings.fromJson(json);
      expect(settings.id, 'rs1');
      expect(settings.merchantId, 'm1');
      expect(settings.acceptsReservations, true);
      expect(settings.hasDineIn, true);
      expect(settings.hasTakeaway, true);
      expect(settings.hasDelivery, false);
      expect(settings.averagePrepTime, 20);
      expect(settings.maxOrdersPerHour, 30);
      expect(settings.autoAcceptOrders, true);
      expect(settings.printerEnabled, true);
      expect(settings.createdAt, now);
      expect(settings.updatedAt, now);
    });

    test('toJson serializes correctly', () {
      final settings = RestaurantSettings(id: 'rs1', merchantId: 'm1', createdAt: now);
      final json = settings.toJson();
      expect(json['id'], 'rs1');
      expect(json['merchantId'], 'm1');
    });

    test('fromJson roundtrip preserves data', () {
      final original = RestaurantSettings.fromJson(json);
      final restored = RestaurantSettings.fromJson(original.toJson());
      expect(restored, original);
    });

    test('defaults are applied correctly', () {
      final settings = RestaurantSettings(id: 'rs1', merchantId: 'm1', createdAt: now);
      expect(settings.acceptsReservations, false);
      expect(settings.hasDineIn, true);
      expect(settings.hasTakeaway, true);
      expect(settings.hasDelivery, true);
      expect(settings.averagePrepTime, 15);
      expect(settings.maxOrdersPerHour, 20);
      expect(settings.autoAcceptOrders, false);
      expect(settings.printerEnabled, false);
      expect(settings.updatedAt, isNull);
    });

    test('equality works correctly', () {
      final a = RestaurantSettings(id: 'rs1', merchantId: 'm1', createdAt: now);
      final b = RestaurantSettings(id: 'rs1', merchantId: 'm1', createdAt: now);
      final c = RestaurantSettings(id: 'rs2', merchantId: 'm1', createdAt: now);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith creates modified copy', () {
      final settings = RestaurantSettings(id: 'rs1', merchantId: 'm1', createdAt: now);
      final modified = settings.copyWith(hasDelivery: false, averagePrepTime: 30);
      expect(modified.hasDelivery, false);
      expect(modified.averagePrepTime, 30);
      expect(modified.id, 'rs1');
      expect(settings.hasDelivery, true);
    });
  });

  group('WorkingHours', () {
    final json = <String, dynamic>{
      'id': 'wh1',
      'merchantId': 'm1',
      'branchId': 'b1',
      'dayOfWeek': 1,
      'openTime': '09:00',
      'closeTime': '22:00',
      'isClosed': false,
      'createdAt': now.toIso8601String(),
    };

    test('fromJson creates WorkingHours from JSON', () {
      final hours = WorkingHours.fromJson(json);
      expect(hours.id, 'wh1');
      expect(hours.merchantId, 'm1');
      expect(hours.branchId, 'b1');
      expect(hours.dayOfWeek, 1);
      expect(hours.openTime, '09:00');
      expect(hours.closeTime, '22:00');
      expect(hours.isClosed, false);
      expect(hours.createdAt, now);
    });

    test('toJson serializes correctly', () {
      final hours = WorkingHours(
        id: 'wh1', merchantId: 'm1', dayOfWeek: 1,
        openTime: '09:00', closeTime: '22:00', createdAt: now,
      );
      final json = hours.toJson();
      expect(json['id'], 'wh1');
      expect(json['merchantId'], 'm1');
      expect(json['dayOfWeek'], 1);
      expect(json['openTime'], '09:00');
      expect(json['closeTime'], '22:00');
    });

    test('fromJson roundtrip preserves data', () {
      final original = WorkingHours.fromJson(json);
      final restored = WorkingHours.fromJson(original.toJson());
      expect(restored, original);
    });

    test('defaults are applied correctly', () {
      final hours = WorkingHours(
        id: 'wh1', merchantId: 'm1', dayOfWeek: 0,
        openTime: '00:00', closeTime: '00:00', createdAt: now,
      );
      expect(hours.isClosed, false);
      expect(hours.branchId, isNull);
    });

    test('equality works correctly', () {
      final a = WorkingHours(
        id: 'wh1', merchantId: 'm1', dayOfWeek: 1,
        openTime: '09:00', closeTime: '22:00', createdAt: now,
      );
      final b = WorkingHours(
        id: 'wh1', merchantId: 'm1', dayOfWeek: 1,
        openTime: '09:00', closeTime: '22:00', createdAt: now,
      );
      final c = WorkingHours(
        id: 'wh2', merchantId: 'm1', dayOfWeek: 2,
        openTime: '09:00', closeTime: '22:00', createdAt: now,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith creates modified copy', () {
      final hours = WorkingHours(
        id: 'wh1', merchantId: 'm1', dayOfWeek: 1,
        openTime: '09:00', closeTime: '22:00', createdAt: now,
      );
      final modified = hours.copyWith(isClosed: true, closeTime: '18:00');
      expect(modified.isClosed, true);
      expect(modified.closeTime, '18:00');
      expect(modified.id, 'wh1');
      expect(hours.isClosed, false);
    });
  });
}
