import 'package:freezed_annotation/freezed_annotation.dart';

part 'saved_account.freezed.dart';
part 'saved_account.g.dart';

@freezed
class SavedAccount with _$SavedAccount {
  const factory SavedAccount({
    @Default('') String email,
    @Default('') String displayName,
    @Default(false) bool hasBiometric,
  }) = _SavedAccount;

  const SavedAccount._();

  factory SavedAccount.fromJson(Map<String, dynamic> json) =>
      _$SavedAccountFromJson(json);

  String get key => email.trim().toLowerCase();
}
