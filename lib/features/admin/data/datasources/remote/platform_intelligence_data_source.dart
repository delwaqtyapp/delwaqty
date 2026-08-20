import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/admin/domain/entities/platform_intelligence.dart';

class PlatformIntelligenceDataSource {
  PlatformIntelligenceDataSource({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<PlatformKpiSummary> getKpiSummary({
    DateTime? from,
    DateTime? to,
    String? regionId,
  }) async {
    final response = await _supabase.rpc('platform_kpi_summary', params: {
      'p_from': from?.toIso8601String(),
      'p_to': to?.toIso8601String(),
      'p_region_id': regionId,
    });
    final data = _unwrapResponse(response, 'platform_kpi_summary');
    return PlatformKpiSummary.fromJson(data);
  }

  Future<ServicePerformance> getServicePerformance({
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _supabase.rpc('platform_service_performance', params: {
      'p_from': from?.toIso8601String(),
      'p_to': to?.toIso8601String(),
    });
    final data = _unwrapResponse(response, 'platform_service_performance');
    return ServicePerformance.fromJson(data);
  }

  Future<DeliveryIntelligence> getDeliveryIntelligence({
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _supabase.rpc('platform_delivery_intelligence', params: {
      'p_from': from?.toIso8601String(),
      'p_to': to?.toIso8601String(),
    });
    final data = _unwrapResponse(response, 'platform_delivery_intelligence');
    return DeliveryIntelligence.fromJson(data);
  }

  Future<MerchantIntelligence> getMerchantIntelligence({
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _supabase.rpc('platform_merchant_intelligence', params: {
      'p_from': from?.toIso8601String(),
      'p_to': to?.toIso8601String(),
    });
    final data = _unwrapResponse(response, 'platform_merchant_intelligence');
    return MerchantIntelligence.fromJson(data);
  }

  Future<WalletIntelligence> getWalletIntelligence({
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _supabase.rpc('platform_wallet_intelligence', params: {
      'p_from': from?.toIso8601String(),
      'p_to': to?.toIso8601String(),
    });
    final data = _unwrapResponse(response, 'platform_wallet_intelligence');
    return WalletIntelligence.fromJson(data);
  }

  Future<ProviderIntelligence> getProviderIntelligence({
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _supabase.rpc('platform_provider_intelligence', params: {
      'p_from': from?.toIso8601String(),
      'p_to': to?.toIso8601String(),
    });
    final data = _unwrapResponse(response, 'platform_provider_intelligence');
    return ProviderIntelligence.fromJson(data);
  }

  Future<CommissionSummary> getCommissionSummary({
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _supabase.rpc('platform_commission_summary', params: {
      'p_from': from?.toIso8601String(),
      'p_to': to?.toIso8601String(),
    });
    final data = _unwrapResponse(response, 'platform_commission_summary');
    return CommissionSummary.fromJson(data);
  }

  Future<ComplaintSummary> getComplaintSummary({
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _supabase.rpc('platform_complaint_summary', params: {
      'p_from': from?.toIso8601String(),
      'p_to': to?.toIso8601String(),
    });
    final data = _unwrapResponse(response, 'platform_complaint_summary');
    return ComplaintSummary.fromJson(data);
  }

  Future<TransactionLedger> getTransactionLedger({
    DateTime? from,
    DateTime? to,
    String? type,
    String? memberId,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _supabase.rpc('platform_transaction_ledger', params: {
      'p_from': from?.toIso8601String(),
      'p_to': to?.toIso8601String(),
      'p_type': type,
      'p_member_id': memberId,
      'p_search': search,
      'p_limit': limit,
      'p_offset': offset,
    });
    final data = _unwrapResponse(response, 'platform_transaction_ledger');
    return TransactionLedger.fromJson(data);
  }

  Future<RevenueOverview> getRevenueOverview({
    String? period,
    String? serviceCategory,
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _supabase.rpc('platform_revenue_overview', params: {
      'p_period': period,
      'p_service_category': serviceCategory,
      'p_from': from?.toIso8601String(),
      'p_to': to?.toIso8601String(),
    });
    final data = _unwrapResponse(response, 'platform_revenue_overview');
    return RevenueOverview.fromJson(data);
  }

  Future<TimeseriesData> getOrdersTimeseries({
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _supabase.rpc('platform_orders_timeseries', params: {
      'p_from': from?.toIso8601String(),
      'p_to': to?.toIso8601String(),
    });
    final data = _unwrapResponse(response, 'platform_orders_timeseries');
    return TimeseriesData.fromJson(data);
  }

  Future<TimeseriesData> getRidesTimeseries({
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _supabase.rpc('platform_rides_timeseries', params: {
      'p_from': from?.toIso8601String(),
      'p_to': to?.toIso8601String(),
    });
    final data = _unwrapResponse(response, 'platform_rides_timeseries');
    return TimeseriesData.fromJson(data);
  }

  Future<List<OperationalAlert>> getOperationalAlerts() async {
    final response = await _supabase.rpc('platform_operational_alerts');
    if (response is List) {
      return response
          .map((e) => OperationalAlert.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();
    }
    return [];
  }

  Future<RevenueOverview> getRevenueBreakdown({
    DateTime? from,
    DateTime? to,
    String? regionId,
  }) async {
    final response = await _supabase.rpc('platform_revenue_breakdown', params: {
      'p_from': from?.toIso8601String(),
      'p_to': to?.toIso8601String(),
      'p_region_id': regionId,
    });
    final data = _unwrapResponse(response, 'platform_revenue_breakdown');
    return RevenueOverview.fromJson(data);
  }

  Map<String, dynamic> _unwrapResponse(dynamic response, String key) {
    if (response is List && response.isNotEmpty) {
      final first = response.first;
      if (first is Map<String, dynamic> && first.containsKey(key)) {
        return Map<String, dynamic>.from(first[key] as Map);
      } else {
        return Map<String, dynamic>.from(first as Map);
      }
    } else if (response is Map<String, dynamic>) {
      return response;
    } else {
      return {};
    }
  }
}
