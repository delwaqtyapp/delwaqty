import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/admin/data/datasources/remote/platform_intelligence_data_source.dart';
import 'package:delwaqty/features/admin/domain/entities/platform_intelligence.dart';

// â”€â”€â”€ Data Source Provider â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final platformIntelligenceDataSourceProvider =
    Provider<PlatformIntelligenceDataSource>((ref) {
  return PlatformIntelligenceDataSource();
});

// â”€â”€â”€ Admin Scope State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final adminScopeRegionProvider = StateProvider<String?>((ref) => null);

// â”€â”€â”€ Time Filter State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

enum AdminTimePeriod { today, week, month, quarter, all }

class AdminTimeFilter {
  const AdminTimeFilter({
    this.period = AdminTimePeriod.all,
    this.from,
    this.to,
  });

  final AdminTimePeriod period;
  final DateTime? from;
  final DateTime? to;

  AdminTimeFilter copyWith({
    AdminTimePeriod? period,
    DateTime? from,
    DateTime? to,
  }) {
    return AdminTimeFilter(
      period: period ?? this.period,
      from: from ?? this.from,
      to: to ?? this.to,
    );
  }

  (DateTime?, DateTime?) get dateRange {
    final now = DateTime.now();
    return switch (period) {
      AdminTimePeriod.today => (
        DateTime(now.year, now.month, now.day),
        now,
      ),
      AdminTimePeriod.week => (
        now.subtract(const Duration(days: 7)),
        now,
      ),
      AdminTimePeriod.month => (
        DateTime(now.year, now.month, 1),
        now,
      ),
      AdminTimePeriod.quarter => (
        DateTime(now.month <= 3 ? now.year - 1 : now.year,
            now.month <= 3 ? 10 + now.month : now.month - 2, 1),
        now,
      ),
      AdminTimePeriod.all => (null, null),
    };
  }
}

final adminTimeFilterProvider =
    StateProvider<AdminTimeFilter>((ref) => const AdminTimeFilter());

// â”€â”€â”€ KPI Summary â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final platformKpiProvider = FutureProvider<PlatformKpiSummary>((ref) async {
  final ds = ref.watch(platformIntelligenceDataSourceProvider);
  final filter = ref.watch(adminTimeFilterProvider);
  final regionId = ref.watch(adminScopeRegionProvider);
  final (from, to) = filter.dateRange;
  return ds.getKpiSummary(from: from, to: to, regionId: regionId);
});

// â”€â”€â”€ Service Performance â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final servicePerformanceProvider = FutureProvider<ServicePerformance>((ref) async {
  final ds = ref.watch(platformIntelligenceDataSourceProvider);
  final filter = ref.watch(adminTimeFilterProvider);
  final (from, to) = filter.dateRange;
  return ds.getServicePerformance(from: from, to: to);
});

// â”€â”€â”€ Delivery Intelligence â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final deliveryIntelligenceProvider = FutureProvider<DeliveryIntelligence>((ref) async {
  final ds = ref.watch(platformIntelligenceDataSourceProvider);
  final filter = ref.watch(adminTimeFilterProvider);
  final (from, to) = filter.dateRange;
  return ds.getDeliveryIntelligence(from: from, to: to);
});

// â”€â”€â”€ Merchant Intelligence â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final merchantIntelligenceProvider = FutureProvider<MerchantIntelligence>((ref) async {
  final ds = ref.watch(platformIntelligenceDataSourceProvider);
  final filter = ref.watch(adminTimeFilterProvider);
  final (from, to) = filter.dateRange;
  return ds.getMerchantIntelligence(from: from, to: to);
});

// â”€â”€â”€ Wallet Intelligence â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final walletIntelligenceProvider = FutureProvider<WalletIntelligence>((ref) async {
  final ds = ref.watch(platformIntelligenceDataSourceProvider);
  final filter = ref.watch(adminTimeFilterProvider);
  final (from, to) = filter.dateRange;
  return ds.getWalletIntelligence(from: from, to: to);
});

// â”€â”€â”€ Provider Intelligence â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final providerIntelligenceProvider = FutureProvider<ProviderIntelligence>((ref) async {
  final ds = ref.watch(platformIntelligenceDataSourceProvider);
  final filter = ref.watch(adminTimeFilterProvider);
  final (from, to) = filter.dateRange;
  return ds.getProviderIntelligence(from: from, to: to);
});

// â”€â”€â”€ Commission Summary â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final commissionSummaryProvider = FutureProvider<CommissionSummary>((ref) async {
  final ds = ref.watch(platformIntelligenceDataSourceProvider);
  final filter = ref.watch(adminTimeFilterProvider);
  final (from, to) = filter.dateRange;
  return ds.getCommissionSummary(from: from, to: to);
});

// â”€â”€â”€ Complaint Summary â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final complaintSummaryProvider = FutureProvider<ComplaintSummary>((ref) async {
  final ds = ref.watch(platformIntelligenceDataSourceProvider);
  final filter = ref.watch(adminTimeFilterProvider);
  final (from, to) = filter.dateRange;
  return ds.getComplaintSummary(from: from, to: to);
});

// â”€â”€â”€ Transaction Ledger â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final transactionLedgerProvider =
    FutureProvider.family<TransactionLedger, ({String? type, String? search, int page})>(
  (ref, params) async {
    final ds = ref.watch(platformIntelligenceDataSourceProvider);
    final filter = ref.watch(adminTimeFilterProvider);
    final (from, to) = filter.dateRange;
    return ds.getTransactionLedger(
      from: from,
      to: to,
      type: params.type,
      search: params.search,
      limit: 50,
      offset: params.page * 50,
    );
  },
);

// â”€â”€â”€ Revenue Overview â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final revenueOverviewProvider =
    FutureProvider.family<RevenueOverview, String?>((ref, period) async {
  final ds = ref.watch(platformIntelligenceDataSourceProvider);
  final filter = ref.watch(adminTimeFilterProvider);
  final (from, to) = filter.dateRange;
  return ds.getRevenueOverview(period: period, from: from, to: to);
});

// â”€â”€â”€ Orders Timeseries â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final ordersTimeseriesProvider = FutureProvider<TimeseriesData>((ref) async {
  final ds = ref.watch(platformIntelligenceDataSourceProvider);
  final filter = ref.watch(adminTimeFilterProvider);
  final (from, to) = filter.dateRange;
  return ds.getOrdersTimeseries(from: from, to: to);
});

// â”€â”€â”€ Rides Timeseries â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final ridesTimeseriesProvider = FutureProvider<TimeseriesData>((ref) async {
  final ds = ref.watch(platformIntelligenceDataSourceProvider);
  final filter = ref.watch(adminTimeFilterProvider);
  final (from, to) = filter.dateRange;
  return ds.getRidesTimeseries(from: from, to: to);
});

// â”€â”€â”€ Operational Alerts â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final operationalAlertsProvider = FutureProvider<List<OperationalAlert>>((ref) async {
  final ds = ref.watch(platformIntelligenceDataSourceProvider);
  return ds.getOperationalAlerts();
});

// â”€â”€â”€ Revenue Breakdown â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final revenueBreakdownProvider = FutureProvider<RevenueOverview>((ref) async {
  final ds = ref.watch(platformIntelligenceDataSourceProvider);
  final filter = ref.watch(adminTimeFilterProvider);
  final (from, to) = filter.dateRange;
  return ds.getRevenueBreakdown(from: from, to: to);
});
