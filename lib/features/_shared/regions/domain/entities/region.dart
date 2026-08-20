import 'package:freezed_annotation/freezed_annotation.dart';

part 'region.freezed.dart';
part 'region.g.dart';

enum RegionType {
  country('country'),
  governorate('governorate'),
  markaz('markaz'),
  district('district'),
  city('city'),
  village('village'),
  newCity('new_city'),
  area('area');

  const RegionType(this.code);

  final String code;

  static RegionType fromCode(String? code) => RegionType.values.firstWhere(
    (t) => t.code == code,
    orElse: () => RegionType.country,
  );
}

enum RegionPreferenceSource {
  detected('detected'),
  manual('manual'),
  verified('verified');

  const RegionPreferenceSource(this.code);

  final String code;

  static RegionPreferenceSource fromCode(String? code) =>
      RegionPreferenceSource.values.firstWhere(
        (s) => s.code == code,
        orElse: () => RegionPreferenceSource.detected,
      );
}

@freezed
class Region with _$Region {
  const factory Region({
    required String id,
    required String code,
    String? parentRegionId,
    @Default('EG') String countryCode,
    required RegionType type,
    required String nameAr,
    String? nameEn,
    @Default(true) bool isActive,
    Map<String, dynamic>? metadata,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _Region;

  factory Region.fromJson(Map<String, dynamic> json) => _$RegionFromJson(json);

  const Region._();

  String displayName(String language) =>
      language == 'ar' ? nameAr : (nameEn ?? nameAr);

  List<String> get aliases =>
      (metadata?['aliases'] as List<dynamic>?)?.cast<String>() ?? const [];
}

@freezed
class UserRegionPreference with _$UserRegionPreference {
  const factory UserRegionPreference({
    required String userId,
    required String regionId,
    required RegionPreferenceSource source,
    required DateTime updatedAt,
  }) = _UserRegionPreference;

  factory UserRegionPreference.fromJson(Map<String, dynamic> json) =>
      _$UserRegionPreferenceFromJson(json);
}

class RegionException implements Exception {
  const RegionException(this.message);
  final String message;

  @override
  String toString() => 'RegionException: $message';
}
