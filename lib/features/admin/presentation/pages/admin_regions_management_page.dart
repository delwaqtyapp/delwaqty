import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/features/_shared/regions/domain/entities/region.dart';
import 'package:delwaqty/features/_shared/regions/presentation/providers/region_providers.dart';
import 'package:delwaqty/features/_shared/regions/presentation/widgets/region_picker_sheet.dart';
import 'package:delwaqty/features/admin/admin_shell.dart';
import 'package:delwaqty/features/admin/presentation/providers/platform_intelligence_providers.dart';
import 'package:delwaqty/features/customer/location/presentation/widgets/smart_map_picker_sheet.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';

class AdminRegionsManagementPage extends ConsumerStatefulWidget {
  const AdminRegionsManagementPage({super.key});

  @override
  ConsumerState<AdminRegionsManagementPage> createState() =>
      _AdminRegionsManagementPageState();
}

class _AdminRegionsManagementPageState
    extends ConsumerState<AdminRegionsManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  final List<Region> _crumbs = [];
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Region? get _currentParent => _crumbs.isEmpty ? null : _crumbs.last;

  // 373: scope-gate region editing. Owner/country unrestricted.
  //  374 review (#44): scoped admins are READ-ONLY here — no edit/add
  // affordances at all. Server-side scope stays enforced by
  // admin_upsert_region; this is the UI contract only.
  // Fail closed while scope is loading or failed to load (#44 residual):
  // null scope means "not known yet", not "unrestricted".
  bool _canEditRegion(AdminRegionScope? scope, Region region) =>
      scope != null && scope.unrestricted;

  bool _canAddUnder(AdminRegionScope? scope, Region? parent) {
    return scope != null && scope.unrestricted;
  }

  Future<void> _openUpsertSheet({Region? existing, Region? parent}) async {
    final targetParent = parent ?? _currentParent;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          _RegionUpsertSheet(existing: existing, parent: targetParent),
    );
    if (saved == true) {
      ref.invalidate(governoratesProvider);
      if (targetParent != null) {
        ref.invalidate(regionChildrenProvider(targetParent.id));
      }
      if (existing != null) {
        ref.invalidate(regionChildrenProvider(existing.id));
      }
      if (_query.length >= 2) {
        ref.invalidate(regionSearchProvider(_query));
      }
    }
  }

  String _typeLabel(RegionType t, AppLocalizations l10n) => switch (t) {
    RegionType.country => l10n.regionCountry,
    RegionType.governorate => l10n.regionGovernorate,
    RegionType.markaz => l10n.regionCenter,
    RegionType.district => l10n.regionDistrict,
    RegionType.city => l10n.regionCity,
    RegionType.newCity => l10n.regionNewCity,
    RegionType.village => l10n.regionVillage,
    RegionType.area => l10n.regionArea,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        leading: MediaQuery.sizeOf(context).width < 1100
            ? const AdminMenuButton()
            : null,
        title: Text(l10n.manageRegions),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              if (_crumbs.isEmpty) {
                ref.invalidate(governoratesProvider);
              } else {
                ref.invalidate(regionChildrenProvider(_crumbs.last.id));
              }
            },
          ),
        ],
      ),
      floatingActionButton:
          _canAddUnder(
            ref.watch(adminRegionScopeProvider).value,
            _currentParent,
          )
          // FittedBox scales the extended FAB down on narrow screens so
          // a long localized label never clips at the screen edge.
          // Constrain to the screen width so a long localized label
          // scales down instead of clipping at the right edge.
          ? ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width - 32,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: FloatingActionButton.extended(
                  onPressed: () => _openUpsertSheet(parent: _currentParent),
                  icon: const Icon(Icons.add_location_alt_rounded),
                  label: Text(l10n.addSubRegion),
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        tooltip: l10n.clear,
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          if (_query.length < 2 && _crumbs.isNotEmpty)
            _buildBreadcrumbs(lang, l10n),
          Expanded(
            child: _query.length >= 2
                ? _buildSearchList(lang, l10n)
                : _buildHierarchyList(lang, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbs(String lang, AppLocalizations l10n) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ActionChip(
            avatar: const Icon(Icons.public_rounded, size: 16),
            label: Text(l10n.regionGovernorate),
            onPressed: () => setState(() => _crumbs.clear()),
          ),
          for (var i = 0; i < _crumbs.length; i++) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.chevron_right_rounded, size: 18),
            ),
            ActionChip(
              label: Text(_crumbs[i].displayName(lang)),
              onPressed: i == _crumbs.length - 1
                  ? null
                  : () => setState(
                      () => _crumbs.removeRange(i + 1, _crumbs.length),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHierarchyList(String lang, AppLocalizations l10n) {
    final parent = _currentParent;
    final scope = ref.watch(adminRegionScopeProvider).value;
    final restricted = scope != null && !scope.unrestricted;
    final asyncRegions = parent == null
        ? (restricted
              ? ref.watch(adminScopeRootsProvider)
              : ref.watch(governoratesProvider))
        : ref.watch(regionChildrenProvider(parent.id));

    return asyncRegions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: PremiumEmptyState(
            icon: Icons.error_outline_rounded,
            title: l10n.error,
            message: appErrorText(context, e),
            actionLabel: l10n.retry,
            onAction: () {
              if (parent == null) {
                ref.invalidate(governoratesProvider);
              } else {
                ref.invalidate(regionChildrenProvider(parent.id));
              }
            },
          ),
        ),
      ),
      data: (regions) {
        if (regions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: PremiumEmptyState(
                icon: Icons.location_off_outlined,
                title: parent?.displayName(lang) ?? l10n.manageRegions,
                message: l10n.noResults,
                actionLabel: _canAddUnder(scope, parent)
                    ? l10n.addSubRegion
                    : null,
                onAction: _canAddUnder(scope, parent)
                    ? () => _openUpsertSheet(parent: parent)
                    : null,
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            if (parent == null) {
              ref.invalidate(governoratesProvider);
              await ref.read(governoratesProvider.future);
            } else {
              ref.invalidate(regionChildrenProvider(parent.id));
              await ref.read(regionChildrenProvider(parent.id).future);
            }
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
            itemCount: regions.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final region = regions[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.5),
                  child: Icon(
                    region.type == RegionType.governorate
                        ? Icons.location_city_rounded
                        : Icons.place_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(
                  region.displayName(lang),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                // Actions wrap below so the region name keeps full width.
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_typeLabel(region.type, l10n)),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: l10n.edit,
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: _canEditRegion(scope, region)
                                ? () => _openUpsertSheet(
                                    existing: region,
                                    parent: parent,
                                  )
                                : null,
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ],
                ),
                onTap: () => setState(() => _crumbs.add(region)),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSearchList(String lang, AppLocalizations l10n) {
    final searchAsync = ref.watch(regionSearchProvider(_query));
    return searchAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: FilledButton.tonalIcon(
          onPressed: () => ref.invalidate(regionSearchProvider(_query)),
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l10n.retry),
        ),
      ),
      data: (regions) {
        if (regions.isEmpty) {
          return Center(child: Text(l10n.noResults));
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: regions.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final region = regions[index];
            return ListTile(
              leading: const Icon(Icons.place_rounded),
              title: Text(region.displayName(lang)),
              // Actions wrap below so the region name keeps full width.
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_typeLabel(region.type, l10n)),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: l10n.edit,
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed:
                              _canEditRegion(
                                ref.watch(adminRegionScopeProvider).value,
                                region,
                              )
                              ? () => _openUpsertSheet(existing: region)
                              : null,
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ],
              ),
              onTap: () {
                _searchController.clear();
                setState(() {
                  _query = '';
                  _crumbs
                    ..clear()
                    ..add(region);
                });
              },
            );
          },
        );
      },
    );
  }
}

