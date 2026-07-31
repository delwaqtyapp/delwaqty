import 'package:delwaqty/features/sanctions/domain/entities/sanction.dart';

abstract class SanctionsRepository {
  Future<List<Sanction>> getSanctions({bool? active});
  Future<List<Sanction>> getUserSanctions(String targetUserId);
  Future<Sanction> getSanctionById(String id);
  Future<Sanction> createSanction(Sanction sanction);
  Future<Sanction> updateSanction(String id, Map<String, dynamic> updates);
  Future<void> revokeSanction(String id);
}
