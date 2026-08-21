import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/_shared/regions/domain/entities/region.dart';
import 'package:delwaqty/features/_shared/regions/presentation/providers/region_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class RegionSelectionPage extends ConsumerStatefulWidget {
  const RegionSelectionPage({
    super.key,
    this.source = RegionPreferenceSource.manual,
  });

  final RegionPreferenceSource source;

  @override
  ConsumerState<RegionSelectionPage> createState() => _RegionSelectionPageState();
}

class _RegionSelectionPageState extends ConsumerState<RegionSelectionPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _displayName(Region region) {
    final language = Localizations.localeOf(context).languageCode;
    return region.displayName(language);
  }

  Future<void> _select(Region region) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(selectRegionProvider)(
        region: region,
        source: widget.source,
      );
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).regionSaved)),
        );
        Navigator.of(context).pop(region);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).regionSelectionFailed),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final regionsAsync = _query.isEmpty
        ? ref.watch(governoratesProvider)
        : ref.watch(regionSearchProvider(_query));
    final current = ref.watch(currentUserRegionProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.selectRegion)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: l10n.regionSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: regionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(l10n.noResults)),
              data: (regions) {
                if (regions.isEmpty) {
                  return Center(child: Text(l10n.noResults));
                }
                final currentRegionId = current.valueOrNull?.regionId;
                return ListView.separated(
                  itemCount: regions.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final region = regions[index];
                    final isCurrent = region.id == currentRegionId;
                    return ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(_displayName(region)),
                      trailing: isCurrent
                          ? const Icon(Icons.check_circle_rounded)
                          : null,
                      onTap: () => _select(region),
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
}
