import 'package:freezed_annotation/freezed_annotation.dart';

part 'admin_region_assignment.freezed.dart';
part 'admin_region_assignment.g.dart';

enum AdminRegionScope {
  self('self'),
  descendants('descendants');

  const AdminRegionScope(this.code);

  final String code;

  static AdminRegionScope fromCode(String? code) =>
      AdminRegionScope.values.firstWhere(
        (s) => s.code == code,
        orElse: () => AdminRegionScope.descendants,
      );
}

@freezed
class AdminRegionAssignment with _$AdminRegionAssignment {
  const factory AdminRegionAssignment({
    required String adminId,
    required String regionId,
    required AdminRegionScope scope,
    required DateTime createdAt,
    String? createdBy,
  }) = _AdminRegionAssignment;

  factory AdminRegionAssignment.fromJson(Map<String, dynamic> json) =>
      _$AdminRegionAssignmentFromJson(json);
}
