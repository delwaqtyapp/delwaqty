import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_category.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_provider.dart';
import 'package:delwaqty/features/customer/home_services/data/repositories/service_booking_repository_impl.dart';
import 'package:delwaqty/features/customer/home_services/presentation/widgets/service_reviews_button.dart';
import 'package:delwaqty/features/customer/location/presentation/providers/location_provider.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

final _providersForTypeProvider =
    FutureProvider.family<List<ServiceProvider>, ServiceCategoryType>(
  (ref, type) async {
    final repo = ref.watch(serviceBookingRepositoryProvider);
    return repo.getProviders(categoryType: type);
  },
);

class ServiceProvidersPage extends ConsumerStatefulWidget {
  const ServiceProvidersPage({super.key, this.initialType});

  final ServiceCategoryType? initialType;

  @override
  ConsumerState<ServiceProvidersPage> createState() =>
      _ServiceProvidersPageState();
}

class _ServiceProvidersPageState extends ConsumerState<ServiceProvidersPage> {
  late ServiceCategoryType _type =
      widget.initialType ?? ServiceCategoryType.plumbing;
  double _radiusKm = 10;

  static const _radiusOptions = <double>[5, 10, 15, 25];

  double _distanceKm(ServiceProvider p, double? uLat, double? uLng) {
    if (uLat == null || uLng == null) return 0;
    if (p.latitude == null || p.longitude == null) return double.infinity;
    const r = 6371.0;
    final dLat = _toRad(p.latitude! - uLat);
    final dLng = _toRad(p.longitude! - uLng);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRad(uLat)) *
            math.cos(_toRad(p.latitude!)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  double _toRad(double deg) => deg * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final location = ref.watch(userLocationProvider).value;
    final uLat = location?.latitude;
    final uLng = location?.longitude;
    final providersAsync = ref.watch(_providersForTypeProvider(_type));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.servicesSection),
        actions: [
          ServiceReviewsButton(categoryType: _type),
        ],
      ),
      body: Column(
        children: [
          _buildCategoryBar(l10n),
          _buildRadiusBar(l10n),
          Expanded(
            child: providersAsync.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: 5,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, _) => const ShimmerCard(),
              ),
              error: (_, _) => PremiumEmptyState(
                icon: Icons.error_outline,
                title: l10n.error,
                message: l10n.errorLoading,
              ),
              data: (providers) {
                final visible = providers
                    .where((p) =>
                        _distanceKm(p, uLat, uLng) <= _radiusKm)
                    .toList()
                  ..sort((a, b) => _distanceKm(a, uLat, uLng)
                      .compareTo(_distanceKm(b, uLat, uLng)));
                if (visible.isEmpty) {
                  return PremiumEmptyState(
                    icon: Icons.person_search_rounded,
                    title: l10n.noProvidersFound,
                    message: l10n.noProvidersNearby,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final provider = visible[index];
                    final dist = _distanceKm(provider, uLat, uLng);
                    return AnimatedFadeIn(
                      delay: Duration(milliseconds: index * 50),
                      child: _ProviderCard(
                        provider: provider,
                        distanceKm: dist,
                        onTap: () => context.push(
                          '/home-services/category/${_type.name}',
                          extra: provider,
                        ),
                        onReviewsTap: () => context.push(
                          '/home-services/reviews/${_type.name}',
                          extra: provider,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar(AppLocalizations l10n) {
    final categories = ServiceCategoryType.values
        .where((t) => t != ServiceCategoryType.other)
        .toList();
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final type = categories[index];
          final selected = type == _type;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: ChoiceChip(
              label: Text(_categoryLabel(type)),
              selected: selected,
              onSelected: (_) => setState(() => _type = type),
              avatar: Icon(_categoryIcon(type), size: 16),
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
            ),
          );
        },
      ),
    );
  }

  Widget _buildRadiusBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(
            l10n.searchRadius,
            style: AppTextStyles.labelLarge,
          ),
          const SizedBox(width: 8),
          for (final r in _radiusOptions)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text('$r ${l10n.km}'),
                selected: _radiusKm == r,
                onSelected: (_) => setState(() => _radiusKm = r),
              ),
            ),
        ],
      ),
    );
  }

  String _categoryLabel(ServiceCategoryType type) => switch (type) {
        ServiceCategoryType.plumbing => 'سباكة',
        ServiceCategoryType.electrical => 'كهرباء',
        ServiceCategoryType.carpentry => 'نجارة',
        ServiceCategoryType.acMaintenance => 'صيانة تكييف',
        ServiceCategoryType.painting => 'دهان',
        ServiceCategoryType.cleaning => 'تنظيف',
        ServiceCategoryType.pestControl => 'مكافحة حشرات',
        ServiceCategoryType.applianceRepair => 'إصلاح أجهزة',
        ServiceCategoryType.pipeChange => 'تغيير أنبوبة',
        ServiceCategoryType.plastering => 'نقاشة',
        ServiceCategoryType.carpetCleaning => 'غسيل السجاد',
        ServiceCategoryType.dishRepair => 'إصلاح الدش',
        ServiceCategoryType.teacher => 'مدرسين',
        ServiceCategoryType.doctor => 'حجز دكتور',
        ServiceCategoryType.nurse => 'ممرض',
        ServiceCategoryType.barber => 'حجز حلاق',
        ServiceCategoryType.other => 'أخرى',
      };

  IconData _categoryIcon(ServiceCategoryType type) => switch (type) {
        ServiceCategoryType.plumbing => Icons.plumbing_rounded,
        ServiceCategoryType.electrical => Icons.electrical_services_rounded,
        ServiceCategoryType.carpentry => Icons.carpenter_rounded,
        ServiceCategoryType.acMaintenance => Icons.ac_unit_rounded,
        ServiceCategoryType.painting => Icons.format_paint_rounded,
        ServiceCategoryType.cleaning => Icons.cleaning_services_rounded,
        ServiceCategoryType.pestControl => Icons.bug_report_rounded,
        ServiceCategoryType.applianceRepair => Icons.build_rounded,
        ServiceCategoryType.pipeChange => Icons.settings_input_component_rounded,
        ServiceCategoryType.plastering => Icons.format_color_fill_rounded,
        ServiceCategoryType.carpetCleaning => Icons.local_laundry_service_rounded,
        ServiceCategoryType.dishRepair => Icons.satellite_alt_rounded,
        ServiceCategoryType.teacher => Icons.school_rounded,
        ServiceCategoryType.doctor => Icons.medical_services_rounded,
        ServiceCategoryType.nurse => Icons.health_and_safety_rounded,
        ServiceCategoryType.barber => Icons.content_cut_rounded,
        ServiceCategoryType.other => Icons.home_repair_service_rounded,
      };
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.provider,
    required this.distanceKm,
    required this.onTap,
    required this.onReviewsTap,
  });

  final ServiceProvider provider;
  final double distanceKm;
  final VoidCallback onTap;
  final VoidCallback onReviewsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: provider.profileImageUrl != null
                    ? Image.network(
                        provider.profileImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _avatarFallback(context, provider.name),
                      )
                    : _avatarFallback(context, provider.name),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            provider.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (provider.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded,
                              size: 16, color: AppColors.brandPurple),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 15, color: AppColors.rating),
                        const SizedBox(width: 2),
                        Text(
                          provider.rating.toStringAsFixed(1),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (distanceKm.isFinite) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.place_outlined,
                              size: 14, color: cs.onSurfaceVariant),
                          const SizedBox(width: 2),
                          Text(
                            '${distanceKm.toStringAsFixed(1)} ${AppLocalizations.of(context).km}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (provider.hourlyRate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${provider.hourlyRate!.toStringAsFixed(0)} ${AppLocalizations.of(context).currencySymbol}/${AppLocalizations.of(context).perHour}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ServiceReviewsButton(
                categoryType: provider.categoryType,
                tooltipLabel:
                    AppLocalizations.of(context).rateService,
                onPressedOverride: onReviewsTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback(BuildContext context, String name) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        name.isNotEmpty ? name.characters.first : '?',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: cs.primary,
        ),
      ),
    );
  }
}