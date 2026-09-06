import 'package:freezed_annotation/freezed_annotation.dart';

part 'platform_intelligence.freezed.dart';
part 'platform_intelligence.g.dart';

@freezed
abstract class PlatformKpiSummary with _$PlatformKpiSummary {
  const factory PlatformKpiSummary({
    @Default(0) int totalUsers,
    @Default(0) int customers,
    @Default(0) int providers,
    @Default(0) int deliveryUsers,
    @Default(0) int merchantUsers,
    @Default(0) int driverUsers,
    @Default(0) int pendingVerification,
    @Default(0) int verifiedMembers,
    @Default(0) int newToday,
    @Default(0) int newThisWeek,
    @Default(0) int thisMonth,
    @Default(0) int newUsersPeriod,
    @Default(0) int totalDrivers,
    @Default(0) int onlineDrivers,
    @Default(0) int verifiedDrivers,
    @Default(0) int totalMerchants,
    @Default(0) int activeMerchants,
    @Default([]) List<TypeCount> merchantsByType,
    @Default(0) int totalOrders,
    @Default(0) int ordersToday,
    @Default(0) int ordersThisWeek,
    @Default(0) int ordersThisMonth,
    @Default(0) int completedOrders,
    @Default(0) int pendingOrders,
    @Default(0) int cancelledOrders,
    @Default(0) int totalRides,
    @Default(0) int completedRides,
    @Default(0) int activeRides,
    @Default(0) int totalDeliveries,
    @Default(0) int completedDeliveries,
    @Default(0) int activeDeliveries,
    @Default(0) int totalServiceBookings,
    @Default(0) int completedServiceBookings,
    @Default(0.0) double totalGmv,
    @Default(0.0) double rideGmv,
    @Default(0.0) double deliveryGmv,
    @Default(0.0) double serviceGmv,
    @Default(0.0) double platformCommission,
    @Default(0.0) double driverEarningsTotal,
    @Default(0.0) double totalWalletLiability,
    @Default(0.0) double commission7pct,
    @Default(0.0) double commission3pct,
    @Default(0) int openComplaints,
    @Default(0) int escalatedComplaints,
    @Default(0) int activeSanctions,
    @Default(0) int sosActive,
    @Default(0) int pendingWithdrawals,
    @Default(0) int paymentFailures,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) = _PlatformKpiSummary;

  factory PlatformKpiSummary.fromJson(Map<String, dynamic> json) =>
      PlatformKpiSummary(
        totalUsers: json['total_users'] as int? ?? 0,
        customers: json['customers'] as int? ?? 0,
        providers: json['providers'] as int? ?? 0,
        deliveryUsers: json['delivery_users'] as int? ?? 0,
        merchantUsers: json['merchant_users'] as int? ?? 0,
        driverUsers: json['driver_users'] as int? ?? 0,
        pendingVerification: json['pending_verification'] as int? ?? 0,
        verifiedMembers: json['verified_members'] as int? ?? 0,
        newToday: json['new_today'] as int? ?? 0,
        newThisWeek: json['new_this_week'] as int? ?? 0,
        thisMonth: json['this_month'] as int? ?? 0,
        newUsersPeriod: json['new_users_period'] as int? ?? 0,
        totalDrivers: json['total_drivers'] as int? ?? 0,
        onlineDrivers: json['online_drivers'] as int? ?? 0,
        verifiedDrivers: json['verified_drivers'] as int? ?? 0,
        totalMerchants: json['total_merchants'] as int? ?? 0,
        activeMerchants: json['active_merchants'] as int? ?? 0,
        merchantsByType: (json['merchants_by_type'] as List<dynamic>?)
                ?.map((e) => TypeCount.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        totalOrders: json['total_orders'] as int? ?? 0,
        ordersToday: json['orders_today'] as int? ?? 0,
        ordersThisWeek: json['orders_this_week'] as int? ?? 0,
        ordersThisMonth: json['orders_this_month'] as int? ?? 0,
        completedOrders: json['completed_orders'] as int? ?? 0,
        pendingOrders: json['pending_orders'] as int? ?? 0,
        cancelledOrders: json['cancelled_orders'] as int? ?? 0,
        totalRides: json['total_rides'] as int? ?? 0,
        completedRides: json['completed_rides'] as int? ?? 0,
        activeRides: json['active_rides'] as int? ?? 0,
        totalDeliveries: json['total_deliveries'] as int? ?? 0,
        completedDeliveries: json['completed_deliveries'] as int? ?? 0,
        activeDeliveries: json['active_deliveries'] as int? ?? 0,
        totalServiceBookings: json['total_service_bookings'] as int? ?? 0,
        completedServiceBookings:
            json['completed_service_bookings'] as int? ?? 0,
        totalGmv: (json['total_gmv'] as num?)?.toDouble() ?? 0.0,
        rideGmv: (json['ride_gmv'] as num?)?.toDouble() ?? 0.0,
        deliveryGmv: (json['delivery_gmv'] as num?)?.toDouble() ?? 0.0,
        serviceGmv: (json['service_gmv'] as num?)?.toDouble() ?? 0.0,
        platformCommission:
            (json['platform_commission'] as num?)?.toDouble() ?? 0.0,
        driverEarningsTotal:
            (json['driver_earnings_total'] as num?)?.toDouble() ?? 0.0,
        totalWalletLiability:
            (json['total_wallet_liability'] as num?)?.toDouble() ?? 0.0,
        commission7pct: (json['commission_7pct'] as num?)?.toDouble() ?? 0.0,
        commission3pct: (json['commission_3pct'] as num?)?.toDouble() ?? 0.0,
        openComplaints: json['open_complaints'] as int? ?? 0,
        escalatedComplaints: json['escalated_complaints'] as int? ?? 0,
        activeSanctions: json['active_sanctions'] as int? ?? 0,
        sosActive: json['sos_active'] as int? ?? 0,
        pendingWithdrawals: json['pending_withdrawals'] as int? ?? 0,
        paymentFailures: json['payment_failures'] as int? ?? 0,
        dateFrom: json['date_from'] != null
            ? DateTime.parse(json['date_from'] as String)
            : null,
        dateTo: json['date_to'] != null
            ? DateTime.parse(json['date_to'] as String)
            : null,
      );
}

@freezed
abstract class TypeCount with _$TypeCount {
  const factory TypeCount({
    @Default('') String type,
    @Default(0) int count,
  }) = _TypeCount;

  factory TypeCount.fromJson(Map<String, dynamic> json) => TypeCount(
        type: json['type'] as String? ?? '',
        count: json['count'] as int? ?? 0,
      );
}

@freezed
abstract class ServicePerformance with _$ServicePerformance {
  const factory ServicePerformance({
    @Default([]) List<ServiceCategoryPerformance> homeServices,
    @Default([]) List<ServiceCategoryPerformance> rideServices,
    @Default([]) List<ServiceCategoryPerformance> deliveryServices,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) = _ServicePerformance;

  factory ServicePerformance.fromJson(Map<String, dynamic> json) =>
      ServicePerformance(
        homeServices: (json['home_services'] as List<dynamic>?)
                ?.map((e) =>
                    ServiceCategoryPerformance.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        rideServices: (json['ride_services'] as List<dynamic>?)
                ?.map((e) =>
                    ServiceCategoryPerformance.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        deliveryServices: (json['delivery_services'] as List<dynamic>?)
                ?.map((e) =>
                    ServiceCategoryPerformance.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        dateFrom: json['date_from'] != null
            ? DateTime.parse(json['date_from'] as String)
            : null,
        dateTo: json['date_to'] != null
            ? DateTime.parse(json['date_to'] as String)
            : null,
      );
}

@freezed
abstract class ServiceCategoryPerformance with _$ServiceCategoryPerformance {
  const factory ServiceCategoryPerformance({
    @Default('') String category,
    @Default(0) int totalBookings,
    @Default(0) int completedBookings,
    @Default(0.0) double avgRating,
    @Default(0.0) double totalRevenue,
  }) = _ServiceCategoryPerformance;

  factory ServiceCategoryPerformance.fromJson(Map<String, dynamic> json) =>
      ServiceCategoryPerformance(
        category: json['category'] as String? ?? '',
        totalBookings: json['total_bookings'] as int? ?? 0,
        completedBookings: json['completed_bookings'] as int? ?? 0,
        avgRating: (json['avg_rating'] as num?)?.toDouble() ?? 0.0,
        totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      );
}

@freezed
abstract class DeliveryIntelligence with _$DeliveryIntelligence {
  const factory DeliveryIntelligence({
    @Default(0) int totalDrivers,
    @Default(0) int onlineDrivers,
    @Default(0) int pendingDrivers,
    @Default(0) int verifiedDrivers,
    @Default(0.0) double deliveryGmv,
    @Default(0.0) double driverEarningsTotal,
    @Default(0) int completedDeliveries,
    @Default(0) int pendingDeliveries,
    @Default(0) int cancelledDeliveries,
    @Default(0) int pendingWithdrawals,
    @Default(0) int paidWithdrawals,
    @Default(0.0) double pendingWithdrawalAmount,
    @Default(0.0) double paidWithdrawalAmount,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) = _DeliveryIntelligence;

  factory DeliveryIntelligence.fromJson(Map<String, dynamic> json) =>
      DeliveryIntelligence(
        totalDrivers: json['total_drivers'] as int? ?? 0,
        onlineDrivers: json['online_drivers'] as int? ?? 0,
        pendingDrivers: json['pending_drivers'] as int? ?? 0,
        verifiedDrivers: json['verified_drivers'] as int? ?? 0,
        deliveryGmv: (json['delivery_gmv'] as num?)?.toDouble() ?? 0.0,
        driverEarningsTotal:
            (json['driver_earnings_total'] as num?)?.toDouble() ?? 0.0,
        completedDeliveries: json['completed_deliveries'] as int? ?? 0,
        pendingDeliveries: json['pending_deliveries'] as int? ?? 0,
        cancelledDeliveries: json['cancelled_deliveries'] as int? ?? 0,
        pendingWithdrawals: json['pending_withdrawals'] as int? ?? 0,
        paidWithdrawals: json['paid_withdrawals'] as int? ?? 0,
        pendingWithdrawalAmount:
            (json['pending_withdrawal_amount'] as num?)?.toDouble() ?? 0.0,
        paidWithdrawalAmount:
            (json['paid_withdrawal_amount'] as num?)?.toDouble() ?? 0.0,
        dateFrom: json['date_from'] != null
            ? DateTime.parse(json['date_from'] as String)
            : null,
        dateTo: json['date_to'] != null
            ? DateTime.parse(json['date_to'] as String)
            : null,
      );
}

@freezed
abstract class MerchantIntelligence with _$MerchantIntelligence {
  const factory MerchantIntelligence({
    @Default(0) int totalMerchants,
    @Default(0) int activeMerchants,
    @Default([]) List<TypeCount> merchantsByType,
    @Default([]) List<MerchantInfo> merchants,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) = _MerchantIntelligence;

  factory MerchantIntelligence.fromJson(Map<String, dynamic> json) =>
      MerchantIntelligence(
        totalMerchants: json['total_merchants'] as int? ?? 0,
        activeMerchants: json['active_merchants'] as int? ?? 0,
        merchantsByType: (json['merchants_by_type'] as List<dynamic>?)
                ?.map((e) => TypeCount.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        merchants: (json['merchants'] as List<dynamic>?)
                ?.map((e) =>
                    MerchantInfo.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        dateFrom: json['date_from'] != null
            ? DateTime.parse(json['date_from'] as String)
            : null,
        dateTo: json['date_to'] != null
            ? DateTime.parse(json['date_to'] as String)
            : null,
      );
}

@freezed
abstract class MerchantInfo with _$MerchantInfo {
  const factory MerchantInfo({
    @Default('') String id,
    @Default('') String name,
    @Default('') String type,
    @Default('') String status,
    @Default(0.0) double rating,
    @Default(0) int totalOrders,
  }) = _MerchantInfo;

  factory MerchantInfo.fromJson(Map<String, dynamic> json) => MerchantInfo(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        type: json['type'] as String? ?? '',
        status: json['status'] as String? ?? '',
        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
        totalOrders: json['total_orders'] as int? ?? 0,
      );
}

@freezed
abstract class WalletIntelligence with _$WalletIntelligence {
  const factory WalletIntelligence({
    @Default(0) int walletCount,
    @Default(0) int totalTransactions,
    @Default(0.0) double totalLiability,
    @Default(0.0) double avgBalance,
    @Default([]) List<TypeCount> transactionsByType,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) = _WalletIntelligence;

  factory WalletIntelligence.fromJson(Map<String, dynamic> json) =>
      WalletIntelligence(
        walletCount: json['wallet_count'] as int? ?? 0,
        totalTransactions: json['total_transactions'] as int? ?? 0,
        totalLiability: (json['total_liability'] as num?)?.toDouble() ?? 0.0,
        avgBalance: (json['avg_balance'] as num?)?.toDouble() ?? 0.0,
        transactionsByType: (json['transactions_by_type'] as List<dynamic>?)
                ?.map((e) => TypeCount.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        dateFrom: json['date_from'] != null
            ? DateTime.parse(json['date_from'] as String)
            : null,
        dateTo: json['date_to'] != null
            ? DateTime.parse(json['date_to'] as String)
            : null,
      );
}

@freezed
abstract class ProviderIntelligence with _$ProviderIntelligence {
  const factory ProviderIntelligence({
    @Default(0) int totalProviders,
    @Default(0) int verifiedProviders,
    @Default(0) int availableProviders,
    @Default([]) List<TypeCount> bookingsByCategory,
    @Default([]) List<TypeCount> providersByCategory,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) = _ProviderIntelligence;

  factory ProviderIntelligence.fromJson(Map<String, dynamic> json) =>
      ProviderIntelligence(
        totalProviders: json['total_providers'] as int? ?? 0,
        verifiedProviders: json['verified_providers'] as int? ?? 0,
        availableProviders: json['available_providers'] as int? ?? 0,
        bookingsByCategory: (json['bookings_by_category'] as List<dynamic>?)
                ?.map((e) => TypeCount.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        providersByCategory: (json['providers_by_category'] as List<dynamic>?)
                ?.map((e) => TypeCount.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        dateFrom: json['date_from'] != null
            ? DateTime.parse(json['date_from'] as String)
            : null,
        dateTo: json['date_to'] != null
            ? DateTime.parse(json['date_to'] as String)
            : null,
      );
}

@freezed
abstract class CommissionSummary with _$CommissionSummary {
  const factory CommissionSummary({
    @Default(0.0) double totalCommission,
    @Default(0.0) double pendingCommission,
    @Default(0.0) double fulfilledCommission,
    @Default([]) List<CommissionRule> activeRules,
    @Default([]) List<CommissionByRate> commissionByRate,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) = _CommissionSummary;

  factory CommissionSummary.fromJson(Map<String, dynamic> json) =>
      CommissionSummary(
        totalCommission:
            (json['total_commission'] as num?)?.toDouble() ?? 0.0,
        pendingCommission:
            (json['pending_commission'] as num?)?.toDouble() ?? 0.0,
        fulfilledCommission:
            (json['fulfilled_commission'] as num?)?.toDouble() ?? 0.0,
        activeRules: (json['active_rules'] as List<dynamic>?)
                ?.map((e) =>
                    CommissionRule.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        commissionByRate: (json['commission_by_rate'] as List<dynamic>?)
                ?.map((e) =>
                    CommissionByRate.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        dateFrom: json['date_from'] != null
            ? DateTime.parse(json['date_from'] as String)
            : null,
        dateTo: json['date_to'] != null
            ? DateTime.parse(json['date_to'] as String)
            : null,
      );
}

@freezed
abstract class CommissionRule with _$CommissionRule {
  const factory CommissionRule({
    @Default(0.0) double rate,
    @Default('') String currency,
    @Default('') String entityKey,
    @Default('') String entityType,
  }) = _CommissionRule;

  factory CommissionRule.fromJson(Map<String, dynamic> json) =>
      CommissionRule(
        rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
        currency: json['currency'] as String? ?? '',
        entityKey: json['entity_key'] as String? ?? '',
        entityType: json['entity_type'] as String? ?? '',
      );
}

@freezed
abstract class CommissionByRate with _$CommissionByRate {
  const factory CommissionByRate({
    @Default(0.0) double rate,
    @Default(0) int count,
    @Default(0.0) double totalAmount,
  }) = _CommissionByRate;

  factory CommissionByRate.fromJson(Map<String, dynamic> json) =>
      CommissionByRate(
        rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
        count: json['count'] as int? ?? 0,
        totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      );
}

@freezed
abstract class ComplaintSummary with _$ComplaintSummary {
  const factory ComplaintSummary({
    @Default(0) int totalComplaints,
    @Default(0) int openComplaints,
    @Default(0) int resolvedComplaints,
    @Default(0) int escalatedComplaints,
    @Default(0) int escalationEvents,
    @Default([]) List<StatusCount> complaintsByStatus,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) = _ComplaintSummary;

  factory ComplaintSummary.fromJson(Map<String, dynamic> json) =>
      ComplaintSummary(
        totalComplaints: json['total_complaints'] as int? ?? 0,
        openComplaints: json['open_complaints'] as int? ?? 0,
        resolvedComplaints: json['resolved_complaints'] as int? ?? 0,
        escalatedComplaints: json['escalated_complaints'] as int? ?? 0,
        escalationEvents: json['escalation_events'] as int? ?? 0,
        complaintsByStatus: (json['complaints_by_status'] as List<dynamic>?)
                ?.map((e) =>
                    StatusCount.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        dateFrom: json['date_from'] != null
            ? DateTime.parse(json['date_from'] as String)
            : null,
        dateTo: json['date_to'] != null
            ? DateTime.parse(json['date_to'] as String)
            : null,
      );
}

@freezed
abstract class StatusCount with _$StatusCount {
  const factory StatusCount({
    @Default('') String status,
    @Default(0) int count,
  }) = _StatusCount;

  factory StatusCount.fromJson(Map<String, dynamic> json) => StatusCount(
        status: json['status'] as String? ?? '',
        count: json['count'] as int? ?? 0,
      );
}

@freezed
abstract class TransactionLedger with _$TransactionLedger {
  const factory TransactionLedger({
    @Default(0) int total,
    @Default(0) int page,
    @Default(0) int pageSize,
    @Default(0) int totalPages,
    @Default([]) List<TransactionLedgerItem> items,
  }) = _TransactionLedger;

  factory TransactionLedger.fromJson(Map<String, dynamic> json) =>
      TransactionLedger(
        total: json['total'] as int? ?? 0,
        page: json['page'] as int? ?? 0,
        pageSize: json['page_size'] as int? ?? 0,
        totalPages: json['total_pages'] as int? ?? 0,
        items: (json['items'] as List<dynamic>?)
                ?.map((e) =>
                    TransactionLedgerItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

@freezed
abstract class TransactionLedgerItem with _$TransactionLedgerItem {
  const factory TransactionLedgerItem({
    @Default('') String id,
    @Default('') String memberId,
    @Default('') String referenceType,
    @Default('') String referenceId,
    @Default(0.0) double grossAmount,
    @Default(0.0) double commissionRate,
    @Default(0.0) double commissionAmount,
    @Default(0.0) double netAmount,
    @Default('') String currency,
    @Default('') String status,
    DateTime? createdAt,
  }) = _TransactionLedgerItem;

  factory TransactionLedgerItem.fromJson(Map<String, dynamic> json) =>
      TransactionLedgerItem(
        id: json['id'] as String? ?? '',
        memberId: json['member_id'] as String? ?? '',
        referenceType: json['reference_type'] as String? ?? '',
        referenceId: json['reference_id'] as String? ?? '',
        grossAmount: (json['gross_amount'] as num?)?.toDouble() ?? 0.0,
        commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 0.0,
        commissionAmount:
            (json['commission_amount'] as num?)?.toDouble() ?? 0.0,
        netAmount: (json['net_amount'] as num?)?.toDouble() ?? 0.0,
        currency: json['currency'] as String? ?? '',
        status: json['status'] as String? ?? '',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
      );
}

@freezed
abstract class RevenueOverview with _$RevenueOverview {
  const factory RevenueOverview({
    String? period,
    @Default(0.0) double totalGmv,
    @Default(0) int refundCount,
    @Default(0.0) double commission3pct,
    @Default(0.0) double commission7pct,
    @Default(0.0) double totalCommission,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) = _RevenueOverview;

  factory RevenueOverview.fromJson(Map<String, dynamic> json) =>
      RevenueOverview(
        period: json['period'] as String?,
        totalGmv: (json['total_gmv'] as num?)?.toDouble() ?? 0.0,
        refundCount: json['refund_count'] as int? ?? 0,
        commission3pct: (json['commission_3pct'] as num?)?.toDouble() ?? 0.0,
        commission7pct: (json['commission_7pct'] as num?)?.toDouble() ?? 0.0,
        totalCommission:
            (json['total_commission'] as num?)?.toDouble() ?? 0.0,
        dateFrom: json['date_from'] != null
            ? DateTime.parse(json['date_from'] as String)
            : null,
        dateTo: json['date_to'] != null
            ? DateTime.parse(json['date_to'] as String)
            : null,
      );
}

@freezed
abstract class TimeseriesData with _$TimeseriesData {
  const factory TimeseriesData({
    @Default([]) List<DailyMetric> ordersByDay,
    @Default([]) List<DailyMetric> ridesByDay,
    @Default([]) List<DailyMetric> deliveriesByDay,
    @Default([]) List<StatusCount> ordersByStatus,
    @Default([]) List<StatusCount> ridesByStatus,
    @Default([]) List<StatusCount> deliveriesByStatus,
    @Default([]) List<StatusCount> serviceBookingsByStatus,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) = _TimeseriesData;

  factory TimeseriesData.fromJson(Map<String, dynamic> json) =>
      TimeseriesData(
        ordersByDay: (json['orders_by_day'] as List<dynamic>?)
                ?.map((e) =>
                    DailyMetric.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        ridesByDay: (json['rides_by_day'] as List<dynamic>?)
                ?.map((e) =>
                    DailyMetric.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        deliveriesByDay: (json['deliveries_by_day'] as List<dynamic>?)
                ?.map((e) =>
                    DailyMetric.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        ordersByStatus: (json['orders_by_status'] as List<dynamic>?)
                ?.map((e) =>
                    StatusCount.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        ridesByStatus: (json['rides_by_status'] as List<dynamic>?)
                ?.map((e) =>
                    StatusCount.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        deliveriesByStatus: (json['deliveries_by_status'] as List<dynamic>?)
                ?.map((e) =>
                    StatusCount.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        serviceBookingsByStatus:
            (json['service_bookings_by_status'] as List<dynamic>?)
                    ?.map((e) =>
                        StatusCount.fromJson(e as Map<String, dynamic>))
                    .toList() ??
                const [],
        dateFrom: json['date_from'] != null
            ? DateTime.parse(json['date_from'] as String)
            : null,
        dateTo: json['date_to'] != null
            ? DateTime.parse(json['date_to'] as String)
            : null,
      );
}

@freezed
abstract class DailyMetric with _$DailyMetric {
  const factory DailyMetric({
    DateTime? date,
    @Default(0) int count,
    @Default(0.0) double revenue,
  }) = _DailyMetric;

  factory DailyMetric.fromJson(Map<String, dynamic> json) => DailyMetric(
        date: json['date'] != null
            ? DateTime.parse(json['date'] as String)
            : null,
        count: json['count'] as int? ?? 0,
        revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
      );
}

@freezed
abstract class OperationalAlert with _$OperationalAlert {
  const factory OperationalAlert({
    @Default('') String id,
    @Default('') String title,
    @Default('') String description,
    @Default('') String severity,
    @Default('') String category,
    @Default(0) int count,
    DateTime? detectedAt,
  }) = _OperationalAlert;

  factory OperationalAlert.fromJson(Map<String, dynamic> json) =>
      OperationalAlert(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        severity: json['severity'] as String? ?? '',
        category: json['category'] as String? ?? '',
        count: json['count'] as int? ?? 0,
        detectedAt: json['detected_at'] != null
            ? DateTime.parse(json['detected_at'] as String)
            : null,
      );
}
