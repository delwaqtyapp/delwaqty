import 'package:freezed_annotation/freezed_annotation.dart';

part 'merchant_stats.freezed.dart';
part 'merchant_stats.g.dart';

@freezed
abstract class MerchantStats with _$MerchantStats {
  const factory MerchantStats({
    @Default(0) int todayOrders,
    @Default(0.0) double todayRevenue,
    @Default(0) int pendingOrders,
    @Default(0.0) double averageRating,
    @Default(0) int totalProducts,
    @Default(0) int totalReviews,
  }) = _MerchantStats;

  factory MerchantStats.fromJson(Map<String, dynamic> json) =>
      _$MerchantStatsFromJson(json);
}
