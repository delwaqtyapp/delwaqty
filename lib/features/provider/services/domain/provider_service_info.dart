/// Read model for the "my services and prices" view of a service-type
/// account (home services, teachers, doctors). Prices are managed by the
/// admin team; the provider can only read them.
class ProviderServiceInfo {
  const ProviderServiceInfo({
    required this.categoryType,
    required this.name,
    this.description = '',
    this.hourlyRate,
    this.fixedPriceMin,
    this.fixedPriceMax,
    this.isAvailable = true,
    this.tags = const [],
  });

  factory ProviderServiceInfo.fromJson(Map<String, dynamic> json) {
    double? num_(Object? v) => v is num ? v.toDouble() : double.tryParse('$v');
    return ProviderServiceInfo(
      categoryType: (json['category_type'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      description: (json['description'] as String? ?? '').trim(),
      hourlyRate: num_(json['hourly_rate']),
      fixedPriceMin: num_(json['fixed_price_min']),
      fixedPriceMax: num_(json['fixed_price_max']),
      isAvailable: json['is_available'] != false,
      tags: (json['tags'] as List?)?.map((e) => '$e').toList() ?? const [],
    );
  }

  final String categoryType;
  final String name;
  final String description;
  final double? hourlyRate;
  final double? fixedPriceMin;
  final double? fixedPriceMax;
  final bool isAvailable;
  final List<String> tags;

  bool get hasAnyPrice =>
      hourlyRate != null || fixedPriceMin != null || fixedPriceMax != null;
}
