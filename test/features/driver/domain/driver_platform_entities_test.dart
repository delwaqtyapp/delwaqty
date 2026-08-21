import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/driver/domain/entities/vehicle.dart';
import 'package:delwaqty/features/driver/domain/entities/driver_document.dart';
import 'package:delwaqty/features/driver/domain/entities/wallet_detail.dart';
import 'package:delwaqty/features/driver/domain/entities/driver_performance.dart';
import 'package:delwaqty/features/driver/domain/entities/driver_profile.dart';

void main() {
  group('Vehicle', () {
    test('fromJson roundtrip', () {
      final now = DateTime.utc(2026);
      final v = Vehicle(
        id: 'v1',
        driverId: 'd1',
        category: 'motorbike',
        make: 'Honda',
        model: 'CRF',
        year: 2024,
        color: 'Red',
        plateNumber: 'ABC-123',
        seats: 2,
        photoUrl: 'https://example.com/photo.jpg',
        createdAt: now,
      );
      final json = v.toJson();
      final restored = Vehicle.fromJson(json);
      expect(restored.id, v.id);
      expect(restored.category, 'motorbike');
      expect(restored.plateNumber, 'ABC-123');
      expect(restored.seats, 2);
      expect(restored.isActive, true);
      expect(restored.photoUrl, 'https://example.com/photo.jpg');
    });

    test('default values', () {
      final v = Vehicle(
        id: 'v1',
        driverId: 'd1',
        category: 'economy',
        plateNumber: 'X',
        createdAt: DateTime(2026),
      );
      expect(v.seats, 4);
      expect(v.isActive, true);
      expect(v.isVerified, false);
      expect(v.photoUrl, isNull);
      expect(v.registrationExpiresAt, isNull);
      expect(v.insuranceExpiresAt, isNull);
    });

    test('vehicle category types for future-proofing', () {
      final categories = [
        'economy', 'comfort', 'premium', 'xl',
        'motorbike', 'taxi', 'motorcycle', 'scooter', 'van', 'pickup',
      ];
      for (final cat in categories) {
        final v = Vehicle(
          id: 'v1',
          driverId: 'd1',
          category: cat,
          plateNumber: 'X',
          createdAt: DateTime(2026),
        );
        expect(v.category, cat);
      }
    });
  });

  group('DriverDocument', () {
    test('fromJson roundtrip', () {
      final d = DriverDocument(
        id: 'doc1',
        driverId: 'd1',
        docType: 'driving_license',
        fileUrl: 'https://storage.example.com/license.pdf',
        fileName: 'license.pdf',
        fileSize: 1024,
        expiresAt: DateTime(2027, 6, 15),
        createdAt: DateTime(2026),
      );
      final json = d.toJson();
      final restored = DriverDocument.fromJson(json);
      expect(restored.id, 'doc1');
      expect(restored.docType, 'driving_license');
      expect(restored.status, 'pending');
      expect(restored.fileName, 'license.pdf');
      expect(restored.fileSize, 1024);
    });

    test('all doc types', () {
      final types = [
        'identity', 'driving_license', 'vehicle_registration',
        'insurance', 'vehicle_photo', 'profile_photo',
      ];
      for (final t in types) {
        final d = DriverDocument(
          id: 'd1',
          driverId: 'd1',
          docType: t,
          createdAt: DateTime(2026),
        );
        expect(d.docType, t);
      }
    });

    test('document status states', () {
      final pending = DriverDocument(
        id: 'd1', driverId: 'd1', docType: 'identity', createdAt: DateTime(2026),
      );
      final verified = DriverDocument(
        id: 'd2', driverId: 'd1', docType: 'identity',
        status: 'verified', createdAt: DateTime(2026),
      );
      final rejected = DriverDocument(
        id: 'd3', driverId: 'd1', docType: 'identity',
        status: 'rejected', rejectionReason: 'Blurry image',
        createdAt: DateTime(2026),
      );
      expect(pending.status, 'pending');
      expect(verified.status, 'verified');
      expect(rejected.status, 'rejected');
      expect(rejected.rejectionReason, 'Blurry image');
    });
  });

  group('WalletDetail', () {
    test('empty constructor', () {
      const w = WalletDetail.empty;
      expect(w.balance, 0);
      expect(w.bonusBalance, 0);
      expect(w.incentiveBalance, 0);
      expect(w.pendingWithdrawals, 0);
      expect(w.totalWithdrawn, 0);
      expect(w.currency, 'EGP');
    });

    test('with values', () {
      const w = WalletDetail(
        balance: 1500.50,
        bonusBalance: 200,
        incentiveBalance: 100,
        pendingWithdrawals: 300,
        totalWithdrawn: 5000,
      );
      expect(w.balance, 1500.50);
      expect(w.bonusBalance, 200);
      expect(w.incentiveBalance, 100);
      expect(w.pendingWithdrawals, 300);
      expect(w.totalWithdrawn, 5000);
    });
  });

  group('DriverPerformance', () {
    test('empty constructor', () {
      const p = DriverPerformance.empty;
      expect(p.totalTrips, 0);
      expect(p.completedTrips, 0);
      expect(p.cancelledTrips, 0);
      expect(p.rating, 0);
      expect(p.acceptanceRate, 100);
      expect(p.cancellationRate, 0);
      expect(p.todayRides, 0);
      expect(p.todayEarnings, 0);
      expect(p.weekEarnings, 0);
      expect(p.monthEarnings, 0);
      expect(p.balance, 0);
      expect(p.bonusBalance, 0);
      expect(p.incentiveBalance, 0);
      expect(p.pendingWithdrawals, 0);
      expect(p.currency, 'EGP');
    });

    test('with values', () {
      const p = DriverPerformance(
        totalTrips: 150,
        completedTrips: 140,
        cancelledTrips: 10,
        rating: 4.8,
        acceptanceRate: 95.5,
        cancellationRate: 6.7,
        todayRides: 5,
        todayEarnings: 450,
        weekEarnings: 3200,
        monthEarnings: 12000,
        balance: 2500,
        bonusBalance: 300,
        incentiveBalance: 150,
        pendingWithdrawals: 500,
      );
      expect(p.totalTrips, 150);
      expect(p.completedTrips, 140);
      expect(p.cancelledTrips, 10);
      expect(p.rating, 4.8);
      expect(p.acceptanceRate, 95.5);
      expect(p.cancellationRate, 6.7);
      expect(p.monthEarnings, 12000);
      expect(p.bonusBalance, 300);
      expect(p.incentiveBalance, 150);
    });
  });

  group('DriverProfile extended fields', () {
    test('onboarding fields default values', () {
      final p = DriverProfile(
        id: 'd1',
        userId: 'u1',
        createdAt: DateTime(2026),
      );
      expect(p.onboardingCompleted, false);
      expect(p.onboardingStep, 0);
      expect(p.verificationStatus, 'pending');
    });

    test('onboarding fields set values', () {
      final p = DriverProfile(
        id: 'd1',
        userId: 'u1',
        createdAt: DateTime(2026),
        onboardingCompleted: true,
        onboardingStep: 5,
        verificationStatus: 'verified',
      );
      expect(p.onboardingCompleted, true);
      expect(p.onboardingStep, 5);
      expect(p.verificationStatus, 'verified');
    });

    test('fromJson roundtrip preserves onboarding fields', () {
      final p = DriverProfile(
        id: 'd1',
        userId: 'u1',
        createdAt: DateTime(2026),
        onboardingCompleted: true,
        onboardingStep: 3,
      );
      final json = p.toJson();
      final restored = DriverProfile.fromJson(json);
      expect(restored.onboardingCompleted, true);
      expect(restored.onboardingStep, 3);
      expect(restored.verificationStatus, 'pending');
    });
  });
}
