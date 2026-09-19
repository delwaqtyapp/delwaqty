import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_category.dart';
import 'package:delwaqty/data/repositories/cached_service_booking_repository.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/pressable_scale.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

final _bookingServicesProvider = FutureProvider<List<ServiceCategory>>((ref) async {
  final repo = ref.watch(cachedServiceBookingRepositoryProvider);
  final all = await repo.getCategories();
  const priority = [
    ServiceCategoryType.doctor,
    ServiceCategoryType.nurse,
    ServiceCategoryType.teacher,
    ServiceCategoryType.barber,
    ServiceCategoryType.deliveryCar,
    ServiceCategoryType.plumbing,
    ServiceCategoryType.electrical,
    ServiceCategoryType.carpentry,
    ServiceCategoryType.painting,
    ServiceCategoryType.cleaning,
    ServiceCategoryType.acMaintenance,
    ServiceCategoryType.pipeChange,
    ServiceCategoryType.plastering,
    ServiceCategoryType.carpetCleaning,
    ServiceCategoryType.dishRepair,
    ServiceCategoryType.pestControl,
    ServiceCategoryType.applianceRepair,
  ];
  int rank(ServiceCategoryType t) {
    final i = priority.indexOf(t);
    return i == -1 ? priority.length : i;
  }

  final sorted = [...all]..sort((a, b) => rank(a.type).compareTo(rank(b.type)));
  return sorted;
});

IconData _serviceIcon(ServiceCategoryType t) => switch (t) {
      ServiceCategoryType.doctor => Icons.medical_services_rounded,
      ServiceCategoryType.nurse => Icons.health_and_safety_rounded,
      ServiceCategoryType.teacher => Icons.school_rounded,
      ServiceCategoryType.barber => Icons.content_cut_rounded,
      ServiceCategoryType.deliveryCar => Icons.local_taxi_rounded,
      ServiceCategoryType.plumbing => Icons.plumbing_rounded,
      ServiceCategoryType.electrical => Icons.electrical_services_rounded,
      ServiceCategoryType.carpentry => Icons.carpenter_rounded,
      ServiceCategoryType.painting => Icons.format_paint_rounded,
      ServiceCategoryType.cleaning => Icons.cleaning_services_rounded,
      ServiceCategoryType.acMaintenance => Icons.ac_unit_rounded,
      ServiceCategoryType.pipeChange => Icons.settings_input_component_rounded,
      ServiceCategoryType.plastering => Icons.format_color_fill_rounded,
      ServiceCategoryType.carpetCleaning => Icons.local_laundry_service_rounded,
      ServiceCategoryType.dishRepair => Icons.satellite_alt_rounded,
      ServiceCategoryType.pestControl => Icons.bug_report_rounded,
      ServiceCategoryType.applianceRepair => Icons.build_rounded,
      ServiceCategoryType.other => Icons.home_repair_service_rounded,
    };

Color _serviceColor(ServiceCategoryType t) => switch (t) {
      ServiceCategoryType.doctor => AppColors.errorLight,
      ServiceCategoryType.nurse => AppColors.successLight,
      ServiceCategoryType.teacher => AppColors.infoLight,
      ServiceCategoryType.barber => AppColors.brandViolet,
      ServiceCategoryType.deliveryCar => AppColors.serviceDelivery,
      ServiceCategoryType.plumbing => AppColors.serviceHome,
      ServiceCategoryType.electrical => AppColors.serviceElectronics,
      ServiceCategoryType.carpentry => AppColors.serviceBakery,
      ServiceCategoryType.painting => AppColors.serviceFashion,
      ServiceCategoryType.cleaning => AppColors.serviceDelivery,
      ServiceCategoryType.acMaintenance => AppColors.serviceSeafood,
      ServiceCategoryType.pipeChange => AppColors.serviceGrocery,
      ServiceCategoryType.plastering => AppColors.serviceFurniture,
      ServiceCategoryType.carpetCleaning => AppColors.serviceCafe,
      ServiceCategoryType.dishRepair => AppColors.serviceElectronics,
      ServiceCategoryType.pestControl => AppColors.serviceGas,
      ServiceCategoryType.applianceRepair => AppColors.serviceAppliances,
      ServiceCategoryType.other => AppColors.serviceMore,
    };

class AllServicesPage extends ConsumerWidget {
  const AllServicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final servicesAsync = ref.watch(_bookingServicesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.allServices)),
      body: servicesAsync.when(
        loading: () => GridView.count(
          crossAxisCount: 3,
          padding: const EdgeInsets.all(16),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: const [
            ShimmerCard(height: 100),
            ShimmerCard(height: 100),
            ShimmerCard(height: 100),
            ShimmerCard(height: 100),
            ShimmerCard(height: 100),
            ShimmerCard(height: 100),
          ],
        ),
        error: (_, _) => PremiumEmptyState(
          icon: Icons.error_outline_rounded,
          title: l10n.error,
          message: l10n.errorLoading,
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(_bookingServicesProvider),
        ),
        data: (services) {
          if (services.isEmpty) {
            return PremiumEmptyState(
              icon: Icons.apps_outlined,
              title: l10n.noResults,
              message: l10n.nearbyEmptyHint,
            );
          }
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: AnimatedFadeIn(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      l10n.bookingServices,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.92,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final service = services[index];
                      final color = _serviceColor(service.type);
                      return AnimatedFadeIn(
                        delay: Duration(milliseconds: 120 + index * 40),
                        child: PressableScale(
                          onTap: () => context.push(
                            service.type == ServiceCategoryType.deliveryCar
                                ? '/home-services/cars'
                                : '/home-services/providers/${service.type.name}',
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      color.withValues(alpha: 0.35),
                                      color.withValues(alpha: 0.15),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Icon(
                                  _serviceIcon(service.type),
                                  color: color,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                Directionality.of(context) == TextDirection.rtl
                                    ? service.nameAr
                                    : service.nameEn,
                                style: AppTextStyles.labelSmall.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: services.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }
}