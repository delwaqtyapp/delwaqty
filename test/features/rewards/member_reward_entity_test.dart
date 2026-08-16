import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/rewards/domain/entities/member_reward.dart';

void main() {
  group('MemberReward.fromJson', () {
    test('parses a birthday reward row', () {
      final reward = MemberReward.fromJson({
        'id': 'reward-1',
        'userId': 'user-123',
        'rewardType': 'birthday',
        'periodKey': 'birthday:2026',
        'benefit': {'kind': 'coupon', 'coupon_id': 'coupon-1'},
        'campaignId': 'campaign-1',
        'status': 'granted',
        'notifiedAt': '2026-07-19T10:00:00.000Z',
        'createdAt': '2026-07-19T10:00:00.000Z',
      });

      expect(reward.id, 'reward-1');
      expect(reward.userId, 'user-123');
      expect(reward.rewardType, RewardType.birthday);
      expect(reward.periodKey, 'birthday:2026');
      expect(reward.benefitKind, 'coupon');
      expect(reward.campaignId, 'campaign-1');
      expect(reward.status, RewardStatus.granted);
      expect(reward.notifiedAt, isNotNull);
    });

    test('parses an anniversary reward without benefit or notifiedAt', () {
      final reward = MemberReward.fromJson({
        'id': 'reward-2',
        'userId': 'user-123',
        'rewardType': 'anniversary',
        'periodKey': 'anniversary:2',
        'benefit': {'kind': 'none'},
        'status': 'claimed',
        'createdAt': '2026-07-19T10:00:00.000Z',
      });

      expect(reward.rewardType, RewardType.anniversary);
      expect(reward.benefitKind, 'none');
      expect(reward.status, RewardStatus.claimed);
      expect(reward.notifiedAt, isNull);
    });

    test('benefitKind falls back to none when benefit is missing', () {
      final reward = MemberReward.fromJson({
        'id': 'reward-3',
        'userId': 'user-123',
        'rewardType': 'birthday',
        'periodKey': 'birthday:2027',
        'status': 'expired',
        'createdAt': '2027-07-19T10:00:00.000Z',
      });

      expect(reward.benefitKind, 'none');
      expect(reward.status, RewardStatus.expired);
    });
  });

  group('RewardType', () {
    test('exposes snake_case JsonValue names', () {
      expect(RewardType.birthday.name, 'birthday');
      expect(RewardType.anniversary.name, 'anniversary');
    });
  });

  group('RewardStatus', () {
    test('exposes snake_case JsonValue names', () {
      expect(RewardStatus.granted.name, 'granted');
      expect(RewardStatus.claimed.name, 'claimed');
      expect(RewardStatus.expired.name, 'expired');
    });
  });
}
