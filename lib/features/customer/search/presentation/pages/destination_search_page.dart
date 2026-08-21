import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/customer/search/domain/entities/geo_point.dart';
import 'package:delwaqty/features/customer/search/domain/entities/place_details.dart';
import 'package:delwaqty/features/customer/search/domain/entities/place_suggestion.dart';
import 'package:delwaqty/features/customer/search/domain/entities/recent_search.dart';
import 'package:delwaqty/features/customer/search/domain/entities/saved_place.dart';
import 'package:delwaqty/features/customer/search/domain/geocoding_provider.dart';
import 'package:delwaqty/features/customer/search/presentation/providers/destination_search_controller.dart';
import 'package:delwaqty/features/customer/search/presentation/providers/search_providers.dart';
import 'package:delwaqty/features/customer/search/presentation/widgets/place_row.dart';

class DestinationSearchArgs {
  const DestinationSearchArgs({this.origin, this.title});
  final GeoPoint? origin;
  final String? title;
}

class DestinationSearchPage extends ConsumerStatefulWidget {
  const DestinationSearchPage({super.key, this.args});

  final DestinationSearchArgs? args;

  @override
  ConsumerState<DestinationSearchPage> createState() =>
      _DestinationSearchPageState();
}

class _DestinationSearchPageState extends ConsumerState<DestinationSearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _resolving = false;

  GeoPoint? get _origin => widget.args?.origin;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _select({
    required String placeId,
    required String primary,
    required String secondary,
  }) async {
    if (_resolving) return;
    setState(() => _resolving = true);
    final l10n = AppLocalizations.of(context);
    final notifier =
        ref.read(destinationSearchControllerProvider(_origin).notifier);
    try {
      final repo = ref.read(placesRepositoryProvider);
      final lang = ref.read(searchLanguageProvider);
      final details = await repo.details(
        placeId: placeId,
        languageCode: lang,
        session: notifier.session,
      );
      notifier.resetSession();
      await repo.addRecentSearch(RecentSearch(
        placeId: placeId,
        primaryText: primary,
        secondaryText: secondary,
        location: details.location,
        searchedAt: DateTime.now(),
      ));
      if (!mounted) return;
      Navigator.of(context).pop(details);
    } catch (_) {
      if (!mounted) return;
      setState(() => _resolving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.networkError)),
      );
    }
  }

  void _returnSaved(SavedPlace place) {
    Navigator.of(context).pop(PlaceDetails(
      placeId: place.id ?? place.type.wire,
      name: place.label,
      formattedAddress: place.address,
      location: place.location,
    ));
  }

  void _returnRecent(RecentSearch r) {
    Navigator.of(context).pop(PlaceDetails(
      placeId: r.placeId,
      name: r.primaryText,
      formattedAddress: r.secondaryText,
      location: r.location,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(destinationSearchControllerProvider(_origin));

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.args?.title ?? l10n.whereTo),
        titleTextStyle:
            context.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              onChanged: (v) => ref
                  .read(destinationSearchControllerProvider(_origin).notifier)
                  .onQueryChanged(v),
              decoration: InputDecoration(
                hintText: l10n.searchPlaceholderCity,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: state.query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _controller.clear();
                          ref
                              .read(destinationSearchControllerProvider(_origin)
                                  .notifier)
                              .onQueryChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: context.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
          if (_resolving) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _buildBody(context, l10n, state)),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    DestinationSearchState state,
  ) {
    if (state.query.trim().length < 2) {
      return _buildDefault(context, l10n);
    }
    switch (state.status) {
      case SearchStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case SearchStatus.error:
        return _buildError(context, l10n, state.errorKind);
      case SearchStatus.empty:
        return Center(
          child: Text(l10n.noResultsFound,
              style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant)),
        );
      case SearchStatus.results:
      case SearchStatus.idle:
        return _buildResults(context, state.suggestions);
    }
  }

  Widget _buildResults(BuildContext context, List<PlaceSuggestion> items) {
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: items.length,
      itemBuilder: (context, i) {
        final s = items[i];
        return PlaceRow(
          icon: Icons.location_on_outlined,
          title: s.primaryText,
          subtitle: s.secondaryText,
          onTap: () => _select(
            placeId: s.placeId,
            primary: s.primaryText,
            secondary: s.secondaryText,
          ),
        );
      },
    );
  }

  Widget _buildError(
      BuildContext context, AppLocalizations l10n, GeocodingErrorKind? kind) {
    final message = switch (kind) {
      GeocodingErrorKind.rateLimited => l10n.rateLimitReached,
      GeocodingErrorKind.network => l10n.networkError,
      _ => l10n.networkError,
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 48, color: context.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => ref
                .read(destinationSearchControllerProvider(_origin).notifier)
                .retry(),
            child: Text(l10n.tryAgain),
          ),
        ],
      ),
    );
  }

  Widget _buildDefault(BuildContext context, AppLocalizations l10n) {
    final savedAsync = ref.watch(savedPlacesProvider);
    final recentAsync = ref.watch(recentSearchesProvider);

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        savedAsync.maybeWhen(
          data: (places) => _buildSaved(context, l10n, places),
          orElse: () => const SizedBox.shrink(),
        ),
        recentAsync.maybeWhen(
          data: (recents) => _buildRecent(context, l10n, recents),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildSaved(
      BuildContext context, AppLocalizations l10n, List<SavedPlace> places) {
    SavedPlace? find(SavedPlaceType t) {
      for (final p in places) {
        if (p.type == t) return p;
      }
      return null;
    }

    final home = find(SavedPlaceType.home);
    final work = find(SavedPlaceType.work);
    final favorites =
        places.where((p) => p.type == SavedPlaceType.favorite).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PlaceRow(
          icon: Icons.home_rounded,
          title: l10n.home,
          subtitle: home?.address,
          iconColor: context.colorScheme.primary,
          onTap: () => home != null ? _returnSaved(home) : _promptSave(SavedPlaceType.home),
          trailing: home == null
              ? Text(l10n.setOnMap,
                  style: context.textTheme.labelSmall
                      ?.copyWith(color: context.colorScheme.primary))
              : null,
        ),
        PlaceRow(
          icon: Icons.work_rounded,
          title: l10n.work,
          subtitle: work?.address,
          iconColor: context.colorScheme.primary,
          onTap: () => work != null ? _returnSaved(work) : _promptSave(SavedPlaceType.work),
          trailing: work == null
              ? Text(l10n.setOnMap,
                  style: context.textTheme.labelSmall
                      ?.copyWith(color: context.colorScheme.primary))
              : null,
        ),
        ...favorites.map((f) => PlaceRow(
              icon: Icons.star_rounded,
              title: f.label,
              subtitle: f.address,
              iconColor: Colors.amber[700],
              onTap: () => _returnSaved(f),
            )),
      ],
    );
  }

  Widget _buildRecent(
      BuildContext context, AppLocalizations l10n, List<RecentSearch> recents) {
    if (recents.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.recentSearches,
                  style: context.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.colorScheme.onSurfaceVariant)),
              TextButton(
                onPressed: () async {
                  await ref
                      .read(placesRepositoryProvider)
                      .clearRecentSearches();
                  ref.invalidate(recentSearchesProvider);
                },
                child: Text(l10n.clearAll),
              ),
            ],
          ),
        ),
        ...recents.map((r) => PlaceRow(
              icon: Icons.history_rounded,
              title: r.primaryText,
              subtitle: r.secondaryText,
              onTap: () => _returnRecent(r),
            )),
      ],
    );
  }

  void _promptSave(SavedPlaceType type) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.searchPlaceholderCity)),
    );
    _focusNode.requestFocus();
  }
}
