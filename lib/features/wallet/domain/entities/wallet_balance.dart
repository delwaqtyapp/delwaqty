import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_balance.freezed.dart';
part 'wallet_balance.g.dart';

@freezed
class WalletBalance with _$WalletBalance {
  const factory WalletBalance({
    required String id,
    required String userId,
    @Default(0.0) double balance,
    @Default('SAR') String currency,
    required DateTime updatedAt,
  }) = _WalletBalance;

  factory WalletBalance.fromJson(Map<String, dynamic> json) =>
      _$WalletBalanceFromJson(json);
}
