import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/_shared/regions/domain/entities/region.dart';
import 'package:delwaqty/features/_shared/regions/presentation/providers/region_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Browsable, cascading region picker (governorate -> markaz/district ->
/// village/area) shared by the customer app and the admin tools.
///
/// Shows a breadcrumb trail, a virtualized list at the current depth and two
/// affordances per row:
///   * tapping the row BODY drills into a region's children, or selects it
///     directly when it has none;
///   * the trailing check button always selects the region itself.
/// The widget stays stateless about the outcome: [onSelected] is invoked and
/// the parent decides what to persist (ADRs 057 / 127 pattern).
class RegionBrowser extends ConsumerStatefulWidget {
  const RegionBrowser({
    super.key,
    required this.onSelected,
    this.selectedRegionId,
    this.roots,
    this.allowedIds,
  });

  final void Function(Region region) onSelected;
  final String? selectedRegionId;

  /// When set, the top level lists these regions instead of all
  /// governorates (scoped admin pickers start at their assigned regions).
  final List<Region>? roots;

  /// When set, regions outside this set render disabled (not selectable,
  /// not drillable). Applied by scoped admin pickers.
  final Set<String>? allowedIds;

  @override
  ConsumerState<RegionBrowser> createState() => _RegionBrowserState();
}

class _RegionBrowserState extends ConsumerState<RegionBrowser> {
  final List<Region> _crumbs = [];
  String? _openingId;

  String _displayName(Region region) {
    final language = Localizations.localeOf(context).languageCode;
    return region.displayName(language);
  }

  IconData _typeIcon(Region region) {
    switch (region.type) {
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

  String _typeLabel(Region region, AppLocalizations l10n) {
    switch (region.type) {
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

  bool _isAllowed(Region region) =>
      widget.allowedIds == null || widget.allowedIds!.contains(region.id);

  Future<void> _openOrSelect(Region region) async {
    if (_openingId != null) return;
    if (!_isAllowed(region)) return;
    setState(() => _openingId = region.id);
    try {
      final children = await ref.read(regionChildrenProvider(region.id).future);
      if (!mounted) return;
      if (children.isNotEmpty) {
        setState(() => _crumbs.add(region));
      } else {
        widget.onSelected(region);
      }
    } catch (_) {
      if (mounted) widget.onSelected(region);
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  Widget _buildRow(BuildContext context, WidgetRef ref, Region region) {
    final l10n = AppLocalizations.of(context);
    final isCurrent = region.id == widget.selectedRegionId;
    final opening = _openingId == region.id;
    final allowed = _isAllowed(region);
    return ListTile(
      key: ValueKey('region-row-${region.id}'),
      enabled: allowed,
      leading: Icon(
        _typeIcon(region),
        color: allowed ? _typeColor(region) : Theme.of(context).disabledColor,
      ),
      title: Text(
        _displayName(region),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      // Actions wrap below so the region name keeps the full tile width.
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_typeLabel(region, l10n)),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: l10n.selectPlace,
                  icon: Icon(
                    isCurrent
                        ? Icons.check_circle_rounded
                        : Icons.check_circle_outline,
                    color: isCurrent
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                  onPressed: opening || !allowed
                      ? null
                      : () => widget.onSelected(region),
                ),
                if (opening)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ],
      ),
      onTap: opening || !allowed ? null : () => _openOrSelect(region),
    );
  }

  Color _typeColor(Region region) {
    switch (region.type) {
      case RegionType.governorate:
        return const Color(0xFF6D28D9);
      case RegionType.markaz:
        return const Color(0xFF0D9488);
      case RegionType.village:
        return const Color(0xFF65A30D);
      case RegionType.area:
        return const Color(0xFFB45309);
      case RegionType.newCity:
      case RegionType.city:
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _buildBreadcrumb(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 46,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            ActionChip(
              avatar: Icon(
                widget.roots == null
                    ? Icons.public_rounded
                    : Icons.home_work_outlined,
                size: 16,
              ),
              label: Text(widget.roots == null ? l10n.allOfEgypt : l10n.back),
              onPressed: _crumbs.isEmpty ? null : () => setState(_crumbs.clear),
            ),
            for (var i = 0; i < _crumbs.length; i++) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Icon(Icons.chevron_right_rounded, size: 16),
              ),
              ActionChip(
                avatar: Icon(_typeIcon(_crumbs[i]), size: 16),
                label: Text(_displayName(_crumbs[i])),
                onPressed: i == _crumbs.length - 1
                    ? null
                    : () => setState(
                        () => _crumbs.removeRange(i + 1, _crumbs.length),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final childrenAsync = _crumbs.isEmpty
        ? (widget.roots != null
              ? AsyncData<List<Region>>(widget.roots!)
              : ref.watch(governoratesProvider))
        : ref.watch(regionChildrenProvider(_crumbs.last.id));

    return Column(
      children: [
        _buildBreadcrumb(context),
        const Divider(height: 1),
        Expanded(
          child: childrenAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.regionSelectionFailed),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () {
                      if (_crumbs.isEmpty && widget.roots == null) {
                        ref.invalidate(governoratesProvider);
                      } else if (_crumbs.isEmpty) {
                        setState(() {});
                      } else {
                        ref.invalidate(regionChildrenProvider(_crumbs.last.id));
                      }
                    },
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
            data: (regions) {
              if (regions.isEmpty) {
                return Center(child: Text(l10n.subRegionsEmpty));
              }
              return ListView.separated(
                itemCount: regions.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) =>
                    _buildRow(context, ref, regions[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}
