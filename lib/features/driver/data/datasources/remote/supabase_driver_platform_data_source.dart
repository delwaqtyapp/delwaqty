import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/driver/domain/entities/vehicle.dart';
import 'package:delwaqty/features/driver/domain/entities/driver_document.dart';
import 'package:delwaqty/features/driver/domain/entities/wallet_detail.dart';
import 'package:delwaqty/features/driver/domain/entities/driver_performance.dart';

final supabaseDriverPlatformDataSourceProvider =
    Provider<SupabaseDriverPlatformDataSource>((ref) {
  return SupabaseDriverPlatformDataSource(ref.watch(supabaseClientProvider));
});

class SupabaseDriverPlatformDataSource {
  SupabaseDriverPlatformDataSource(this._client);

  final SupabaseClient _client;

  Map<String, dynamic> _checkRpc(dynamic data) {
    final map = Map<String, dynamic>.from(data as Map);
    if (map['success'] == false) {
      throw DriverPlatformException(map['reason'] as String? ?? 'unknown');
    }
    return map;
  }

  // ── Onboarding ──

  Future<void> submitOnboardingStep(
    String driverId, {
    String? fullName,
    String? phone,
    String? nationalId,
    String? address,
    String? profilePhotoUrl,
    required int step,
  }) async {
    _checkRpc(await _client.rpc('submit_driver_onboarding', params: {
      'p_driver_id': driverId,
      if (fullName != null) 'p_full_name': fullName,
      if (phone != null) 'p_phone': phone,
      if (nationalId != null) 'p_national_id': nationalId,
      if (address != null) 'p_address': address,
      if (profilePhotoUrl != null) 'p_profile_photo_url': profilePhotoUrl,
      'p_onboarding_step': step,
    }));
  }

  Future<void> completeOnboarding(String driverId) async {
    _checkRpc(await _client.rpc('complete_driver_onboarding', params: {
      'p_driver_id': driverId,
    }));
  }

  // ── Vehicles ──

