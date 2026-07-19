import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/location/presentation/providers/location_provider.dart';
import 'package:delwaqty/features/ride/domain/entities/ride.dart';
import 'package:delwaqty/features/ride/presentation/providers/ride_providers.dart';
import 'package:delwaqty/features/ride/presentation/widgets/ride_map.dart';
import 'package:delwaqty/features/ride/presentation/widgets/ride_type_info.dart';
import 'package:delwaqty/features/search/domain/entities/geo_point.dart';
import 'package:delwaqty/features/search/domain/entities/place_details.dart';
import 'package:delwaqty/features/search/domain/entities/saved_place.dart';
import 'package:delwaqty/features/search/presentation/pages/destination_search_page.dart';
import 'package:delwaqty/features/search/presentation/providers/search_providers.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';

class RideBookingPage extends ConsumerStatefulWidget {
  const RideBookingPage({super.key});

  @override
  ConsumerState<RideBookingPage> createState() => _RideBookingPageState();
}

class _RideBookingPageState extends ConsumerState<RideBookingPage> {
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  final _promoController = TextEditingController();

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  String _money(BuildContext context, double amount) {
    final l10n = AppLocalizations.of(context);
    return l10n.amountWithCurrency(amount.toStringAsFixed(0), l10n.currencySymbol);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final booking = ref.watch(rideBookingProvider);
    final locationAsync = ref.watch(userLocationProvider);

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, l10n),
                    if (booking.hasPickup) _buildMap(context, booking),
                    _buildLocationInputs(context, l10n, booking, locationAsync),
                    if (booking.step == BookingStep.review) ...[
                      if (booking.isEstimating)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (booking.quotes.isNotEmpty) ...[
                        _buildRideTypeSelector(context, l10n, booking),
                        _buildPromoSection(context, l10n, booking),
                        _buildFareBreakdown(context, l10n, booking),
                      ],
                    ],
                    _buildSafetyBadge(context, l10n),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            if (booking.step == BookingStep.review && booking.selectedQuote != null)
              _buildBottomBar(context, l10n, booking),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    return AnimatedFadeIn(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
        child: Row(
          children: [
            IconButton(
              onPressed: () => context.go('/'),
              icon: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.arrow_back_rounded,
                    color: context.colorScheme.onSurface, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(BuildContext context, RideBookingState booking) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: RideMap(
        pickup: LatLng(booking.pickupLatitude!, booking.pickupLongitude!),
        dropoff: booking.hasDropoff
            ? LatLng(booking.dropoffLatitude!, booking.dropoffLongitude!)
            : null,
        height: 180,
      ),
    );
  }

  Widget _buildLocationInputs(
    BuildContext context,
    AppLocalizations l10n,
    RideBookingState booking,
    AsyncValue<UserLocation?> locationAsync,
  ) {
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 100),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: context.colorScheme.outlineVariant.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: context.colorScheme.primary, shape: BoxShape.circle),
                      ),
                      Container(
                        width: 2,
                        height: 28,
                        color: context.colorScheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: context.colorScheme.error, shape: BoxShape.circle),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        _buildLocationField(
                          context,
                          text: booking.pickupAddress,
                          hint: l10n.currentLocation,
                          isCurrent: true,
                          onTap: () => _useCurrentLocation(l10n, locationAsync),
                        ),
                        const SizedBox(height: 8),
                        _buildLocationField(
                          context,
                          text: booking.dropoffAddress,
                          hint: l10n.whereTo,
                          isCurrent: false,
                          onTap: () => _openDestinationSearch(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSavedPlaces(context, l10n, locationAsync),
            ],
          ),
        ),
      ),
    );
  }

  void _useCurrentLocation(AppLocalizations l10n, AsyncValue<UserLocation?> loc) {
    final value = loc.valueOrNull;
    if (value != null) {
      final address =
          value.detailedAddress.isNotEmpty ? value.detailedAddress : l10n.currentLocation;
      _pickupController.text = address;
      ref
          .read(rideBookingProvider.notifier)
          .setPickup(address, value.latitude, value.longitude);
    }
  }

  Widget _buildLocationField(
    BuildContext context, {
    required String text,
    required String hint,
    required bool isCurrent,
    required VoidCallback onTap,
  }) {
    final hasValue = text.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (isCurrent) ...[
              Icon(Icons.my_location_rounded, size: 16, color: context.colorScheme.primary),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                hasValue ? text : hint,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: hasValue
                      ? context.colorScheme.onSurface
                      : (isCurrent
                          ? context.colorScheme.primary
                          : context.colorScheme.onSurfaceVariant),
                  fontWeight: hasValue ? FontWeight.w500 : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: context.colorScheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedPlaces(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<UserLocation?> locationAsync,
  ) {
    final savedAsync = ref.watch(savedPlacesProvider);
    final places = savedAsync.valueOrNull ?? const <SavedPlace>[];
    SavedPlace? find(SavedPlaceType t) {
      for (final p in places) {
        if (p.type == t) return p;
      }
      return null;
    }

    final home = find(SavedPlaceType.home);
    final work = find(SavedPlaceType.work);

    return Row(
      children: [
        _buildSavedPlaceChip(
          context,
          icon: Icons.home_rounded,
          label: l10n.home,
          onTap: () => home != null
              ? _applySavedPlace(home)
              : _openDestinationSearch(context),
        ),
        const SizedBox(width: 8),
        _buildSavedPlaceChip(
          context,
          icon: Icons.work_rounded,
          label: l10n.work,
          onTap: () => work != null
              ? _applySavedPlace(work)
              : _openDestinationSearch(context),
        ),
      ],
    );
  }

  void _applySavedPlace(SavedPlace place) {
    _dropoffController.text = place.address;
    ref.read(rideBookingProvider.notifier).setDropoff(
          place.address,
          place.location.latitude,
          place.location.longitude,
        );
  }

  Widget _buildSavedPlaceChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: context.colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideTypeSelector(
      BuildContext context, AppLocalizations l10n, RideBookingState booking) {
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.chooseRideType,
              style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...booking.quotes.map((quote) {
              final info = RideTypeInfo.of(quote.rideType, l10n);
              final isSelected = booking.rideType == quote.rideType;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () =>
                      ref.read(rideBookingProvider.notifier).setRideType(quote.rideType),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.colorScheme.primaryContainer.withValues(alpha: 0.4)
                          : context.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? context.colorScheme.primary
                            : context.colorScheme.outlineVariant.withValues(alpha: 0.2),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? context.colorScheme.primary.withValues(alpha: 0.15)
                                : context.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(info.icon,
                              color: isSelected
                                  ? context.colorScheme.primary
                                  : context.colorScheme.onSurfaceVariant,
                              size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    info.name,
                                    style: context.textTheme.bodyLarge
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.person_rounded,
                                      size: 13,
                                      color: context.colorScheme.onSurfaceVariant),
                                  Text(
                                    '${quote.rideType.passengerCapacity}',
                                    style: context.textTheme.labelSmall?.copyWith(
                                        color: context.colorScheme.onSurfaceVariant),
                                  ),
                                  if (quote.rideType.luggageCapacity > 0) ...[
                                    const SizedBox(width: 6),
                                    Icon(Icons.luggage_rounded,
                                        size: 13,
                                        color: context.colorScheme.onSurfaceVariant),
                                    Text(
                                      '${quote.rideType.luggageCapacity}',
                                      style: context.textTheme.labelSmall?.copyWith(
                                          color: context.colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.arrivesInMinutes(quote.etaMinutes),
                                style: context.textTheme.bodySmall?.copyWith(
                                    color: context.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _money(context, quote.total),
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? context.colorScheme.primary
                                : context.colorScheme.onSurface,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.check_circle_rounded,
                              color: context.colorScheme.primary, size: 20),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoSection(
      BuildContext context, AppLocalizations l10n, RideBookingState booking) {
    final hasPromo = booking.promoCode != null && booking.promoDiscount > 0;
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: hasPromo
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_offer_rounded, color: Colors.green[700], size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${booking.promoCode}  -${_money(context, booking.promoDiscount)}',
                        style: context.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600, color: Colors.green[800]),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        _promoController.clear();
                        ref.read(rideBookingProvider.notifier).clearPromo();
                      },
                      child: Icon(Icons.close_rounded,
                          size: 18, color: context.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _promoController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: l10n.promoCode,
                            prefixIcon:
                                const Icon(Icons.local_offer_outlined, size: 20),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: context.colorScheme.outlineVariant
                                      .withValues(alpha: 0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: context.colorScheme.outlineVariant
                                      .withValues(alpha: 0.3)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => ref
                              .read(rideBookingProvider.notifier)
                              .applyPromo(_promoController.text),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.colorScheme.primary,
                            foregroundColor: context.colorScheme.onPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(l10n.applyPromo),
                        ),
                      ),
                    ],
                  ),
                  if (booking.promoError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(
                        l10n.promoInvalid,
                        style: context.textTheme.bodySmall
                            ?.copyWith(color: context.colorScheme.error),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildFareBreakdown(
      BuildContext context, AppLocalizations l10n, RideBookingState booking) {
    final quote = booking.selectedQuote;
    if (quote == null) return const SizedBox.shrink();
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.fareBreakdown,
                      style: context.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    '${quote.distanceKm.toStringAsFixed(1)} km · ${quote.durationMinutes.ceil()} ${l10n.minutesShort}',
                    style: context.textTheme.bodySmall
                        ?.copyWith(color: context.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _fareRow(context, l10n.baseFare, _money(context, quote.baseFare)),
              _fareRow(context, l10n.distanceFare, _money(context, quote.distanceFare)),
              _fareRow(context, l10n.timeFare, _money(context, quote.timeFare)),
              if (booking.promoDiscount > 0)
                _fareRow(context, l10n.discount, '-${_money(context, booking.promoDiscount)}',
                    highlight: true),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.totalFare,
                      style: context.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text(
                    _money(context, booking.finalFare),
                    style: context.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800, color: context.colorScheme.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fareRow(BuildContext context, String label, String value,
      {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant)),
          Text(value,
              style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: highlight ? Colors.green[700] : context.colorScheme.onSurface)),
        ],
      ),
    );
  }

  Widget _buildSafetyBadge(BuildContext context, AppLocalizations l10n) {
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 500),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_rounded, color: Colors.green[600], size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.tripProtected,
                  style: context.textTheme.bodySmall
                      ?.copyWith(color: Colors.green[800], fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(
      BuildContext context, AppLocalizations l10n, RideBookingState booking) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        border: Border(
          top: BorderSide(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (booking.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(booking.error!,
                  style: context.textTheme.bodySmall
                      ?.copyWith(color: context.colorScheme.error)),
            ),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: booking.isRequesting || !booking.isReadyToBook
                  ? null
                  : () => _confirm(context, l10n),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colorScheme.primary,
                foregroundColor: context.colorScheme.onPrimary,
                disabledBackgroundColor: context.colorScheme.surfaceContainerHighest,
                disabledForegroundColor: context.colorScheme.onSurfaceVariant,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: booking.isRequesting
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: context.colorScheme.onPrimary),
                    )
                  : Text(
                      '${l10n.confirmRide} · ${_money(context, booking.finalFare)}',
                      style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.colorScheme.onPrimary),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(BuildContext context, AppLocalizations l10n) async {
    final notifier = ref.read(rideBookingProvider.notifier);
    final ride = await notifier.confirmRide();
    if (ride == null || !context.mounted) return;

    final booking = ref.read(rideBookingProvider);
    final drivers = await ref.read(rideRepositoryProvider).findNearbyDrivers(
          latitude: booking.pickupLatitude!,
          longitude: booking.pickupLongitude!,
          rideType: ride.rideType,
        );
    if (!context.mounted) return;

    if (drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.noDriversFound),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    context.push('/ride/tracking/${ride.id}');
    notifier.reset();
    _pickupController.clear();
    _dropoffController.clear();
    _promoController.clear();
  }

  GeoPoint? _searchOrigin() {
    final booking = ref.read(rideBookingProvider);
    if (booking.hasPickup) {
      return GeoPoint(booking.pickupLatitude!, booking.pickupLongitude!);
    }
    final loc = ref.read(userLocationProvider).valueOrNull;
    if (loc != null) return GeoPoint(loc.latitude, loc.longitude);
    return null;
  }

  Future<void> _openDestinationSearch(BuildContext context) async {
    final result = await Navigator.of(context).push<PlaceDetails>(
      MaterialPageRoute(
        builder: (_) => DestinationSearchPage(
          args: DestinationSearchArgs(origin: _searchOrigin()),
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    final address =
        result.formattedAddress.isNotEmpty ? result.formattedAddress : result.name;
    _dropoffController.text = address;
    ref.read(rideBookingProvider.notifier).setDropoff(
          address,
          result.location.latitude,
          result.location.longitude,
        );
  }
}
