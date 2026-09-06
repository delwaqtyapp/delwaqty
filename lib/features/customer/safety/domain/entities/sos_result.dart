import 'package:freezed_annotation/freezed_annotation.dart';

part 'sos_result.freezed.dart';
part 'sos_result.g.dart';

@freezed
abstract class SosResult with _$SosResult {
  const factory SosResult({
    required bool success,
    required String alertId,
    required List<NotifiedContact> notifiedContacts,
    required String rideId,
  }) = _SosResult;

  factory SosResult.fromJson(Map<String, dynamic> json) =>
      _$SosResultFromJson(json);
}

@freezed
abstract class NotifiedContact with _$NotifiedContact {
  const factory NotifiedContact({
    required String id,
    required String name,
    required String phone,
    required String preference,
  }) = _NotifiedContact;

  factory NotifiedContact.fromJson(Map<String, dynamic> json) =>
      _$NotifiedContactFromJson(json);
}
