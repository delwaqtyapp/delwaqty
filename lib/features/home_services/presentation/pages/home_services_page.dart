import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/features/home_services/domain/entities/service_category.dart';
import 'package:delwaqty/features/home_services/data/repositories/service_booking_repository_impl.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';

final _categoriesProvider = FutureProvider<List<ServiceCategory>>((ref) async {
  final repo = ref.watch(serviceBookingRepositoryProvider);
  return repo.getCategories();
});

class HomeServicesPage extends ConsumerWidget {
  const HomeServicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final categoriesAsync = ref.watch(_categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.homeServices,
          style: context.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_categoriesProvider),
        child: categoriesAsync.when(
          loading: () => _buildLoadingSkeleton(context),
          error: (_, __) => PremiumEmptyState(
            icon: Icons.error_outline,
            title: l10n.error,
            message: l10n.errorLoading,
          ),
          data: (categories) {
            if (categories.isEmpty) {
              return PremiumEmptyState(
                icon: Icons.home_repair_service_outlined,
                title: l10n.noResults,
                message: l10n.nearbyEmptyHint,
              );
            }
            return _buildCategoryGrid(context, categories);
          },
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.2,
        ),
        itemCount: 8,
        itemBuilder: (_, __) => const ShimmerCard(height: 120),
      ),
    );
  }

  Widget _buildCategoryGrid(BuildContext context, List<ServiceCategory> categories) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.2,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return _CategoryCard(
            category: category,
            onTap: () => context.push(
              '/home-services/category/${category.type.name}',
            ),
          );
        },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onTap});

  final ServiceCategory category;
  final VoidCallback onTap;

  Color _categoryColor() => switch (category.type) {
    ServiceCategoryType.plumbing => AppColors.serviceHome,
    ServiceCategoryType.electrical => AppColors.serviceElectronics,
    ServiceCategoryType.carpentry => AppColors.serviceBakery,
    ServiceCategoryType.acMaintenance => AppColors.serviceSeafood,
    ServiceCategoryType.painting => AppColors.serviceFashion,
    ServiceCategoryType.cleaning => AppColors.serviceDelivery,
    ServiceCategoryType.pestControl => AppColors.serviceGas,
    ServiceCategoryType.applianceRepair => AppColors.serviceAppliances,
    ServiceCategoryType.other => AppColors.serviceMore,
  };

  IconData _categoryIcon() => switch (category.type) {
    ServiceCategoryType.plumbing => Icons.plumbing_rounded,
    ServiceCategoryType.electrical => Icons.electrical_services_rounded,
    ServiceCategoryType.carpentry => Icons.carpenter_rounded,
    ServiceCategoryType.acMaintenance => Icons.ac_unit_rounded,
    ServiceCategoryType.painting => Icons.format_paint_rounded,
    ServiceCategoryType.cleaning => Icons.cleaning_services_rounded,
    ServiceCategoryType.pestControl => Icons.bug_report_rounded,
    ServiceCategoryType.applianceRepair => Icons.build_rounded,
    ServiceCategoryType.other => Icons.home_repair_service_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor();
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final name = isRtl ? category.nameAr : category.nameEn;

    return AnimatedFadeIn(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.38),
                      color.withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Icon(_categoryIcon(), color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
