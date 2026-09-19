import 'package:freezed_annotation/freezed_annotation.dart';

part 'service_category.freezed.dart';
part 'service_category.g.dart';

enum ServiceCategoryType {
  @JsonValue('plumbing')
  plumbing,
  @JsonValue('electrical')
  electrical,
  @JsonValue('carpentry')
  carpentry,
  @JsonValue('acMaintenance')
  acMaintenance,
  @JsonValue('painting')
  painting,
  @JsonValue('cleaning')
  cleaning,
  @JsonValue('pestControl')
  pestControl,
  @JsonValue('applianceRepair')
  applianceRepair,
  @JsonValue('pipeChange')
  pipeChange,
  @JsonValue('plastering')
  plastering,
  @JsonValue('carpetCleaning')
  carpetCleaning,
  @JsonValue('dishRepair')
  dishRepair,
  @JsonValue('teacher')
  teacher,
  @JsonValue('doctor')
  doctor,
  @JsonValue('nurse')
  nurse,
  @JsonValue('barber')
  barber,
  @JsonValue('deliveryCar')
  deliveryCar,
  @JsonValue('other')
  other,
}

@freezed
abstract class ServiceCategory with _$ServiceCategory {
  const factory ServiceCategory({
    required String id,
    required String nameAr,
    required String nameEn,
    required ServiceCategoryType type,
    String? descriptionAr,
    String? descriptionEn,
    String? iconUrl,
    @Default(true) bool isActive,
    required DateTime createdAt,
  }) = _ServiceCategory;

  factory ServiceCategory.fromJson(Map<String, dynamic> json) =>
      _$ServiceCategoryFromJson(json);
}
