import 'package:freezed_annotation/freezed_annotation.dart';

part 'service_category.freezed.dart';

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
  @JsonValue('other')
  other,
}

ServiceCategoryType serviceCategoryTypeFromJson(Object? value) {
  const byWireName = <String, ServiceCategoryType>{
    'plumbing': ServiceCategoryType.plumbing,
    'electrical': ServiceCategoryType.electrical,
    'carpentry': ServiceCategoryType.carpentry,
    'acMaintenance': ServiceCategoryType.acMaintenance,
    'painting': ServiceCategoryType.painting,
    'cleaning': ServiceCategoryType.cleaning,
    'pestControl': ServiceCategoryType.pestControl,
    'applianceRepair': ServiceCategoryType.applianceRepair,
    'pipeChange': ServiceCategoryType.pipeChange,
    'plastering': ServiceCategoryType.plastering,
    'carpetCleaning': ServiceCategoryType.carpetCleaning,
    'dishRepair': ServiceCategoryType.dishRepair,
    'teacher': ServiceCategoryType.teacher,
    'doctor': ServiceCategoryType.doctor,
    'nurse': ServiceCategoryType.nurse,
    'barber': ServiceCategoryType.barber,
    'other': ServiceCategoryType.other,
  };
  return byWireName[value] ?? ServiceCategoryType.other;
}

String serviceCategoryTypeToJson(ServiceCategoryType type) {
  const wireNames = <ServiceCategoryType, String>{
    ServiceCategoryType.plumbing: 'plumbing',
    ServiceCategoryType.electrical: 'electrical',
    ServiceCategoryType.carpentry: 'carpentry',
    ServiceCategoryType.acMaintenance: 'acMaintenance',
    ServiceCategoryType.painting: 'painting',
    ServiceCategoryType.cleaning: 'cleaning',
    ServiceCategoryType.pestControl: 'pestControl',
    ServiceCategoryType.applianceRepair: 'applianceRepair',
    ServiceCategoryType.pipeChange: 'pipeChange',
    ServiceCategoryType.plastering: 'plastering',
    ServiceCategoryType.carpetCleaning: 'carpetCleaning',
    ServiceCategoryType.dishRepair: 'dishRepair',
    ServiceCategoryType.teacher: 'teacher',
    ServiceCategoryType.doctor: 'doctor',
    ServiceCategoryType.nurse: 'nurse',
    ServiceCategoryType.barber: 'barber',
    ServiceCategoryType.other: 'other',
  };
  return wireNames[type] ?? 'other';
}

@freezed
abstract class ServiceCategory with _$ServiceCategory {
  const ServiceCategory._();

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

  factory ServiceCategory.fromJson(Map<String, dynamic> json) {
    return ServiceCategory(
      id: json['id'] as String,
      nameAr: json['name_ar'] as String? ?? '',
      nameEn: json['name_en'] as String? ?? '',
      type: serviceCategoryTypeFromJson(json['type']),
      descriptionAr: json['description_ar'] as String?,
      descriptionEn: json['description_en'] as String?,
      iconUrl: json['icon_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name_ar': nameAr,
      'name_en': nameEn,
      'type': serviceCategoryTypeToJson(type),
      'description_ar': descriptionAr,
      'description_en': descriptionEn,
      'icon_url': iconUrl,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
