import 'package:delwaqty/features/admin/sanctions/domain/entities/sanction.dart';

abstract class SanctionsRepository {
  Future<List<Sanction>> getSanctions({bool? active});
  Future<List<Sanction>> getUserSanctions(String targetUserId);
  Future<Sanction> getSanctionById(String id);
  Future<String> issueSanction({
    required String memberId,
    required String sanctionType,
    required String reason,
    int durationDays = 0,
    double amount = 0,
    String? evidenceUrl,
  });
  Future<void> revokeSanction({
    required String sanctionId,
    required String reason,
  });
}
