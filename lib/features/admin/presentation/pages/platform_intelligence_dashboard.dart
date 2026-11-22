import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/admin/admin_shell.dart';
import 'package:delwaqty/features/admin/presentation/providers/platform_intelligence_providers.dart';
import 'package:delwaqty/features/admin/domain/entities/platform_intelligence.dart';
import 'package:delwaqty/features/_shared/regions/domain/entities/region.dart';
import 'package:delwaqty/features/_shared/regions/presentation/providers/region_providers.dart';
import 'package:delwaqty/features/_shared/regions/presentation/widgets/region_picker_sheet.dart';
import 'package:delwaqty/features/admin_management/domain/entities/admin_account.dart';
import 'package:delwaqty/features/admin_management/presentation/providers/admin_management_providers.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/floating_glass_buttons.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';

class PlatformIntelligenceDashboard extends ConsumerStatefulWidget {
  const PlatformIntelligenceDashboard({super.key});

  @override
  ConsumerState<PlatformIntelligenceDashboard> createState() =>
      _PlatformIntelligenceDashboardState();
}

class _PlatformIntelligenceDashboardState
    extends ConsumerState<PlatformIntelligenceDashboard> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final filter = ref.watch(adminTimeFilterProvider);
    final kpiAsync = ref.watch(platformKpiProvider);
    final alertsAsync = ref.watch(operationalAlertsProvider);
    final revenueAsync = ref.watch(revenueBreakdownProvider);

    return Scaffold(
      appBar: AppBar(
        leading: MediaQuery.sizeOf(context).width < 1100
            ? const AdminMenuButton()
            : null,
        title: Text(l10n.adminCommandCenter),
        actions: [
          const Center(
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: 6),
              child: FloatingNotificationCircleButton(size: 40),
            ),
          ),
          IconButton(
            tooltip: l10n.adminQuickActions,
            icon: const Icon(Icons.grid_view_rounded),
            onPressed: () => context.push('/admin/actions'),
          ),
          IconButton(
            tooltip: l10n.search,
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push('/admin/members'),
          ),
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(platformKpiProvider);
              ref.invalidate(operationalAlertsProvider);
              ref.invalidate(revenueBreakdownProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(platformKpiProvider);
          ref.invalidate(operationalAlertsProvider);
          ref.invalidate(revenueBreakdownProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedFadeIn(child: _buildScopeRow(context)),
              const SizedBox(height: 12),
              AnimatedFadeIn(child: _buildTimeFilter(filter, cs)),
              const SizedBox(height: 12),
              AnimatedFadeIn(child: _buildExecutiveHubBar(context, cs)),
              const SizedBox(height: 20),
              kpiAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: AppLoaderCircular(),
                  ),
                ),
                error: (e, _) => AnimatedFadeIn(
                  child: PremiumCard(
                    child: PremiumEmptyState(
                      icon: Icons.error_outline_rounded,
                      title: l10n.error,
                      message: l10n.errorLoadingMetrics,
                      actionLabel: l10n.retry,
                      onAction: () => ref.invalidate(platformKpiProvider),
                    ),
                  ),
                ),
                data: (kpi) => _buildKpiGroups(kpi, l10n, cs),
              ),
              const SizedBox(height: 24),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 150),
                child: Text(
                  l10n.revenueOverview,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              revenueAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: AppLoaderCircular(),
                  ),
                ),
                error: (e, _) => AnimatedFadeIn(
                  delay: const Duration(milliseconds: 180),
                  child: PremiumCard(
                    child: PremiumEmptyState(
                      icon: Icons.account_balance_wallet_rounded,
                      title: l10n.error,
                      message: l10n.errorLoadingMetrics,
                      actionLabel: l10n.retry,
                      onAction: () => ref.invalidate(revenueBreakdownProvider),
                    ),
                  ),
                ),
                data: (revenue) => AnimatedFadeIn(
                  delay: const Duration(milliseconds: 180),
                  child: _buildRevenueSection(revenue, l10n, cs),
                ),
              ),
              const SizedBox(height: 24),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 250),
                child: Text(
                  l10n.operationalAlertsTitle,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              alertsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: AppLoaderCircular(),
                  ),
                ),
                error: (e, _) => AnimatedFadeIn(
                  delay: const Duration(milliseconds: 280),
                  child: PremiumCard(
                    child: PremiumEmptyState(
                      icon: Icons.warning_amber_rounded,
                      title: l10n.error,
                      message: l10n.errorLoadingMetrics,
                      actionLabel: l10n.retry,
                      onAction: () => ref.invalidate(operationalAlertsProvider),
                    ),
                  ),
                ),
                data: (alerts) {
                  if (alerts.isEmpty) {
                    return AnimatedFadeIn(
                      delay: const Duration(milliseconds: 280),
                      child: PremiumCard(
                        child: PremiumEmptyState(
                          icon: Icons.check_circle_outline_rounded,
                          title: l10n.noOperationalAlerts,
                          message: l10n.platformHealthy,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (int i = 0; i < alerts.length; i++)
                        AnimatedFadeIn(
                          delay: Duration(milliseconds: 280 + i * 50),
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: i < alerts.length - 1 ? 8 : 0,
                            ),
                            child: _AlertCard(alert: alerts[i], cs: cs),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _regionTypeLabel(RegionType type, AppLocalizations l10n) {
    switch (type) {
      case RegionType.country:
        return l10n.regionCountry;
      case RegionType.governorate:
        return l10n.regionGovernorate;
      case RegionType.markaz:
        return l10n.regionCenter;
      case RegionType.district:
        return l10n.regionDistrict;
      case RegionType.city:
        return l10n.regionCity;
      case RegionType.newCity:
        return l10n.regionNewCity;
      case RegionType.village:
        return l10n.regionVillage;
      case RegionType.area:
        return l10n.regionArea;
    }
  }

  IconData _regionTypeIcon(RegionType type) {
    switch (type) {
      case RegionType.country:
        return Icons.public_rounded;
      case RegionType.governorate:
        return Icons.location_city_rounded;
      case RegionType.markaz:
        return Icons.storefront_rounded;
      case RegionType.district:
        return Icons.domain_rounded;
      case RegionType.city:
      case RegionType.newCity:
        return Icons.apartment_rounded;
      case RegionType.village:
        return Icons.cottage_outlined;
      case RegionType.area:
        return Icons.place_rounded;
    }
  }

  Widget _buildScopeRow(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final rawScopeRegion = ref.watch(adminScopeRegionProvider);
    // 373: scope-gate the selector. Owner/country are unrestricted; scoped
    // admins browse only their assigned subtree(s).
    final adminScope = ref.watch(adminRegionScopeProvider).value;
    final restricted = adminScope != null && !adminScope.unrestricted;
    final rootsAsync = restricted
        ? ref.watch(adminScopeRootsProvider)
        : const AsyncData<List<Region>>(<Region>[]);
    final scopeRegion =
        restricted &&
            rawScopeRegion != null &&
            !adminScope!.covers(rawScopeRegion)
        ? null
        : rawScopeRegion;
    final activeRegionAsync = scopeRegion != null
        ? ref.watch(regionByIdProvider(scopeRegion))
        : const AsyncData<Region?>(null);
    final subRegionsAsync = scopeRegion != null
        ? ref.watch(regionChildrenProvider(scopeRegion))
        : (restricted ? rootsAsync : ref.watch(governoratesProvider));
    final adminsAsync = ref.watch(adminsListProvider);

    final activeRegion = activeRegionAsync.value;
    final subRegions = restricted
        ? (subRegionsAsync.value ?? const <Region>[])
              .where((r) => adminScope!.covers(r.id))
              .toList()
        : subRegionsAsync.value ?? const <Region>[];
    final childRegionIds = subRegions.map((r) => r.id).toSet();

    final allRegionalAdmins = (adminsAsync.value ?? const <AdminAccount>[])
        .where((a) => a.regionId != null && a.regionId!.isNotEmpty)
        .toList();

    final prioritizedAdmins = scopeRegion == null
        ? allRegionalAdmins
        : [
            ...allRegionalAdmins.where(
              (a) =>
                  a.regionId == scopeRegion ||
                  childRegionIds.contains(a.regionId),
            ),
            ...allRegionalAdmins.where(
              (a) =>
                  a.regionId != scopeRegion &&
                  !childRegionIds.contains(a.regionId),
            ),
          ];

    final activeRegionAdmin = scopeRegion == null
        ? null
        : allRegionalAdmins.where((a) => a.regionId == scopeRegion).firstOrNull;

    return PremiumCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1 — Main Region Picker Button
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await RegionPickerSheet.show(
                      context,
                      selectedRegionId: scopeRegion,
                      roots: restricted
                          ? (rootsAsync.value ?? const <Region>[])
                          : null,
                      allowedIds: restricted ? adminScope!.regionIds : null,
                    );
                    if (!mounted) return;
                    if (picked == null) return;
                    ref.read(adminScopeRegionProvider.notifier).state =
                        picked.id.isEmpty ? null : picked.id;
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF5B3DF0).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          activeRegion != null
                              ? _regionTypeIcon(activeRegion.type)
                              : Icons.public_rounded,
                          size: 18,
                          color: const Color(0xFF5B3DF0),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            activeRegion?.nameAr ?? l10n.allGovernorates,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (activeRegion != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5B3DF0)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusFull,
                              ),
                            ),
                            child: Text(
                              _regionTypeLabel(activeRegion.type, l10n),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF5B3DF0),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
              if (scopeRegion != null) ...[
                if (activeRegion?.parentRegionId != null) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: l10n.regions,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        ref.read(adminScopeRegionProvider.notifier).state =
                            activeRegion!.parentRegionId;
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_upward_rounded,
                              size: 16,
                              color: cs.onSecondaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.regions,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: cs.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                Tooltip(
                  message: l10n.allGovernorates,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      ref.read(adminScopeRegionProvider.notifier).state = null;
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: cs.errorContainer.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.public_off_rounded,
                            size: 15,
                            color: cs.onErrorContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.allGovernorates,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: cs.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Row 2 — Sub-Regions Quick Filter Strip
          if (subRegions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.account_tree_rounded,
                  size: 14,
                  color: Color(0xFF0D9488),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '${l10n.regions} (${subRegions.length})',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: subRegions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final place = subRegions[index];
                  return ActionChip(
                    avatar: Icon(
                      _regionTypeIcon(place.type),
                      size: 15,
                      color: const Color(0xFF0D9488),
                    ),
                    label: Text(
                      '${place.nameAr} (${_regionTypeLabel(place.type, l10n)})',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: const Color(0xFF0D9488)
                        .withValues(alpha: 0.09),
                    side: BorderSide(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                    ),
                    onPressed: () {
                      ref.read(adminScopeRegionProvider.notifier).state =
                          place.id;
                    },
                  );
                },
              ),
            ),
          ],

          // Row 3 — Subordinate Admins Supervision Strip
          if (prioritizedAdmins.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.shield_rounded,
                  size: 14,
                  color: Color(0xFF5B3DF0),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '${l10n.adminMgmtList} (${prioritizedAdmins.length})',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: prioritizedAdmins.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final admin = prioritizedAdmins[index];
                  final isCurrentAdminRegion =
                      scopeRegion != null && admin.regionId == scopeRegion;
                  final displayName =
                      (admin.fullName != null &&
                          admin.fullName!.trim().isNotEmpty)
                      ? admin.fullName!.trim()
                      : admin.email;
                  final regionLabel =
                      (admin.regionName != null &&
                          admin.regionName!.trim().isNotEmpty)
                      ? admin.regionName!.trim()
                      : l10n.regions;

                  return FilterChip(
                    selected: isCurrentAdminRegion,
                    showCheckmark: false,
                    avatar: Icon(
                      Icons.verified_user_rounded,
                      size: 15,
                      color: isCurrentAdminRegion
                          ? cs.onPrimary
                          : const Color(0xFF5B3DF0),
                    ),
                    label: Text(
                      '$displayName • $regionLabel',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isCurrentAdminRegion
                            ? cs.onPrimary
                            : cs.onSurface,
                      ),
                    ),
                    selectedColor: const Color(0xFF5B3DF0),
                    backgroundColor: const Color(0xFF5B3DF0)
                        .withValues(alpha: 0.08),
                    side: BorderSide(
                      color: const Color(0xFF5B3DF0).withValues(alpha: 0.25),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                    ),
                    onSelected: (_) {
                      ref.read(adminScopeRegionProvider.notifier).state =
                          admin.regionId;
                    },
                  );
                },
              ),
            ),
            if (activeRegionAdmin != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B3DF0).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF5B3DF0).withValues(alpha: 0.24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.admin_panel_settings_rounded,
                          size: 16,
                          color: Color(0xFF5B3DF0),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${l10n.adminRole}: ${activeRegionAdmin.fullName ?? activeRegionAdmin.email}',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildSupervisionJumpButton(
                          context,
                          label: l10n.adminMembers,
                          icon: Icons.people_rounded,
                          color: const Color(0xFF4A90D9),
                          route: '/admin/members',
                        ),
                        _buildSupervisionJumpButton(
                          context,
                          label: l10n.adminOrdersPage,
                          icon: Icons.receipt_long_rounded,
                          color: const Color(0xFFFF9500),
                          route: '/admin/orders',
                        ),
                        _buildSupervisionJumpButton(
                          context,
                          label: l10n.complaints,
                          icon: Icons.warning_amber_rounded,
                          color: const Color(0xFFFF3B30),
                          route: '/admin/complaints',
                        ),
                        _buildSupervisionJumpButton(
                          context,
                          label: l10n.supportChat,
                          icon: Icons.chat_bubble_rounded,
                          color: const Color(0xFF34C759),
                          route: '/admin/support-chat',
                        ),
                        _buildSupervisionJumpButton(
                          context,
                          label: l10n.adminProfile,
                          icon: Icons.badge_rounded,
                          color: const Color(0xFF5B3DF0),
                          route: '/admin/admins/${activeRegionAdmin.id}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSupervisionJumpButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveHubBar(BuildContext context, ColorScheme cs) {
    final l10n = AppLocalizations.of(context);
    final pills = [
      (
        l10n.adminMembers,
        Icons.people_rounded,
        const Color(0xFF4A90D9),
        '/admin/members',
      ),
      (
        l10n.manageRegions,
        Icons.public_rounded,
        const Color(0xFF0D9488),
        '/admin/regions',
      ),
      (
        l10n.adminBannersTitle,
        Icons.view_carousel_rounded,
        const Color(0xFFAF52DE),
        '/admin/campaigns',
      ),
      (
        l10n.adminOrdersPage,
        Icons.local_shipping_rounded,
        const Color(0xFFFF9500),
        '/admin/orders',
      ),
      (
        l10n.supportChat,
        Icons.chat_bubble_rounded,
        const Color(0xFF34C759),
        '/admin/support-chat',
      ),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pills.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final pill = pills[index];
          return InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            onTap: () => context.push(pill.$4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: pill.$3.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(color: pill.$3.withValues(alpha: 0.28)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(pill.$2, size: 15, color: pill.$3),
                  const SizedBox(width: 6),
                  Text(
                    pill.$1,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKpiGroups(
    PlatformKpiSummary kpi,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    final currency = l10n.currencySymbol;
    final groups = [
      (
        l10n.dashGroupPlatform,
        Icons.dashboard_outlined,
        const Color(0xFF007AFF),
        [
          _KpiItem(
            l10n.kpiTotalUsers,
            kpi.totalUsers.toString(),
            Icons.people_outline_rounded,
            const Color(0xFF4A90D9),
            '/admin/members',
          ),
          _KpiItem(
            l10n.kpiActiveMerchants,
            kpi.activeMerchants.toString(),
            Icons.store_outlined,
            const Color(0xFF34C759),
            '/admin/merchants',
          ),
          _KpiItem(
            l10n.kpiOnlineDrivers,
            kpi.onlineDrivers.toString(),
            Icons.local_shipping_rounded,
            const Color(0xFF007AFF),
            '/admin/drivers',
          ),
          _KpiItem(
            l10n.kpiPendingVerification,
            kpi.pendingVerification.toString(),
            Icons.verified_user_outlined,
            const Color(0xFF8B5CF6),
            '/admin/verifications',
          ),
        ],
      ),
      (
        l10n.dashGroupOperations,
        Icons.settings_outlined,
        const Color(0xFFFF9500),
        [
          _KpiItem(
            l10n.kpiTotalOrders,
            kpi.totalOrders.toString(),
            Icons.receipt_long_rounded,
            const Color(0xFFFF9500),
            '/admin/orders',
          ),
          _KpiItem(
            l10n.kpiActiveDeliveries,
            kpi.activeDeliveries.toString(),
            Icons.directions_bike_rounded,
            const Color(0xFF00C7BE),
            '/admin/deliveries',
          ),
          _KpiItem(
            l10n.kpiOpenComplaints,
            kpi.openComplaints.toString(),
            Icons.warning_amber_rounded,
            const Color(0xFFFF3B30),
            '/admin/complaints',
          ),
          _KpiItem(
            l10n.kpiActiveSanctions,
            kpi.activeSanctions.toString(),
            Icons.gavel_rounded,
            const Color(0xFFFF6482),
            '/admin/sanctions',
          ),
        ],
      ),
      (
        l10n.dashGroupFinancial,
        Icons.account_balance_rounded,
        const Color(0xFF5B3DF0),
        [
          _KpiItem(
            l10n.kpiTotalGmv,
            '$currency ${kpi.totalGmv.toStringAsFixed(0)}',
            Icons.payments_outlined,
            const Color(0xFFAF52DE),
            '/admin/financial-center',
          ),
          _KpiItem(
            l10n.kpiPlatformCommission,
            '$currency ${kpi.platformCommission.toStringAsFixed(0)}',
            Icons.account_balance_rounded,
            const Color(0xFF5B3DF0),
            '/admin/commissions',
          ),
          _KpiItem(
            l10n.kpiWalletLiability,
            '$currency ${kpi.totalWalletLiability.toStringAsFixed(0)}',
            Icons.savings_outlined,
            const Color(0xFF14B8A6),
            '/admin/wallet-intelligence',
          ),
          _KpiItem(
            l10n.kpiPaymentFailures,
            kpi.paymentFailures.toString(),
            Icons.error_outline_rounded,
            const Color(0xFFE65100),
            '/admin/transaction-ledger',
          ),
        ],
      ),
      (
        l10n.dashGroupRisk,
        Icons.security_outlined,
        const Color(0xFFFF3B30),
        [
          _KpiItem(
            l10n.kpiPendingWithdrawals,
            kpi.pendingWithdrawals.toString(),
            Icons.currency_exchange_rounded,
            const Color(0xFF8B5CF6),
            '/admin/financial-center',
          ),
          _KpiItem(
            l10n.kpiCancelledOrders,
            kpi.cancelledOrders.toString(),
            Icons.cancel_outlined,
            const Color(0xFFFF9500),
            '/admin/orders',
          ),
          _KpiItem(
            l10n.kpiPendingOrders,
            kpi.pendingOrders.toString(),
            Icons.hourglass_empty_rounded,
            const Color(0xFF34C759),
            '/admin/orders',
          ),
        ],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int g = 0; g < groups.length; g++)
          Padding(
            padding: EdgeInsets.only(top: g == 0 ? 0 : 16),
            child: _KpiGroup(
              title: groups[g].$1,
              icon: groups[g].$2,
              color: groups[g].$3,
              items: groups[g].$4,
              startDelay: g * 100,
              cs: cs,
            ),
          ),
      ],
    );
  }

  Widget _buildTimeFilter(AdminTimeFilter filter, ColorScheme cs) {
    final l10n = AppLocalizations.of(context);
    final periodLabels = {
      AdminTimePeriod.today: l10n.periodToday,
      AdminTimePeriod.week: l10n.periodWeek,
      AdminTimePeriod.month: l10n.periodMonth,
      AdminTimePeriod.quarter: l10n.periodQuarter,
      AdminTimePeriod.all: l10n.periodAll,
    };
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: AdminTimePeriod.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final period = AdminTimePeriod.values[index];
          final isSelected = filter.period == period;
          return FilterChip(
            label: Text(
              periodLabels[period]!,
              style: TextStyle(
                color: isSelected ? cs.onPrimary : cs.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            selected: isSelected,
            onSelected: (_) {
              ref.read(adminTimeFilterProvider.notifier).state = filter
                  .copyWith(period: period);
            },
            selectedColor: cs.primary,
            backgroundColor: cs.surfaceContainerHighest,
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRevenueSection(
    RevenueOverview revenue,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    final currency = l10n.currencySymbol;
    final items = [
      _RevenueItem(l10n.revenueGmv, revenue.totalGmv, const Color(0xFF5B3DF0)),
      _RevenueItem(
        l10n.revenuePlatformCommission,
        revenue.totalCommission,
        const Color(0xFF34C759),
      ),
      _RevenueItem(
        l10n.revenueDeliveryGmv,
        revenue.commission3pct,
        const Color(0xFFFF6482),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: crossAxisCount >= 3 ? 120 : 136,
          children: items
              .map(
                (item) => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: item.color.withValues(alpha: 0.22),
                      width: 1.2,
                    ),
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                      colors: [
                        item.color.withValues(alpha: 0.12),
                        cs.surfaceContainerLow.withValues(alpha: 0.9),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: item.color.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: item.color.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          color: item.color,
                          size: 16,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$currency ${item.amount.toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _KpiItem {
  const _KpiItem(this.label, this.value, this.icon, this.color, this.route);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String route;
}

class _KpiGroup extends StatelessWidget {
  const _KpiGroup({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    required this.startDelay,
    required this.cs,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<_KpiItem> items;
  final int startDelay;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedFadeIn(
          delay: Duration(milliseconds: startDelay),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 900
                ? 4
                : constraints.maxWidth > 600
                ? 3
                : 2;
            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: crossAxisCount >= 3 ? 128 : 140,
              children: [
                for (int i = 0; i < items.length; i++)
                  AnimatedFadeIn(
                    delay: Duration(milliseconds: startDelay + i * 40),
                    child: _KpiCard(item: items[i], cs: cs),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.item, required this.cs});
  final _KpiItem item;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(item.route),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.color.withValues(alpha: 0.22),
              width: 1.2,
            ),
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                item.color.withValues(alpha: 0.12),
                cs.surfaceContainerLow.withValues(alpha: 0.9),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: item.color.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: item.color.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(item.icon, color: item.color, size: 20),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: item.color.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: item.color,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevenueItem {
  const _RevenueItem(this.label, this.amount, this.color);
  final String label;
  final double amount;
  final Color color;
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.cs});
  final OperationalAlert alert;
  final ColorScheme cs;

  String _targetRoute() {
    final cat = alert.category.toLowerCase();
    final title = alert.title.toLowerCase();
    if (cat.contains('sos') ||
        cat.contains('emerg') ||
        title.contains('sos') ||
        title.contains('emerg')) {
      return '/admin/support-chat';
    }
    if (cat.contains('complaint') ||
        title.contains('complaint') ||
        cat.contains('dispute') ||
        title.contains('dispute')) {
      return '/admin/complaints';
    }
    if (cat.contains('verif') ||
        title.contains('verif') ||
        cat.contains('kyc') ||
        title.contains('kyc')) {
      return '/admin/verifications';
    }
    if (cat.contains('sanction') ||
        title.contains('sanction') ||
        cat.contains('penalty') ||
        title.contains('penalty')) {
      return '/admin/sanctions';
    }
    if (cat.contains('order') || title.contains('order')) {
      return '/admin/orders';
    }
    if (cat.contains('deliver') || title.contains('deliver')) {
      return '/admin/deliveries';
    }
    if (cat.contains('driver') ||
        title.contains('driver') ||
        cat.contains('courier') ||
        title.contains('courier')) {
      return '/admin/drivers';
    }
    if (cat.contains('wallet') ||
        cat.contains('financ') ||
        cat.contains('payment') ||
        title.contains('wallet') ||
        title.contains('financ') ||
        title.contains('pay')) {
      return '/admin/financial-center';
    }
    return '/admin/actions';
  }

  @override
  Widget build(BuildContext context) {
    final severityColor = _severityColor(alert.severity);
    final severityIcon = _severityIcon(alert.severity);
    final route = _targetRoute();

    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(16),
      child: PremiumCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: severityColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(severityIcon, color: severityColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    alert.description,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (alert.count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  alert.count.toString(),
                  style: TextStyle(
                    color: severityColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
      case 'high':
        return const Color(0xFFFF3B30);
      case 'medium':
      case 'warning':
        return const Color(0xFFFF9500);
      case 'low':
      case 'info':
        return const Color(0xFF007AFF);
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData _severityIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
      case 'high':
        return Icons.error_rounded;
      case 'medium':
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'low':
      case 'info':
        return Icons.info_outline_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }
}
