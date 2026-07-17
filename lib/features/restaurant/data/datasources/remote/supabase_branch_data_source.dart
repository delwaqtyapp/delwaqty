import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/restaurant/domain/entities/branch.dart';

final supabaseBranchDataSourceProvider = Provider<SupabaseBranchDataSource>((
  ref,
) {
  return SupabaseBranchDataSource(ref.watch(supabaseClientProvider));
});

class SupabaseBranchDataSource {
  SupabaseBranchDataSource(this._client);
  final SupabaseClient _client;

  Branch _fromRow(Map<String, dynamic> row) => Branch(
    id: row['id'] as String,
    merchantId: row['merchant_id'] as String,
    name: row['name'] as String,
    address: row['address'] as String?,
    latitude: row['latitude'] != null
        ? (row['latitude'] as num).toDouble()
        : null,
    longitude: row['longitude'] != null
        ? (row['longitude'] as num).toDouble()
        : null,
    phone: row['phone'] as String?,
    isActive: row['is_active'] as bool? ?? true,
    isPrimary: row['is_primary'] as bool? ?? false,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: row['updated_at'] != null
        ? DateTime.parse(row['updated_at'] as String)
        : null,
  );

  Future<List<Branch>> getBranches(String merchantId) async {
    final data = await _client
        .from('branches')
        .select()
        .eq('merchant_id', merchantId)
        .order('is_primary', ascending: false);
    return (data as List)
        .map((r) => _fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<Branch?> getBranchById(String id) async {
    final data = await _client
        .from('branches')
        .select()
        .eq('id', id)
        .maybeSingle();
    return data != null ? _fromRow(data) : null;
  }

  Future<Branch> createBranch(Branch branch) async {
    final data = await _client
        .from('branches')
        .insert({
          'merchant_id': branch.merchantId,
          'name': branch.name,
          'address': branch.address,
          'latitude': branch.latitude,
          'longitude': branch.longitude,
          'phone': branch.phone,
          'is_active': branch.isActive,
          'is_primary': branch.isPrimary,
        })
        .select()
        .single();
    return _fromRow(data);
  }

  Future<Branch> updateBranch(Branch branch) async {
    final data = await _client
        .from('branches')
        .update({
          'name': branch.name,
          'address': branch.address,
          'latitude': branch.latitude,
          'longitude': branch.longitude,
          'phone': branch.phone,
          'is_active': branch.isActive,
          'is_primary': branch.isPrimary,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', branch.id)
        .select()
        .single();
    return _fromRow(data);
  }

  Future<void> deleteBranch(String id) async {
    await _client.from('branches').delete().eq('id', id);
  }
}
