import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/_shared/regions/domain/entities/region.dart';
import 'package:delwaqty/features/_shared/regions/presentation/providers/region_providers.dart';
import 'package:delwaqty/features/_shared/regions/presentation/widgets/region_browser.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class RegionPickerSheet extends ConsumerStatefulWidget {
  const RegionPickerSheet({
    super.key,
    this.selectedRegionId,
    this.roots,
    this.allowedIds,
  });

  final String? selectedRegionId;

  /// Scoped-admin support: top level lists these regions instead of all
  /// governorates, and regions outside [allowedIds] are not selectable.
  final List<Region>? roots;
  final Set<String>? allowedIds;

  static Future<Region?> show(
    BuildContext context, {
    String? selectedRegionId,
    List<Region>? roots,
    Set<String>? allowedIds,
  }) {
    return showModalBottomSheet<Region>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => RegionPickerSheet(
        selectedRegionId: selectedRegionId,
        roots: roots,
        allowedIds: allowedIds,
      ),
    );
  }

  @override
  ConsumerState<RegionPickerSheet> createState() => _RegionPickerSheetState();
}

class _RegionPickerSheetState extends ConsumerState<RegionPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final height = MediaQuery.sizeOf(context).height * 0.78;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.adminMgmtSelectRegion,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: l10n.close,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
              onChanged: (val) => setState(() => _query = val.trim()),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _query.length >= 2
                ? _buildSearchResults(lang, l10n)
                : RegionBrowser(
                    selectedRegionId: widget.selectedRegionId,
                    roots: widget.roots,
                    allowedIds: widget.allowedIds,
                    onSelected: (region) => Navigator.of(context).pop(region),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(String lang, AppLocalizations l10n) {
    final searchAsync = ref.watch(regionSearchProvider(_query));
    return searchAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: FilledButton.tonalIcon(
          onPressed: () => ref.invalidate(regionSearchProvider(_query)),
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l10n.retry),
        ),
      ),
      data: (allRegions) {
        final regions = widget.allowedIds == null
            ? allRegions
            : allRegions
                  .where((r) => widget.allowedIds!.contains(r.id))
                  .toList();
        if (regions.isEmpty) {
          return Center(child: Text(l10n.noResults));
        }
        return ListView.separated(
          itemCount: regions.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final region = regions[index];
            return ListTile(
              leading: const Icon(Icons.place_rounded),
              title: Text(region.displayName(lang)),
              subtitle: Text(region.type.code),
              onTap: () => Navigator.of(context).pop(region),
            );
          },
        );
      },
    );
  }
}

class RegionSelectorButton extends StatelessWidget {
  const RegionSelectorButton({
    super.key,
    required this.label,
    this.selectedName,
    required this.onTap,
  });

  final String label;
  final String? selectedName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasSelection =
        selectedName != null && selectedName!.trim().isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          prefixIcon: const Icon(Icons.map_outlined),
          suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
        ),
        child: Text(
          hasSelection ? selectedName! : label,
          style: TextStyle(
            color: hasSelection ? cs.onSurface : cs.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
