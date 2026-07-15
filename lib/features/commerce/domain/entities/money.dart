import 'package:freezed_annotation/freezed_annotation.dart';

part 'money.freezed.dart';
part 'money.g.dart';

@freezed
class Money with _$Money {
  const factory Money({
    @Default(0.0) double amount,
    @Default('SAR') String currency,
  }) = _Money;

  factory Money.fromJson(Map<String, dynamic> json) => _$MoneyFromJson(json);
}
