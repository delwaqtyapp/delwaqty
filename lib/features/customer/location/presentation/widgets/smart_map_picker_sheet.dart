import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/features/customer/location/presentation/providers/location_provider.dart';
import 'package:delwaqty/features/customer/search/domain/geocoding_provider.dart';
import 'package:delwaqty/features/customer/search/presentation/providers/search_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class _MapSearchHit {
  const _MapSearchHit({
    required this.title,
    this.subtitle = '',
    this.placeId,
    this.lat,
    this.lng,
  });

  final String title;
  final String subtitle;
  final String? placeId;
  final double? lat;
  final double? lng;
}

class SmartMapPickerSheet extends ConsumerStatefulWidget {
  const SmartMapPickerSheet({
    this.initialLat,
    this.initialLng,
    super.key,
  });

  final double? initialLat;
  final double? initialLng;

  static Future<UserLocation?> show(
    BuildContext context, {
    double? initialLat,
    double? initialLng,
  }) {
    return showModalBottomSheet<UserLocation>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => SmartMapPickerSheet(
        initialLat: initialLat,
        initialLng: initialLng,
      ),
    );
  }

  @override
  ConsumerState<SmartMapPickerSheet> createState() =>
      _SmartMapPickerSheetState();
}

class _SmartMapPickerSheetState extends ConsumerState<SmartMapPickerSheet> {
  static const LatLng _cairoFallback = LatLng(30.0444, 31.2357);

  final Completer<GoogleMapController> _mapController = Completer();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  late LatLng _center;
  bool _isMoving = false;
  bool _isGeocoding = false;
  bool _isLockingGps = false;
  bool _isConfirming = false;
  bool _isSearching = false;
  List<_MapSearchHit> _searchHits = const [];
  String _resolvedAddress = '';
  double? _accuracyMeters;
  int _geocodeToken = 0;