  Vehicle _vehicleFromRow(Map<String, dynamic> row) {
    return Vehicle(
      id: row['id'] as String,
      driverId: row['driver_id'] as String,
      category: row['category'] as String? ?? 'economy',
      make: row['make'] as String?,
      model: row['model'] as String?,
      year: row['year'] as int?,
      color: row['color'] as String?,
      plateNumber: row['plate_number'] as String? ?? '',
      seats: row['seats'] as int? ?? 4,
      isActive: row['is_active'] as bool? ?? true,
      isVerified: row['is_verified'] as bool? ?? false,
      photoUrl: row['photo_url'] as String?,
      registrationExpiresAt: row['registration_expires_at'] != null
          ? DateTime.parse(row['registration_expires_at'] as String)
          : null,
      insuranceExpiresAt: row['insurance_expires_at'] != null
          ? DateTime.parse(row['insurance_expires_at'] as String)
          : null,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Future<List<Vehicle>> getVehicles(String driverId) async {
    final rows = await _client
        .from('vehicles')
        .select()
        .eq('driver_id', driverId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => _vehicleFromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<String> addVehicle(
    String driverId, {
    required String category,
    String? make,
    String? model,
    int? year,
    String? color,
    required String plateNumber,
    int seats = 4,
    String? photoUrl,
  }) async {
    final map = _checkRpc(await _client.rpc('add_driver_vehicle', params: {
      'p_driver_id': driverId,
      'p_category': category,
      'p_make': make,
      'p_model': model,
      'p_year': year,
      'p_color': color,
      'p_plate_number': plateNumber,
      'p_seats': seats,
      'p_photo_url': photoUrl,
    }));
    return map['vehicle_id'] as String? ?? '';
  }

  Future<void> updateVehicle(
    String vehicleId,
    String driverId, {
    String? category,
    String? make,
    String? model,
    int? year,
    String? color,
    String? plateNumber,
    int? seats,
    String? photoUrl,
    bool? isActive,
  }) async {
    _checkRpc(await _client.rpc('update_driver_vehicle', params: {
      'p_vehicle_id': vehicleId,
      'p_driver_id': driverId,
      if (category != null) 'p_category': category,
      if (make != null) 'p_make': make,
      if (model != null) 'p_model': model,
      if (year != null) 'p_year': year,
      if (color != null) 'p_color': color,
      if (plateNumber != null) 'p_plate_number': plateNumber,
      if (seats != null) 'p_seats': seats,
      if (photoUrl != null) 'p_photo_url': photoUrl,
      if (isActive != null) 'p_is_active': isActive,
    }));
  }

  Future<void> toggleVehicleActive(String vehicleId, String driverId) async {
    _checkRpc(await _client.rpc('toggle_vehicle_active', params: {
      'p_vehicle_id': vehicleId,
      'p_driver_id': driverId,
    }));
  }

  // ── Documents ──

  DriverDocument _documentFromRow(Map<String, dynamic> row) {
    return DriverDocument(
      id: row['id'] as String,
      driverId: row['driver_id'] as String,
      docType: row['doc_type'] as String? ?? '',
      fileUrl: row['file_url'] as String?,
      fileName: row['file_name'] as String?,
      fileSize: row['file_size'] as int?,
      status: row['status'] as String? ?? 'pending',
      rejectionReason: row['rejection_reason'] as String?,
      expiresAt: row['expires_at'] != null
          ? DateTime.parse(row['expires_at'] as String)
          : null,
      createdAt: DateTime.parse(row['created_at'] as String),
      reviewedAt: row['reviewed_at'] != null
          ? DateTime.parse(row['reviewed_at'] as String)
          : null,
    );
  }

  Future<List<DriverDocument>> getDocuments(String driverId) async {
    final rows = await _client
        .from('driver_documents')
        .select()
        .eq('driver_id', driverId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => _documentFromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<String> upsertDocument(
    String driverId,
    String docType,
    String fileUrl, {
    String? fileName,
    int? fileSize,
    DateTime? expiresAt,
  }) async {
    final map = _checkRpc(await _client.rpc('upsert_driver_document', params: {
      'p_driver_id': driverId,
      'p_doc_type': docType,
      'p_file_url': fileUrl,
      'p_file_name': fileName,
      'p_file_size': fileSize,
      'p_expires_at': expiresAt?.toIso8601String().split('T').first,
    }));
    return map['document_id'] as String? ?? '';
  }

  // ── Wallet ──

  Future<WalletDetail> getWalletDetail(String driverId) async {
    final map = _checkRpc(await _client.rpc('get_driver_wallet_detail', params: {
      'p_driver_id': driverId,
    }));
    return WalletDetail(
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
      bonusBalance: (map['bonus_balance'] as num?)?.toDouble() ?? 0,
      incentiveBalance: (map['incentive_balance'] as num?)?.toDouble() ?? 0,
      pendingWithdrawals: (map['pending_withdrawals'] as num?)?.toDouble() ?? 0,
      totalWithdrawn: (map['total_withdrawn'] as num?)?.toDouble() ?? 0,
      currency: map['currency'] as String? ?? 'EGP',
    );
  }

  // ── Performance ──

  Future<DriverPerformance> getPerformance(String driverId) async {
    final map = _checkRpc(await _client.rpc('get_driver_performance', params: {
      'p_driver_id': driverId,
    }));
    return DriverPerformance(
      totalTrips: (map['total_trips'] as num?)?.toInt() ?? 0,
      completedTrips: (map['completed_trips'] as num?)?.toInt() ?? 0,
      cancelledTrips: (map['cancelled_trips'] as num?)?.toInt() ?? 0,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      acceptanceRate: (map['acceptance_rate'] as num?)?.toDouble() ?? 100,
      cancellationRate: (map['cancellation_rate'] as num?)?.toDouble() ?? 0,
      todayRides: (map['today_rides'] as num?)?.toInt() ?? 0,
      todayEarnings: (map['today_earnings'] as num?)?.toDouble() ?? 0,
      weekEarnings: (map['week_earnings'] as num?)?.toDouble() ?? 0,
      monthEarnings: (map['month_earnings'] as num?)?.toDouble() ?? 0,
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
      bonusBalance: (map['bonus_balance'] as num?)?.toDouble() ?? 0,
      incentiveBalance: (map['incentive_balance'] as num?)?.toDouble() ?? 0,
      pendingWithdrawals: (map['pending_withdrawals'] as num?)?.toDouble() ?? 0,
      currency: map['currency'] as String? ?? 'EGP',
    );
  }
}

class DriverPlatformException implements Exception {
  DriverPlatformException(this.reason);
  final String reason;
  @override
  String toString() => 'DriverPlatformException($reason)';
}
