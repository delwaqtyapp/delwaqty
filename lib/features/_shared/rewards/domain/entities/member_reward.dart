import 'package:freezed_annotation/freezed_annotation.dart';

part 'member_reward.freezed.dart';
part 'member_reward.g.dart';

enum RewardType {
  @JsonValue('birthday')
  birthday,
  @JsonValue('anniversary')
  anniversary,
}

enum RewardStatus {
  @JsonValue('granted')
  granted,
  @JsonValue('claimed')
  claimed,
  @JsonValue('expired')
  expired,
}

@freezed
abstract class MemberReward with _$MemberReward {
  const factory MemberReward({
    required String id,
    required String userId,
    required RewardType rewardType,
    required String periodKey,
    Map<String, dynamic>? benefit,
    String? campaignId,
    required RewardStatus status,
    DateTime? notifiedAt,
    required DateTime createdAt,
  }) = _MemberReward;

  factory MemberReward.fromJson(Map<String, dynamic> json) =>
      _$MemberRewardFromJson(json);

  const MemberReward._();

  String get benefitKind => (benefit?['kind'] as String?) ?? 'none';

  int? get birthdayYear {
    if (rewardType != RewardType.birthday) return null;
    final parts = periodKey.split(':');
    return parts.length == 2 ? int.tryParse(parts[1]) : null;
  }

  int? get anniversaryYears {
    if (rewardType != RewardType.anniversary) return null;
    final parts = periodKey.split(':');
    return parts.length == 2 ? int.tryParse(parts[1]) : null;
  }

  String? get benefitCode => benefit?['code'] as String?;
}
