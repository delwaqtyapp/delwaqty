import 'package:freezed_annotation/freezed_annotation.dart';

part 'contact_result.freezed.dart';
part 'contact_result.g.dart';

@freezed
abstract class ContactResult with _$ContactResult {
  const factory ContactResult({
    required bool success,
    String? contactId,
    String? reason,
  }) = _ContactResult;

  factory ContactResult.fromJson(Map<String, dynamic> json) =>
      _$ContactResultFromJson(json);
}
