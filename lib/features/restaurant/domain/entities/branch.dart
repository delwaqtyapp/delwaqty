import 'package:freezed_annotation/freezed_annotation.dart';

part 'branch.freezed.dart';
part 'branch.g.dart';

@freezed
class Branch with _$Branch {
  const factory Branch({
    required String id,
    required String merchantId,
    required String name,
    String? address,
    double? latitude,
    double? longitude,
    String? phone,
    @Default(true) bool isActive,
    @Default(false) bool isPrimary,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _Branch;

  factory Branch.fromJson(Map<String, dynamic> json) => _$BranchFromJson(json);
}
