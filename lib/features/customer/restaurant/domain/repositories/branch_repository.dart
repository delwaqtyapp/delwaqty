import 'package:delwaqty/features/customer/restaurant/domain/entities/branch.dart';

abstract interface class BranchRepository {
  Future<List<Branch>> getBranches(String merchantId);
  Future<Branch?> getBranchById(String id);
  Future<Branch> createBranch(Branch branch);
  Future<Branch> updateBranch(Branch branch);
  Future<void> deleteBranch(String id);
}
