import 'package:freezed_annotation/freezed_annotation.dart';

part 'sos_alert.freezed.dart';
part 'sos_alert.g.dart';

enum SosAlertType { manual, automatic, timer }

enum SosAlertStatus { active, escalated, resolved, falseAlarm }

@freezed
class SosAlert with _$SosAlert {
  const factory SosAlert({
    required String id,
    required String rideId,
    required String userId,
    @Default(SosAlertType.manual) SosAlertType alertType,
    double? latitude,
    double? longitude,
    String? address,
    @Default(SosAlertStatus.active) SosAlertStatus status,
    @Default([]) List<String> notifiedContactIds,
    String? notes,
    required DateTime createdAt,
    DateTime? resolvedAt,
  }) = _SosAlert;

  factory SosAlert.fromJson(Map<String, dynamic> json) =>
      _$SosAlertFromJson(json);
}
