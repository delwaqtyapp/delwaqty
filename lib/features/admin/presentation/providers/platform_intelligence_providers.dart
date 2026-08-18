import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/admin/data/datasources/remote/platform_intelligence_data_source.dart';
import 'package:delwaqty/features/admin/domain/entities/platform_intelligence.dart';

// ─── Data Source Provider ─────────────────────────────────

final platformIntelligenceDataSourceProvider =
    Provider<PlatformIntelligenceDataSource>((ref) {
  return PlatformIntelligenceDataSource();
});

// ─── Time Filter State ────────────────────────────────────

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

// ─── KPI Summary ──────────────────────────────────────────

final platformKpiProvider = FutureProvider<PlatformKpiSummary>((ref) async {
  final ds = ref.watch(platformIntelligenceDataSourceProvider);
  final filter = ref.watch(adminTimeFilterProvider);
  final (from, to) = filter.dateRange;
  return ds.getKpiSummary(from: from, to: to);
});

// ─── Service Performance ──────────────────────────────────

final servicePerformanceProvider = FutureProvider<ServicePerformance>((ref) async {
  final ds = ref.watch(platformIntelligenceDataSourceProvider);
  final filter = ref.watch(adminTimeFilterProvider);
  final (from, to) = filter.dateRange;
  return ds.getServicePerformance(from: from, to: to);
});

// ─── Delivery Intelligence ────────────────────────────────

final deliveryIntelligenceProvider = FutureProvider<DeliveryIntelligence>((ref) async {
  final ds = ref.watch(platformIntelligenceDataSourceProvider);
  final filter = ref.watch(adminTimeFilterProvider);
  final (from, to) = filter.dateRange;
  return ds.getDeliveryIntelligence(from: from, to: to);
});

// ─── Merchant Intelligence ────────────────────────────────

final merchantIntelligenceProvider = FutureProvider<MerchantIntelligence>((ref) async {
  final ds = ref.watch(platformIntelligenceDataSourceProvider);
  final filter = ref.watch(adminTimeFilterProvider);
  final (from, to) = filter.dateRange;
  return ds.getMerchantIntelligence(from: from, to: to);
});

// ─── Wallet Intelligence ──────────────────────────────────

final walletIntelligenceProvider = FutureProvider<WalletIntelligence>((ref) async {
  final ds = ref.watch(platformIntelligenceDataSourceProvider);
  final filter = ref.watch(adminTimeFilterProvider);
  final (from, to) = filter.dateRange;
  return ds.getWalletIntelligence(from: from, to: to);
});

// ─── Provider Intelligence ────────────────────────────────

final providerIntelligenceProvider = FutureProvider<ProviderIntelligence>((ref) async {
  final ds = ref.watch(platformIntelligenceDataSourceProvider);
  final filter = ref.watch(adminTimeFilterProvider);
  final (from, to) = filter.dateRange;
  return ds.getProviderIntelligence(from: from, to: to);
});

// ─── Commission Summary ───────────────────────────────────

final commissionSummaryProvider = FutureProvider<CommissionSummary>((ref) async {
  final ds = ref.watch(platformIntelligenceDataSourceProvider);
  final filter = ref.watch(adminTimeFilterProvider);
  final (from, to) = filter.dateRange;
  return ds.getCommissionSummary(from: from, to: to);
});

// ─── Complaint Summary ────────────────────────────────────

final complaintSummaryProvider = FutureProvider<ComplaintSummary>((ref) async {
  final ds = ref.watch(platformIntelligenceDataSourceProvider);
  final filter = ref.watch(adminTimeFilterProvider);
  final (from, to) = filter.dateRange;
  return ds.getComplaintSummary(from: from, to: to);
});

// ─── Transaction Ledger ───────────────────────────────────

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

// ─── Revenue Overview ─────────────────────────────────────

final revenueOverviewProvider =
    FutureProvider.family<RevenueOverview, String?>((ref, period) async {
  final ds = ref.watch(platformIntelligenceDataSourceProvider);
  final filter = ref.watch(adminTimeFilterProvider);
  final (from, to) = filter.dateRange;
  return ds.getRevenueOverview(period: period, from: from, to: to);
});

// ─── Orders Timeseries ────────────────────────────────────

final ordersTimeseriesProvider = FutureProvider<TimeseriesData>((ref) async {
  final ds = ref.watch(platformIntelligenceDataSourceProvider);
  final filter = ref.watch(adminTimeFilterProvider);
  final (from, to) = filter.dateRange;
  return ds.getOrdersTimeseries(from: from, to: to);
});

// ─── Rides Timeseries ─────────────────────────────────────

final ridesTimeseriesProvider = FutureProvider<TimeseriesData>((ref) async {
  final ds = ref.watch(platformIntelligenceDataSourceProvider);
  final filter = ref.watch(adminTimeFilterProvider);
  final (from, to) = filter.dateRange;
  return ds.getRidesTimeseries(from: from, to: to);
});

// ─── Operational Alerts ───────────────────────────────────

final operationalAlertsProvider = FutureProvider<List<OperationalAlert>>((ref) async {
  final ds = ref.watch(platformIntelligenceDataSourceProvider);
  return ds.getOperationalAlerts();
});

// ─── Revenue Breakdown ────────────────────────────────────

final revenueBreakdownProvider = FutureProvider<RevenueOverview>((ref) async {
  final ds = ref.watch(platformIntelligenceDataSourceProvider);
  final filter = ref.watch(adminTimeFilterProvider);
  final (from, to) = filter.dateRange;
  return ds.getRevenueBreakdown(from: from, to: to);
});
