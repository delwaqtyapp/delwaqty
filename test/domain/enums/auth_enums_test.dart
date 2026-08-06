import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/domain/enums/user_type.dart';
import 'package:delwaqty/domain/enums/verification_status.dart';

void main() {
  group('UserType', () {
    test('exposes expected codes', () {
      expect(UserType.customer.code, 'customer');
      expect(UserType.provider.code, 'provider');
      expect(UserType.delivery.code, 'delivery');
    });

    test('requiresVerification is true only for non-customers', () {
      expect(UserType.customer.requiresVerification, isFalse);
      expect(UserType.provider.requiresVerification, isTrue);
      expect(UserType.delivery.requiresVerification, isTrue);
    });

    test('fromCode maps known codes', () {
      expect(UserType.fromCode('customer'), UserType.customer);
      expect(UserType.fromCode('provider'), UserType.provider);
      expect(UserType.fromCode('delivery'), UserType.delivery);
    });

    test('fromCode falls back to customer for unknown or null', () {
      expect(UserType.fromCode('admin'), UserType.customer);
      expect(UserType.fromCode(null), UserType.customer);
    });
  });

  group('VerificationStatus', () {
    test('exposes expected codes', () {
      expect(VerificationStatus.pending.code, 'pending');
      expect(VerificationStatus.approved.code, 'approved');
      expect(VerificationStatus.rejected.code, 'rejected');
    });

    test('isApproved is true only for approved', () {
      expect(VerificationStatus.pending.isApproved, isFalse);
      expect(VerificationStatus.approved.isApproved, isTrue);
      expect(VerificationStatus.rejected.isApproved, isFalse);
    });

    test('fromCode maps known codes', () {
      expect(VerificationStatus.fromCode('pending'), VerificationStatus.pending);
      expect(
        VerificationStatus.fromCode('approved'),
        VerificationStatus.approved,
      );
      expect(
        VerificationStatus.fromCode('rejected'),
        VerificationStatus.rejected,
      );
    });

    test('fromCode falls back to pending for unknown or null', () {
      expect(VerificationStatus.fromCode('banned'), VerificationStatus.pending);
      expect(VerificationStatus.fromCode(null), VerificationStatus.pending);
    });
  });
}