  @override
  void initState() {
    super.initState();
    final currentLoc = ref.read(userLocationProvider).value;
    if (widget.initialLat != null && widget.initialLng != null) {
      _center = LatLng(widget.initialLat!, widget.initialLng!);
    } else if (currentLoc != null) {
      _center = LatLng(currentLoc.latitude, currentLoc.longitude);
      _resolvedAddress = currentLoc.detailedAddress;
      _accuracyMeters = currentLoc.accuracyMeters;
    } else {
      _center = _cairoFallback;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialLat == null && currentLoc == null) {
        _detectPreciseGps();
      } else if (_resolvedAddress.isEmpty) {
        _reverseGeocodeCenter(_center);
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    final q = query.trim();
    if (q.length < 2) {
      setState(() {
        _searchHits = const [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _performSearch(q);
    });
  }

  Future<void> _performSearch(String query) async {
    final hits = <_MapSearchHit>[];
    try {
      final places = ref.read(placesRepositoryProvider);
      final suggestions = await places.autocomplete(
        query: query,
        bias: GeoPoint(latitude: _center.latitude, longitude: _center.longitude),
      );
      for (final s in suggestions.take(5)) {
        hits.add(
          _MapSearchHit(
            title: s.primaryText,
            subtitle: s.secondaryText ?? '',
            placeId: s.placeId,
          ),
        );
      }
    } catch (_) {}

    if (hits.isEmpty) {
      try {
        final lang = Localizations.localeOf(context).languageCode;
        final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
          'q': query,
          'format': 'json',
          'addressdetails': '1',
          'limit': '6',
          'countrycodes': 'eg',
          'accept-language': lang,
        });
        final resp = await http
            .get(uri, headers: {'User-Agent': 'DelwaqtyApp/1.0'})
            .timeout(const Duration(seconds: 6));
        if (resp.statusCode == 200) {
          final decoded = jsonDecode(resp.body);
          if (decoded is List) {
            for (final item in decoded) {
              if (item is Map) {
                final lat = double.tryParse('${item['lat']}');
                final lng = double.tryParse('${item['lon']}');
                final display = (item['display_name'] ?? '').toString();
                if (lat != null && lng != null && display.isNotEmpty) {
                  final parts = display.split(',');
                  hits.add(
                    _MapSearchHit(
                      title: parts.first.trim(),
                      subtitle: parts.skip(1).take(2).join(', ').trim(),
                      lat: lat,
                      lng: lng,
                    ),
                  );
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _searchHits = hits;
      _isSearching = false;
    });
  }

  Future<void> _selectSearchHit(_MapSearchHit hit) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _searchHits = const [];
      _isSearching = false;
    });
    double? lat = hit.lat;
    double? lng = hit.lng;
    String? address = hit.subtitle.isNotEmpty
        ? '${hit.title}, ${hit.subtitle}'
        : hit.title;

    if ((lat == null || lng == null) && hit.placeId != null) {
      try {
        final details =
            await ref.read(placesRepositoryProvider).details(placeId: hit.placeId!);
        lat = details.point.latitude;
        lng = details.point.longitude;
        if (details.formattedAddress.isNotEmpty) {
          address = details.formattedAddress;
        }
      } catch (_) {}
    }

    if (lat == null || lng == null || !mounted) return;
    final target = LatLng(lat, lng);
    setState(() {
      _center = target;
      _resolvedAddress = address ?? '';
      _searchController.text = hit.title;
    });
    if (_mapController.isCompleted) {
      final ctrl = await _mapController.future;
      await ctrl.animateCamera(CameraUpdate.newLatLngZoom(target, 17));
    }
    unawaited(_reverseGeocodeCenter(target));
  }

  Future<void> _reverseGeocodeCenter(LatLng target) async {
    final token = ++_geocodeToken;
    if (mounted) {
      setState(() => _isGeocoding = true);
    }
    try {
      final address = await ref
          .read(userLocationProvider.notifier)
          .reverseGeocodePoint(target.latitude, target.longitude);
      if (!mounted || token != _geocodeToken) return;
      setState(() {
        _resolvedAddress = address.isNotEmpty
            ? address
            : '${target.latitude.toStringAsFixed(5)}, ${target.longitude.toStringAsFixed(5)}';
        _isGeocoding = false;
      });
    } catch (_) {
      if (!mounted || token != _geocodeToken) return;
      setState(() {
        _resolvedAddress =
            '${target.latitude.toStringAsFixed(5)}, ${target.longitude.toStringAsFixed(5)}';
        _isGeocoding = false;
      });
    }
  }

  Future<void> _detectPreciseGps() async {
    if (_isLockingGps) return;
    setState(() => _isLockingGps = true);
    try {
      final loc =
          await ref.read(userLocationProvider.notifier).refreshDeepLocked();
      if (!mounted) return;
      if (loc != null) {
        final target = LatLng(loc.latitude, loc.longitude);
        setState(() {
          _center = target;
          _resolvedAddress = loc.detailedAddress;
          _accuracyMeters = loc.accuracyMeters;
        });
        if (_mapController.isCompleted) {
          final ctrl = await _mapController.future;
          await ctrl.animateCamera(CameraUpdate.newLatLngZoom(target, 18));
        }
      } else {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.locationUnavailable)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLockingGps = false);
      }
    }
  }

  Future<void> _confirmSelection() async {
    if (_isConfirming) return;
    setState(() => _isConfirming = true);
    try {
      final saved = await ref
          .read(userLocationProvider.notifier)
          .setCustomCoordinates(
            latitude: _center.latitude,
            longitude: _center.longitude,
            addressOverride: _resolvedAddress,
          );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } finally {
      if (mounted) {
        setState(() => _isConfirming = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final height = MediaQuery.sizeOf(context).height * 0.90;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 6),
            child: Row(
              children: [
                const Icon(
                  Icons.satellite_alt_rounded,
                  color: AppColors.brandPurple,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.pickLocationOnMap,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        l10n.dragMapToRefineLocation,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
          // Live Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: _performSearch,
              decoration: InputDecoration(
                hintText: '${l10n.search}…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _searchController.text.isNotEmpty
                    ? IconButton(
                        tooltip: l10n.clear,
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchHits = const []);
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_searchHits.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 190),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _searchHits.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, idx) {
                  final hit = _searchHits[idx];
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.place_rounded,
                      color: AppColors.brandPurple,
                      size: 20,
                    ),
                    title: Text(
                      hit.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: hit.subtitle.isNotEmpty
                        ? Text(
                            hit.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    onTap: () => _selectSearchHit(hit),
                  );
                },
              ),
            ),
          // Map + Floating center pin + accuracy badge
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _center,
                    zoom: 17,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    const Factory<OneSequenceGestureRecognizer>(
                      EagerGestureRecognizer.new,
                    ),
                  },
                  onMapCreated: (ctrl) {
                    if (!_mapController.isCompleted) {
                      _mapController.complete(ctrl);
                    }
                  },
                  onCameraMoveStarted: () {
                    if (!_isMoving) {
                      setState(() => _isMoving = true);
                    }
                  },
                  onCameraMove: (pos) {
                    _center = pos.target;
                  },
                  onCameraIdle: () {
                    if (_isMoving) {
                      setState(() => _isMoving = false);
                    }
                    _reverseGeocodeCenter(_center);
                  },
                ),
                // Animated floating center pin
                IgnorePointer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutBack,
                        transform: Matrix4.translationValues(
                          0,
                          _isMoving ? -10 : 0,
                          0,
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          size: 46,
                          color: AppColors.brandPurple,
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: _isMoving ? 14 : 8,
                        height: _isMoving ? 6 : 4,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(
                            alpha: _isMoving ? 0.25 : 0.45,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
                // Accuracy or locking status chip at top of map
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: Center(
                    child: _isLockingGps
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: cs.surface.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x22000000),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    l10n.acquiringHighAccuracyGps,
                                    style: AppTextStyles.labelSmall.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _accuracyMeters != null
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.successLight
                                      .withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.gps_fixed_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      l10n.gpsLockedWithinMeters(
                                        _accuracyMeters!.toStringAsFixed(1),
                                      ),
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                  ),
                ),
                // Floating Smart GPS button
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton.extended(
                    heroTag: 'smart_gps_btn',
                    onPressed: _isLockingGps ? null : _detectPreciseGps,
                    backgroundColor: cs.surface,
                    foregroundColor: AppColors.brandPurple,
                    icon: const Icon(Icons.my_location_rounded),
                    label: Text(
                      l10n.useSmartGpsLocation,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.brandPurple,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bottom card with resolved address + confirm button
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                AppColors.brandPurple.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.place_rounded,
                            color: AppColors.brandPurple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.selectedAddressLabel,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isGeocoding
                                    ? l10n.searchingForLocation
                                    : (_resolvedAddress.isNotEmpty
                                        ? _resolvedAddress
                                        : l10n.locationUnavailable),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed:
                          _isConfirming || _isGeocoding ? null : _confirmSelection,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _isConfirming
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_rounded),
                      label: Text(
                        l10n.confirmSelectedLocation,
                        style: AppTextStyles.titleSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