class _RegionUpsertSheet extends ConsumerStatefulWidget {
  const _RegionUpsertSheet({this.existing, this.parent});

  final Region? existing;
  final Region? parent;

  @override
  ConsumerState<_RegionUpsertSheet> createState() => _RegionUpsertSheetState();
}

class _RegionUpsertSheetState extends ConsumerState<_RegionUpsertSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameArCtrl;
  late final TextEditingController _nameEnCtrl;
  String? _parentRegionId;
  String? _parentRegionName;
  RegionType _type = RegionType.village;
  double? _lat;
  double? _lon;
  double _radiusKm = 3.0;
  bool _saving = false;

  static const _editableTypes = [
    RegionType.markaz,
    RegionType.district,
    RegionType.city,
    RegionType.newCity,
    RegionType.village,
    RegionType.area,
  ];

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _nameArCtrl = TextEditingController(text: ex?.nameAr ?? '');
    _nameEnCtrl = TextEditingController(text: ex?.nameEn ?? '');
    _parentRegionId = ex?.parentRegionId ?? widget.parent?.id;
    _parentRegionName = widget.parent?.nameAr;
    _type = ex?.type ?? RegionType.village;
    final meta = ex?.metadata;
    if (meta != null) {
      final lat = meta['lat'];
      final lon = meta['lon'];
      final r = meta['radius_km'];
      if (lat is num) _lat = lat.toDouble();
      if (lon is num) _lon = lon.toDouble();
      if (r is num) _radiusKm = r.toDouble().clamp(0.5, 25.0);
    }
  }

  @override
  void dispose() {
    _nameArCtrl.dispose();
    _nameEnCtrl.dispose();
    super.dispose();
  }

  String _typeLabel(RegionType t, AppLocalizations l10n) => switch (t) {
    RegionType.country => l10n.regionCountry,
    RegionType.governorate => l10n.regionGovernorate,
    RegionType.markaz => l10n.regionCenter,
    RegionType.district => l10n.regionDistrict,
    RegionType.city => l10n.regionCity,
    RegionType.newCity => l10n.regionNewCity,
    RegionType.village => l10n.regionVillage,
    RegionType.area => l10n.regionArea,
  };

  Future<void> _pickParent() async {
    final scope = ref.read(adminRegionScopeProvider).value;
    final restricted = scope != null && !scope.unrestricted;
    final roots = restricted
        ? await ref.read(adminScopeRootsProvider.future)
        : const <Region>[];
    if (!mounted) return;
    final picked = await RegionPickerSheet.show(
      context,
      selectedRegionId: _parentRegionId,
      roots: restricted ? roots : null,
      allowedIds: restricted ? scope!.regionIds : null,
    );
    if (picked == null || !mounted) return;
    final lang = Localizations.localeOf(context).languageCode;
    setState(() {
      _parentRegionId = picked.id;
      _parentRegionName = picked.displayName(lang);
    });
  }

  Future<void> _pickLocationFromMap() async {
    final picked = await SmartMapPickerSheet.show(
      context,
      initialLat: _lat,
      initialLng: _lon,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _lat = picked.latitude;
      _lon = picked.longitude;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(supabaseClientProvider)
          .rpc(
            'admin_upsert_region',
            params: {
              'p_id': widget.existing?.id,
              'p_parent_region_id': _parentRegionId,
              'p_type': _type.code,
              'p_name_ar': _nameArCtrl.text.trim(),
              'p_name_en': _nameEnCtrl.text.trim().isEmpty
                  ? null
                  : _nameEnCtrl.text.trim(),
              'p_lat': _lat,
              'p_lon': _lon,
              'p_radius_km': _radiusKm,
            },
          );
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        context.showAppSnackBar(l10n.regionSaved);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        context.showAppSnackBar(appErrorText(context, e), isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.existing != null
                          ? widget.existing!.displayName(
                              Localizations.localeOf(context).languageCode,
                            )
                          : l10n.addSubRegion,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.close,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              RegionSelectorButton(
                label: l10n.regionGovernorate,
                selectedName: _parentRegionName,
                onTap: _saving ? () {} : _pickParent,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _editableTypes.map((t) {
                  return ChoiceChip(
                    label: Text(_typeLabel(t, l10n)),
                    selected: _type == t,
                    onSelected: _saving
                        ? null
                        : (_) => setState(() => _type = t),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameArCtrl,
                decoration: InputDecoration(
                  labelText: l10n.bannerTitleAr,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.requiredField : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameEnCtrl,
                decoration: InputDecoration(
                  labelText: l10n.bannerTitleEn,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickLocationFromMap,
                icon: const Icon(Icons.location_searching_rounded),
                label: Text(
                  _lat != null && _lon != null
                      ? '${l10n.regionCoordinates}: ${_lat!.toStringAsFixed(4)}, ${_lon!.toStringAsFixed(4)}'
                      : l10n.pickFromMap,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${l10n.boundaryRadiusKm}: ${_radiusKm.toStringAsFixed(1)} km',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Slider(
                value: _radiusKm,
                min: 0.5,
                max: 25.0,
                divisions: 49,
                label: '${_radiusKm.toStringAsFixed(1)} km',
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _radiusKm = v),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
