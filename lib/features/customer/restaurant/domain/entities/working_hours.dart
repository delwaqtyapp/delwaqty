import 'package:freezed_annotation/freezed_annotation.dart';

part 'working_hours.freezed.dart';
part 'working_hours.g.dart';

@freezed
class WorkingHours with _$WorkingHours {
  const factory WorkingHours({
    required String id,
    required String merchantId,
    String? branchId,
    required int dayOfWeek,
    required String openTime,
    required String closeTime,
    @Default(false) bool isClosed,
    required DateTime createdAt,
  }) = _WorkingHours;

  factory WorkingHours.fromJson(Map<String, dynamic> json) =>
      _$WorkingHoursFromJson(json);
}
