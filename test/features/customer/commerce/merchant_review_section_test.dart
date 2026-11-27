import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/merchant_review_section.dart';

void main() {
  group('canSubmitReview', () {
    test('blocked until a star rating is chosen', () {
      expect(canSubmitReview(rating: 0, submitting: false), isFalse);
      expect(canSubmitReview(rating: 1, submitting: false), isTrue);
      expect(canSubmitReview(rating: 5, submitting: false), isTrue);
    });

    test('blocked while a submission is in flight', () {
      expect(canSubmitReview(rating: 4, submitting: true), isFalse);
    });
  });
}
