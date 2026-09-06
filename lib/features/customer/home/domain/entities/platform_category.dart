import 'package:freezed_annotation/freezed_annotation.dart';

part 'platform_category.freezed.dart';
part 'platform_category.g.dart';

@freezed
abstract class PlatformCategory with _$PlatformCategory {
  const factory PlatformCategory({
    required String id,
    required String name,
    String? nameAr,
    String? nameEn,
    String? icon,
    String? imageUrl,
    @Default(0) int sortOrder,
    @Default(true) bool isActive,
    DateTime? createdAt,
  }) = _PlatformCategory;

  factory PlatformCategory.fromJson(Map<String, dynamic> json) =>
      _$PlatformCategoryFromJson(json);
}

extension PlatformCategoryX on PlatformCategory {
  String displayName(bool isArabic) {
    if (isArabic && nameAr != null && nameAr!.isNotEmpty) return nameAr!;
    if (nameEn != null && nameEn!.isNotEmpty) return nameEn!;
    return name;
  }
}
