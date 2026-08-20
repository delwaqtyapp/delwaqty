import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_share_session.freezed.dart';
part 'live_share_session.g.dart';

@freezed
class LiveShareSession with _$LiveShareSession {
  const factory LiveShareSession({
    required String id,
    required String rideId,
    required String userId,
    required String shareToken,
    required bool isActive,
    required DateTime expiresAt,
    required DateTime createdAt,
  }) = _LiveShareSession;

  factory LiveShareSession.fromJson(Map<String, dynamic> json) =>
      _$LiveShareSessionFromJson(json);
}
