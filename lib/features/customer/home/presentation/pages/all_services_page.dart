import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_category.dart';
import 'package:delwaqty/data/repositories/cached_service_booking_repository.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/customer/home_services/presentation/widgets/service_reviews_button.dart';

final _bookingServicesProvider = FutureProvider<List<ServiceCategory>>((ref) async {
  final repo = ref.watch(cachedServiceBookingRepositoryProvider);
  final all = await repo.getCategories();
  const priority = [
    ServiceCategoryType.doctor,
    ServiceCategoryType.nurse,
    ServiceCategoryType.teacher,
    ServiceCategoryType.barber,
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
        loading: () => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 14,
            crossAxisSpacing: 12,
            mainAxisExtent: 132,
          ),
          itemCount: 6,
          itemBuilder: (_, _) => const ShimmerCard(height: 100),
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
                    mainAxisExtent: 132,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final service = services[index];
                      final color = _serviceColor(service.type);
                      final label =
                          Directionality.of(context) == TextDirection.rtl
                              ? service.nameAr
                              : service.nameEn;
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: _ServiceButtonTile(
                              color: color,
                              icon: _serviceIcon(service.type),
                              label: label,
                              onTap: () => context.push(
                                '/home-services/providers/${service.type.name}',
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.88),
                              ),
                              child: ServiceReviewsButton(
                                categoryType: service.type,
                                iconSize: 18,
                                tooltipLabel:
                                    AppLocalizations.of(context).rateService,
                              ),
                            ),
                          ),
                        ],
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

class _ServiceButtonTile extends StatefulWidget {
  const _ServiceButtonTile({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_ServiceButtonTile> createState() => _ServiceButtonTileState();
}

class _ServiceButtonTileState extends State<_ServiceButtonTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final highlightBg = Color.lerp(color, Colors.white, 0.55)!;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _pressed
                  ? [highlightBg, color.withValues(alpha: 0.65)]
                  : [color, Color.lerp(color, Colors.black, 0.22)!],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(
                    alpha: _pressed ? 0.9 : 0.22,
                  ),
                ),
                child: Icon(
                  widget.icon,
                  size: 26,
                  color: _pressed
                      ? Color.lerp(color, Colors.black, 0.35)
                      : Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 20,
                child: Center(
                  child: Text(
                    widget.label,
                    style: AppTextStyles.labelSmall.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _pressed
                          ? Color.lerp(color, Colors.black, 0.55)
                          : Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}