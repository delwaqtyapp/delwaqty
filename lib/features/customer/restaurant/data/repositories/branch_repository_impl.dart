import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/customer/restaurant/data/datasources/remote/supabase_branch_data_source.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/branch.dart';
import 'package:delwaqty/features/customer/restaurant/domain/repositories/branch_repository.dart';

class BranchRepositoryImpl implements BranchRepository {
  BranchRepositoryImpl(this._dataSource);
  final SupabaseBranchDataSource _dataSource;

  @override
  Future<List<Branch>> getBranches(String merchantId) async {
    try {
      return await _dataSource.getBranches(merchantId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Branch?> getBranchById(String id) async {
    try {
      return await _dataSource.getBranchById(id);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Branch> createBranch(Branch branch) async {
    try {
      return await _dataSource.createBranch(branch);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Branch> updateBranch(Branch branch) async {
    try {
      return await _dataSource.updateBranch(branch);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> deleteBranch(String id) async {
    try {
      await _dataSource.deleteBranch(id);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
