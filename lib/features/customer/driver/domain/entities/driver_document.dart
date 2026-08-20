import 'package:freezed_annotation/freezed_annotation.dart';

part 'driver_document.freezed.dart';
part 'driver_document.g.dart';

@freezed
class DriverDocument with _$DriverDocument {
  const factory DriverDocument({
    required String id,
    required String driverId,
    required String docType,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    @Default('pending') String status,
    String? rejectionReason,
    DateTime? expiresAt,
    required DateTime createdAt,
    DateTime? reviewedAt,
  }) = _DriverDocument;

  factory DriverDocument.fromJson(Map<String, dynamic> json) =>
      _$DriverDocumentFromJson(json);
}
