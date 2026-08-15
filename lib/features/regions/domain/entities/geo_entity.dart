import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:delwaqty/features/regions/domain/entities/spatial_resolution.dart';

part 'geo_entity.freezed.dart';
part 'geo_entity.g.dart';

/// Significant named geographic entities (ADR-057 §14): tourism, transport,
/// landmarks, universities — NEVER an admin unit and NEVER a business
/// directory.
enum GeoPlaceType {
  hotel('hotel'),
  resort('resort'),
  touristVillage('tourist_village'),
  touristCity('tourist_city'),
  compound('compound'),
  development('development'),
  airport('airport'),
  port('port'),
  university('university'),
  hospital('hospital'),
  station('station'),
  landmark('landmark'),
  settlement('settlement'),
  poi('poi');

  const GeoPlaceType(this.code);

  final String code;

  static GeoPlaceType fromCode(String? code) =>
      GeoPlaceType.values.firstWhere(
        (t) => t.code == code,
        orElse: () => GeoPlaceType.poi,
      );
}

/// Source-type classification (mandatory provenance, ADR-057).
enum GeoSourceType {
  officialVerified('OFFICIAL VERIFIED'),
  secondaryVerified('SECONDARY VERIFIED'),
  providerDerived('PROVIDER-DERIVED'),
  unverifiedMissing('UNVERIFIED-MISSING');

  const GeoSourceType(this.code);

  final String code;

  static GeoSourceType fromCode(String? code) =>
      GeoSourceType.values.firstWhere(
        (t) => t.code == code,
        orElse: () => GeoSourceType.unverifiedMissing,
      );
}

@freezed
class GeoPlace with _$GeoPlace {
  const factory GeoPlace({
    required String id,
    required GeoPlaceType type,
    String? regionId,
    String? nameAr,
    String? nameEn,
    double? latitude,
    double? longitude,
    required String source,
    required String sourceRef,
    DateTime? sourceDate,
    required GeoSourceType sourceType,
    required GeoConfidence confidence,
    Map<String, dynamic>? provenance,
    String? license,
    @Default(true) bool isActive,
    Map<String, dynamic>? metadata,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _GeoPlace;

  factory GeoPlace.fromJson(Map<String, dynamic> json) =>
      _$GeoPlaceFromJson(json);

  /// Maps a raw `geo_places` table row (snake_case) without a framework
  /// dependency, keeping the DB mapping logic testable in the domain layer.
  factory GeoPlace.fromRow(Map<String, dynamic> row) => GeoPlace(
    id: row['id'] as String,
    type: GeoPlaceType.fromCode(row['type'] as String?),
    regionId: row['region_id'] as String?,
    nameAr: row['name_ar'] as String?,
    nameEn: row['name_en'] as String?,
    latitude: (row['latitude'] as num?)?.toDouble(),
    longitude: (row['longitude'] as num?)?.toDouble(),
    source: row['source'] as String,
    sourceRef: row['source_ref'] as String,
    sourceDate: row['source_date'] != null
        ? DateTime.parse(row['source_date'] as String)
        : null,
    sourceType: GeoSourceType.fromCode(row['source_type'] as String?),
    confidence: GeoConfidence.fromCode(row['confidence'] as String?),
    provenance: row['provenance'] as Map<String, dynamic>?,
    license: row['license'] as String?,
    isActive: row['is_active'] as bool? ?? true,
    metadata: row['metadata'] as Map<String, dynamic>?,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: row['updated_at'] != null
        ? DateTime.parse(row['updated_at'] as String)
        : null,
  );

  const GeoPlace._();

  String displayName(String language) {
    if (language == 'ar') return nameAr ?? nameEn ?? sourceRef;
    return nameEn ?? nameAr ?? sourceRef;
  }
}

@freezed
class GeoAlias with _$GeoAlias {
  const factory GeoAlias({
    required String entityType,
    required String entityId,
    required String alias,
    String? lang,
    @Default(false) bool isPrimary,
    required String source,
  }) = _GeoAlias;

  factory GeoAlias.fromJson(Map<String, dynamic> json) =>
      _$GeoAliasFromJson(json);

  /// Maps a raw `geo_aliases` table row (snake_case) without a framework
  /// dependency.
  factory GeoAlias.fromRow(Map<String, dynamic> row) => GeoAlias(
    entityType: row['entity_type'] as String,
    entityId: row['entity_id'] as String,
    alias: row['alias'] as String,
    lang: row['lang'] as String?,
    isPrimary: row['is_primary'] as bool? ?? false,
    source: row['source'] as String,
  );
}
