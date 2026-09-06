import 'package:freezed_annotation/freezed_annotation.dart';

part 'spatial_resolution.freezed.dart';
part 'spatial_resolution.g.dart';

/// Confidence of a server-side spatial resolution (ADR-057 �17).
///   HIGH    point-in-polygon match (or verified centroid refinement)
///   MEDIUM  nearest-boundary snap within tolerance
///   LOW     nearest governorate centroid fallback
///   UNVERIFIED / INVALID  nothing usable resolved
enum GeoConfidence {
  high('HIGH'),
  medium('MEDIUM'),
  low('LOW'),
  unverified('UNVERIFIED'),
  invalid('INVALID');

  const GeoConfidence(this.code);

  final String code;

  static GeoConfidence fromCode(String? code) =>
      GeoConfidence.values.firstWhere(
        (c) => c.code == code,
        orElse: () => GeoConfidence.unverified,
      );

  bool get mayAutoPersist =>
      this == GeoConfidence.high || this == GeoConfidence.medium;
}

/// Result of the `geo_region_for_point` RPC: the matched region plus its
/// governorate ancestor and the confidence/distance of the match.
/// [regionId] is null when the server returned INVALID/UNVERIFIED.
@freezed
abstract class SpatialResolution with _$SpatialResolution {
  const factory SpatialResolution({
    String? regionId,
    String? code,
    String? nameAr,
    String? nameEn,
    String? type,
    String? parentRegionId,
    String? governorateId,
    String? governorateCode,
    String? governorateNameAr,
    String? governorateNameEn,
    required GeoConfidence confidence,
    double? distanceM,
  }) = _SpatialResolution;

  factory SpatialResolution.fromJson(Map<String, dynamic> json) =>
      _$SpatialResolutionFromJson(json);

  /// Maps a raw `geo_region_for_point` RPC payload (snake_case) without a
  /// framework dependency, keeping the mapping testable in the domain layer.
  factory SpatialResolution.fromRpc(Map<String, dynamic> json) =>
      SpatialResolution(
        regionId: json['region_id'] as String?,
        code: json['code'] as String?,
        nameAr: json['name_ar'] as String?,
        nameEn: json['name_en'] as String?,
        type: json['type'] as String?,
        parentRegionId: json['parent_region_id'] as String?,
        governorateId: json['governorate_id'] as String?,
        governorateCode: json['governorate_code'] as String?,
        governorateNameAr: json['governorate_name_ar'] as String?,
        governorateNameEn: json['governorate_name_en'] as String?,
        confidence: GeoConfidence.fromCode(json['confidence'] as String?),
        distanceM: (json['distance_m'] as num?)?.toDouble(),
      );
}
