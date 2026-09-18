import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/customer/home/domain/home_domain.dart';
import 'package:delwaqty/features/customer/home/domain/entities/platform_category.dart';
import 'package:delwaqty/features/customer/home/presentation/widgets/category_visuals.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_category.dart';
import 'package:delwaqty/features/customer/home_services/data/repositories/service_booking_repository_impl.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/pressable_scale.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

final _selectedTypeProvider = StateProvider<MerchantType?>((_) => null);

final _bookingServicesProvider = FutureProvider<List<ServiceCategory>>((ref) async {
  final repo = ref.watch(serviceBookingRepositoryProvider);
  return repo.getCategories();
});

class AllServicesPage extends ConsumerWidget {
  const AllServicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final categoriesAsync = ref.watch(activeCategoriesProvider);
    final selectedType = ref.watch(_selectedTypeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.allServices)),
      body: categoriesAsync.when(
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
          onAction: () => ref.invalidate(activeCategoriesProvider),
        ),
        data: (categories) {
          if (categories.isEmpty) {
            return PremiumEmptyState(
              icon: Icons.apps_outlined,
              title: l10n.noResults,
              message: l10n.nearbyEmptyHint,
            );
          }
          final sorted = [...categories]
            ..sort((a, b) => categoryRank(a.name).compareTo(categoryRank(b.name)));

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: AnimatedFadeIn(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      l10n.servicesSection,
                      style: context.textTheme.titleSmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.92,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final category = sorted[index];
                      final merchantType =
                          categoryNameToMerchantType(category.name);
                      final isSelected = selectedType != null &&
                          merchantType == selectedType;
                      final typeColor = merchantType != null
                          ? merchantTypeColor(merchantType)
                          : AppColors.brandPurple;
                      final emoji = merchantType != null
                          ? merchantEmoji(merchantType)
                          : '🏪';

                      return AnimatedFadeIn(
                        delay: Duration(milliseconds: 60 + index * 40),
                        child: PressableTile(
                          onTap: () {
                            ref.read(_selectedTypeProvider.notifier).state =
                                merchantType;
                            final typeParam = merchantType?.name ?? 'other';
                            context.push('/market?type=$typeParam');
                          },
                          color: typeColor,
                          emoji: emoji,
                          label: category.displayName(
                            Directionality.of(context) == TextDirection.rtl,
                          ),
                          isSelected: isSelected,
                          imageUrl: category.imageUrl,
                        ),
                      );
                    },
                    childCount: sorted.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: AnimatedFadeIn(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: () => context.push('/market'),
                        child: Text(l10n.browseMerchants),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: AnimatedFadeIn(
                  delay: const Duration(milliseconds: 100),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      l10n.bookingServices,
                      style: context.textTheme.titleSmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: AnimatedFadeIn(
                  delay: const Duration(milliseconds: 140),
                  child: _BookingServicesSection(
                    servicesAsync: ref.watch(_bookingServicesProvider),
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

class _BookingServicesSection extends ConsumerWidget {
  const _BookingServicesSection({required this.servicesAsync});

  final AsyncValue<List<ServiceCategory>> servicesAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return servicesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: ShimmerCard(height: 160),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (services) {
        if (services.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.nearbyEmptyHint,
              style: context.textTheme.bodySmall,
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 12,
              childAspectRatio: 0.95,
            ),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];
              return AnimatedFadeIn(
                delay: Duration(milliseconds: 140 + index * 40),
                child: PressableScale(
                  onTap: () => context.push(
                    '/home-services/category/${service.type.name}',
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
                              AppColors.serviceHome.withValues(alpha: 0.35),
                              AppColors.brandPurple.withValues(alpha: 0.15),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.serviceHome.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Icon(
                          Icons.home_repair_service_rounded,
                          color: AppColors.serviceHome,
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
          ),
        );
      },
    );
  }
}

class PressableTile extends StatelessWidget {
  const PressableTile({
    super.key,
    required this.onTap,
    required this.color,
    required this.emoji,
    required this.label,
    required this.isSelected,
    this.imageUrl,
  });

  final VoidCallback onTap;
  final Color color;
  final String emoji;
  final String label;
  final bool isSelected;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? color
                  : context.colorScheme.outlineVariant.withValues(alpha: 0.2),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: (imageUrl != null && imageUrl!.isNotEmpty)
                    ? Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _fallback(),
                      )
                    : _fallback(),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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

  Widget _fallback() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.38),
            color.withValues(alpha: 0.15),
          ],
        ),
      ),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}
