import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_review.dart';

void main() {
  group('ServiceReview', () {
    test('fromJson parses real service_reviews row', () {
      final row = <String, dynamic>{
        'id': 'sr-1',
        'user_id': null,
        'user_name': 'سارة',
        'category_type': 'plumbing',
        'provider_id': null,
        'booking_id': null,
        'rating': 5,
        'comment': 'شغل ممتاز',
        'created_at': '2026-07-17T21:46:03.2872+00:00',
      };
      final r = ServiceReview.fromJson(row);
      expect(r.id, 'sr-1');
      expect(r.userName, 'سارة');
      expect(r.categoryType, 'plumbing');
      expect(r.rating, 5);
      expect(r.comment, 'شغل ممتاز');
      expect(r.createdAt, isNotNull);
    });

    test('fromJson tolerates null comment and unknown createdAt', () {
      final row = <String, dynamic>{
        'id': 'sr-2',
        'user_name': 'خالد',
        'category_type': 'barber',
        'rating': 3,
        'comment': null,
        'created_at': null,
      };
      final r = ServiceReview.fromJson(row);
      expect(r.comment, isNull);
      expect(r.createdAt, isNull);
      expect(r.rating, 3);
    });
  });

  group('ServiceReviewSummary', () {
    test('fromJson parses get_service_rating_summary result', () {
      final row = <String, dynamic>{
        'category_type': 'plumbing',
        'avg_rating': 4.5,
        'total_reviews': 4,
        'five_star': 2,
        'four_star': 2,
        'three_star': 0,
        'two_star': 0,
        'one_star': 0,
      };
      final s = ServiceReviewSummary.fromJson(row);
      expect(s.averageRating, 4.5);
      expect(s.totalReviews, 4);
      expect(s.fiveStar, 2);
      expect(s.countFor(5), 2);
      expect(s.countFor(4), 2);
      expect(s.countFor(1), 0);
    });

    test('countFor ignores unsupported star count', () {
      const s = ServiceReviewSummary(fiveStar: 1, oneStar: 2);
      expect(s.countFor(5), 1);
      expect(s.countFor(1), 2);
      expect(s.countFor(0), 2);
    });
  });
}