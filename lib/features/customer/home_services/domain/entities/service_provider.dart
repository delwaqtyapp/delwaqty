import 'package:freezed_annotation/freezed_annotation.dart';
import 'service_category.dart';

part 'service_provider.freezed.dart';
part 'service_provider.g.dart';

@freezed
abstract class ServiceProvider with _$ServiceProvider {
  const factory ServiceProvider({
    required String id,
    required String userId,
    required String name,
    required ServiceCategoryType categoryType,
    String? description,
    String? profileImageUrl,
    @Default(0.0) double rating,
    @Default(0) int ratingCount,
    @Default(false) bool isVerified,
    @Default(false) bool isAvailable,
    double? hourlyRate,
    double? fixedPriceMin,
    double? fixedPriceMax,
    String? city,
    double? latitude,
    double? longitude,
    @Default([]) List<String> tags,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _ServiceProvider;

  factory ServiceProvider.fromJson(Map<String, dynamic> json) =>
      _$ServiceProviderFromJson(json);
}
