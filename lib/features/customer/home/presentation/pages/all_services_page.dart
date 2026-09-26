import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/features/customer/home/domain/entities/platform_category.dart';
import 'package:delwaqty/features/customer/home/domain/home_domain.dart';
import 'package:delwaqty/features/customer/home/presentation/widgets/category_visuals.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_category.dart';
import 'package:delwaqty/data/repositories/cached_service_booking_repository.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/pressable_scale.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

sealed class _GridItem {
  const _GridItem();
}

class _PlatformGridItem extends _GridItem {
  const _PlatformGridItem(this.category);
  final PlatformCategory category;
}

class _BookingGridItem extends _GridItem {
  const _BookingGridItem(this.service);
  final ServiceCategory service;
}

final _allCategoriesProvider = FutureProvider<List<_GridItem>>((ref) async {
  List<PlatformCategory> platformCategories = const [];
  try {
    platformCategories = await ref.watch(activeCategoriesProvider.future);
  } catch (_) {
    platformCategories = const [];
  }
  final sortedPlatform = [...platformCategories]
    ..sort((a, b) => categoryRank(a.name).compareTo(categoryRank(b.name)));

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

  final sortedServices = [...all]..sort((a, b) => rank(a.type).compareTo(rank(b.type)));

  return [
    for (final c in sortedPlatform) _PlatformGridItem(c),
    for (final s in sortedServices) _BookingGridItem(s),
  ];
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

class AllServicesPage extends ConsumerWidget {
  const AllServicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final servicesAsync = ref.watch(_allCategoriesProvider);

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
          onAction: () => ref.invalidate(_allCategoriesProvider),
        ),
        data: (items) {
          final platformItems = items.whereType<_PlatformGridItem>().toList();
          final bookingItems = items.whereType<_BookingGridItem>().toList();
          if (platformItems.isEmpty && bookingItems.isEmpty) {
            return PremiumEmptyState(
              icon: Icons.apps_outlined,
              title: l10n.noResults,
              message: l10n.nearbyEmptyHint,
            );
          }
          return CustomScrollView(
            slivers: [
              if (platformItems.isNotEmpty) ...[
                _sectionHeader(context, l10n.mainCategories),
                _gridSliver(platformItems, (index) {
                  final item = platformItems[index];
                  return _buildPlatformTile(context, item.category);
                }),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
              ],
              if (bookingItems.isNotEmpty) ...[
                _sectionHeader(context, l10n.bookingServices),
                _gridSliver(bookingItems, (index) {
                  final item = bookingItems[index];
                  final rtl = Directionality.of(context) == TextDirection.rtl;
                  final label = rtl ? item.service.nameAr : item.service.nameEn;
                  return _buildServiceTile(
                    context,
                    icon: _serviceIcon(item.service.type),
                    label: label,
                    onTap: () => context.push(
                      '/home-services/providers/${item.service.type.name}',
                    ),
                  );
                }),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return SliverToBoxAdapter(
      child: AnimatedFadeIn(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            title,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _gridSliver(
    List<_GridItem> items,
    Widget Function(int index) builder,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 14,
          crossAxisSpacing: 12,
          mainAxisExtent: 132,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => builder(index),
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildPlatformTile(BuildContext context, PlatformCategory category) {
    final merchantType = categoryNameToMerchantType(category.name);
    final emoji = merchantType != null ? merchantEmoji(merchantType) : '🏪';
    final label = category.displayName(
      Directionality.of(context) == TextDirection.rtl,
    );
    return _SimpleGridTile(
      label: label,
      imageUrl: category.imageUrl,
      emoji: emoji,
      onTap: () {
        final typeParam = merchantType?.name ?? 'other';
        context.push('/market?type=$typeParam');
      },
    );
  }

  Widget _buildServiceTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return _SimpleGridTile(label: label, icon: icon, onTap: onTap);
  }
}

class _SimpleGridTile extends StatelessWidget {
  const _SimpleGridTile({
    required this.label,
    required this.onTap,
    this.icon,
    this.imageUrl,
    this.emoji,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final String? imageUrl;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PressableScale(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.surfaceContainerLow.withValues(alpha: 0.6),
              ),
              child: _buildIcon(context),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 20,
              child: Center(
                child: Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
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
    );
  }

  Widget _buildIcon(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (icon != null) {
      return Center(child: Icon(icon, size: 26, color: cs.onSurfaceVariant));
    }
    if (imageUrl != null) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _emojiWidget(),
      );
    }
    return _emojiWidget();
  }

  Widget _emojiWidget() {
    return Center(child: Text(emoji ?? '🏪', style: const TextStyle(fontSize: 22)));
  }
}