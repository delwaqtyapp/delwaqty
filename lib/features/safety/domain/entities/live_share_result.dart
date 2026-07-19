import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_share_result.freezed.dart';
part 'live_share_result.g.dart';

@freezed
class LiveShareResult with _$LiveShareResult {
  const factory LiveShareResult({
    required bool success,
    required String sessionId,
    required String shareToken,
    required DateTime expiresAt,
  }) = _LiveShareResult;

  factory LiveShareResult.fromJson(Map<String, dynamic> json) =>
      _$LiveShareResultFromJson(json);
}
