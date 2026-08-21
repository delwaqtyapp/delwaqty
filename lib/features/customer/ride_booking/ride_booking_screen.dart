import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/customer/location/presentation/providers/location_provider.dart';
import 'package:delwaqty/features/customer/ride/presentation/providers/ride_providers.dart';
import 'package:delwaqty/features/customer/ride/presentation/widgets/ride_map.dart';
import 'package:delwaqty/features/customer/ride/presentation/widgets/ride_type_info.dart';
import 'package:delwaqty/features/customer/search/domain/entities/geo_point.dart';
import 'package:delwaqty/features/customer/search/domain/entities/place_details.dart';
import 'package:delwaqty/features/customer/search/domain/entities/saved_place.dart';
import 'package:delwaqty/features/customer/search/presentation/pages/destination_search_page.dart';
import 'package:delwaqty/features/customer/search/presentation/providers/search_providers.dart';
import 'package:delwaqty/features/customer/ride_booking/ride_booking_theme.dart';
import 'package:delwaqty/features/customer/ride_booking/ride_booking_animations.dart';
import 'package:delwaqty/features/customer/ride_booking/location_header_card.dart';
import 'package:delwaqty/features/customer/ride_booking/pickup_destination_card.dart';
import 'package:delwaqty/features/customer/ride_booking/quick_destination_cards.dart';
import 'package:delwaqty/features/customer/ride_booking/recent_destinations_section.dart';
import 'package:delwaqty/features/customer/ride_booking/safety_card.dart';
import 'package:delwaqty/features/customer/ride_booking/primary_cta_button.dart';

class RideBookingPage extends ConsumerStatefulWidget {
  const RideBookingPage({super.key});

  @override
  ConsumerState<RideBookingPage> createState() => _RideBookingPageState();
}

class _RideBookingPageState extends ConsumerState<RideBookingPage>
    with SingleTickerProviderStateMixin {
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
    return l10n.amountWithCurrency(
      amount.toStringAsFixed(0),
      l10n.currencySymbol,
    );
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

  Future<void> _useCurrentLocation() async {
    final l10n = AppLocalizations.of(context);
    final value = await ref
        .read(userLocationProvider.notifier)
        .refreshDeepLocked();
    if (!context.mounted) return;
    if (value != null) {
      final address = value.detailedAddress.isNotEmpty
          ? value.detailedAddress
          : l10n.currentLocation;
      _pickupController.text = address;
      ref
          .read(rideBookingProvider.notifier)
          .setPickup(address, value.latitude, value.longitude);
      final accuracy = value.accuracyMeters;
      if (accuracy != null && accuracy > precisionTargetMeters) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.accuracyInsufficient),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _openDestinationSearch() async {
    final result = await Navigator.of(context).push<PlaceDetails>(
      MaterialPageRoute(
        builder: (_) => DestinationSearchPage(
          args: DestinationSearchArgs(origin: _searchOrigin()),
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    final address = result.formattedAddress.isNotEmpty
        ? result.formattedAddress
        : result.name;
    _dropoffController.text = address;
    ref
        .read(rideBookingProvider.notifier)
        .setDropoff(
          address,
          result.location.latitude,
          result.location.longitude,
        );
  }

  void _applySavedPlace(SavedPlace place) {
    _dropoffController.text = place.address;
    ref
        .read(rideBookingProvider.notifier)
        .setDropoff(
          place.address,
          place.location.latitude,
          place.location.longitude,
        );
  }

  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(rideBookingProvider.notifier);
    final ride = await notifier.confirmRide();
    if (ride == null || !context.mounted) return;

    final booking = ref.read(rideBookingProvider);
    final drivers = await ref
        .read(rideRepositoryProvider)
        .findNearbyDrivers(
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
    context.push('/ride/tracking/${ride.id}');
    notifier.reset();
    _pickupController.clear();
    _dropoffController.clear();
    _promoController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final booking = ref.watch(rideBookingProvider);
    final locationAsync = ref.watch(userLocationProvider);

    return Scaffold(
      backgroundColor: RideBookingTheme.darkBg,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    RideBookingTheme.primaryPurple.withValues(alpha: 0.06),
                    RideBookingTheme.primaryPurple.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 200,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    RideBookingTheme.green.withValues(alpha: 0.03),
                    RideBookingTheme.green.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _buildBackButton(context)),
                      SliverToBoxAdapter(
                        child: StaggeredSlideIn(
                          children: [
                            const LocationHeaderCard(),
                            const SizedBox(height: 12),
                            PickupDestinationCard(
                              pickupAddress: booking.pickupAddress,
                              dropoffAddress: booking.dropoffAddress,
                              hasPickup: booking.hasPickup,
                              hasDropoff: booking.hasDropoff,
                              onPickupTap: _useCurrentLocation,
                              onDropoffTap: _openDestinationSearch,
                            ),
                          ],
                        ),
                      ),
                      if (booking.hasPickup)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                RideBookingTheme.cardRadius,
                              ),
                              child: RideMap(
                                pickup: LatLng(
                                  booking.pickupLatitude!,
                                  booking.pickupLongitude!,
                                ),
                                dropoff: booking.hasDropoff
                                    ? LatLng(
                                        booking.dropoffLatitude!,
                                        booking.dropoffLongitude!,
                                      )
                                    : null,
                                height: 180,
                              ),
                            ),
                          ),
                        ),
                      const SliverToBoxAdapter(
                        child: SizedBox(
                          height: RideBookingTheme.sectionSpacing,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _buildQuickDestinations(l10n, locationAsync),
                      ),
                      if (booking.step == BookingStep.review) ...[
                        const SliverToBoxAdapter(
                          child: SizedBox(
                            height: RideBookingTheme.sectionSpacing,
                          ),
                        ),
                        if (booking.isEstimating)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: RideBookingTheme.primaryPurple,
                                ),
                              ),
                            ),
                          )
                        else if (booking.quotes.isNotEmpty)
                          SliverToBoxAdapter(
                            child: _buildReviewSection(l10n, booking),
                          ),
                      ],
                      const SliverToBoxAdapter(
                        child: SizedBox(
                          height: RideBookingTheme.sectionSpacing,
                        ),
                      ),
                      SliverToBoxAdapter(child: _buildRecentSection(l10n)),
                      const SliverToBoxAdapter(
                        child: SizedBox(
                          height: RideBookingTheme.sectionSpacing,
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: SafetyCard(),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                ),
                _buildBottomBar(l10n, booking),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: GestureDetector(
        onTap: () => context.go('/'),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: RideBookingTheme.whiteAlpha08,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: RideBookingTheme.whiteAlpha60,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickDestinations(
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

    final items = <QuickDestItem>[
      QuickDestItem(
        icon: Icons.home_rounded,
        label: l10n.home,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)],
        ),
        onTap: () =>
            home != null ? _applySavedPlace(home) : _openDestinationSearch(),
      ),
      QuickDestItem(
        icon: Icons.work_rounded,
        label: l10n.work,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
        ),
        onTap: () =>
            work != null ? _applySavedPlace(work) : _openDestinationSearch(),
      ),
      QuickDestItem(
        icon: Icons.star_rounded,
        label: l10n.favorites,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD97706), Color(0xFFFCD34D)],
        ),
        onTap: _openDestinationSearch,
      ),
      QuickDestItem(
        icon: Icons.history_rounded,
        label: l10n.recentSearches,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF059669), Color(0xFF6EE7B7)],
        ),
        onTap: _openDestinationSearch,
      ),
      QuickDestItem(
        icon: Icons.flight_rounded,
        label: l10n.airport,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0891B2), Color(0xFF67E8F9)],
        ),
        onTap: _openDestinationSearch,
      ),
      QuickDestItem(
        icon: Icons.local_hospital_rounded,
        label: l10n.hospital,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDC2626), Color(0xFFFCA5A5)],
        ),
        onTap: _openDestinationSearch,
      ),
      QuickDestItem(
        icon: Icons.shopping_bag_rounded,
        label: l10n.shopping,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9333EA), Color(0xFFC084FC)],
        ),
        onTap: _openDestinationSearch,
      ),
      QuickDestItem(
        icon: Icons.more_horiz_rounded,
        label: l10n.more,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF475569), Color(0xFF94A3B8)],
        ),
        onTap: _openDestinationSearch,
      ),
    ];

    return QuickDestinationCards(items: items);
  }

  Widget _buildReviewSection(AppLocalizations l10n, RideBookingState booking) {
    return Column(
      children: [
        RideBookingSectionTitle(text: l10n.chooseRideType),
        const SizedBox(height: 12),
        ...booking.quotes.map((quote) {
          final info = RideTypeInfo.of(quote.rideType, l10n);
          final isSelected = booking.rideType == quote.rideType;
          return Padding(
            padding: RideBookingTheme.screenPadding,
            child: _buildRideTypeCard(
              l10n: l10n,
              info: info,
              quote: quote,
              isSelected: isSelected,
              money: _money(context, quote.total),
              onTap: () => ref
                  .read(rideBookingProvider.notifier)
                  .setRideType(quote.rideType),
            ),
          );
        }),
        if (booking.selectedQuote != null) ...[
          const SizedBox(height: RideBookingTheme.sectionSpacing),
          _buildPromoSection(l10n, booking),
          const SizedBox(height: RideBookingTheme.sectionSpacing),
          _buildFareBreakdown(l10n, booking),
        ],
      ],
    );
  }

  Widget _buildRideTypeCard({
    required AppLocalizations l10n,
    required RideTypeInfo info,
    required dynamic quote,
    required bool isSelected,
    required String money,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? RideBookingTheme.primaryPurple.withValues(alpha: 0.12)
                : RideBookingTheme.cardBg,
            borderRadius: BorderRadius.circular(RideBookingTheme.innerRadius),
            border: Border.all(
              color: isSelected
                  ? RideBookingTheme.primaryPurple
                  : RideBookingTheme.whiteAlpha08,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: RideBookingTheme.primaryPurple.withValues(
                        alpha: 0.15,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? RideBookingTheme.primaryPurple.withValues(alpha: 0.2)
                      : RideBookingTheme.whiteAlpha08,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  info.icon,
                  color: isSelected
                      ? RideBookingTheme.primaryPurple
                      : RideBookingTheme.whiteAlpha60,
                  size: 26,
                ),
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
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? RideBookingTheme.whiteAlpha80
                                : RideBookingTheme.whiteAlpha60,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.person_rounded,
                          size: 13,
                          color: RideBookingTheme.whiteAlpha40,
                        ),
                        Text(
                          '${quote.rideType.passengerCapacity}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: RideBookingTheme.whiteAlpha40,
                          ),
                        ),
                        if (quote.rideType.luggageCapacity > 0) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.luggage_rounded,
                            size: 13,
                            color: RideBookingTheme.whiteAlpha40,
                          ),
                          Text(
                            '${quote.rideType.luggageCapacity}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: RideBookingTheme.whiteAlpha40,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.arrivesInMinutes(quote.etaMinutes),
                      style: const TextStyle(
                        fontSize: 12,
                        color: RideBookingTheme.whiteAlpha40,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                money,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? RideBookingTheme.primaryPurple
                      : RideBookingTheme.whiteAlpha80,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.check_circle_rounded,
                  color: RideBookingTheme.primaryPurple,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromoSection(AppLocalizations l10n, RideBookingState booking) {
    final hasPromo = booking.promoCode != null && booking.promoDiscount > 0;
    return Padding(
      padding: RideBookingTheme.screenPadding,
      child: hasPromo
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(
                  RideBookingTheme.chipRadius,
                ),
                border: Border.all(
                  color: const Color(0xFF34C759).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_offer_rounded,
                    color: Color(0xFF34C759),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${booking.promoCode}  -${_money(context, booking.promoDiscount)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF34C759),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _promoController.clear();
                      ref.read(rideBookingProvider.notifier).clearPromo();
                    },
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: RideBookingTheme.whiteAlpha40,
                    ),
                  ),
                ],
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promoController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                      color: RideBookingTheme.whiteAlpha80,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.promoCode,
                      hintStyle: const TextStyle(
                        color: RideBookingTheme.whiteAlpha40,
                      ),
                      prefixIcon: const Icon(
                        Icons.local_offer_outlined,
                        size: 20,
                        color: RideBookingTheme.whiteAlpha40,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: RideBookingTheme.cardBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          RideBookingTheme.chipRadius,
                        ),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          RideBookingTheme.chipRadius,
                        ),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => ref
                      .read(rideBookingProvider.notifier)
                      .applyPromo(_promoController.text),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: RideBookingTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(
                        RideBookingTheme.chipRadius,
                      ),
                    ),
                    child: Text(
                      l10n.applyPromo,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFareBreakdown(AppLocalizations l10n, RideBookingState booking) {
    final quote = booking.selectedQuote;
    if (quote == null) return const SizedBox.shrink();

    return Padding(
      padding: RideBookingTheme.screenPadding,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: RideBookingTheme.cardBg,
          borderRadius: BorderRadius.circular(RideBookingTheme.innerRadius),
          border: Border.all(color: RideBookingTheme.whiteAlpha08, width: 1),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.fareBreakdown,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: RideBookingTheme.whiteAlpha80,
                  ),
                ),
                Text(
                  '${quote.distanceKm.toStringAsFixed(1)} ${l10n.kmUnit} Â· ${quote.durationMinutes.ceil()} ${l10n.minutesShort}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: RideBookingTheme.whiteAlpha40,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _fareRow(l10n.baseFare, _money(context, quote.baseFare)),
            _fareRow(l10n.distanceFare, _money(context, quote.distanceFare)),
            _fareRow(l10n.timeFare, _money(context, quote.timeFare)),
            if (booking.promoDiscount > 0)
              _fareRow(
                l10n.discount,
                '-${_money(context, booking.promoDiscount)}',
                highlight: true,
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: RideBookingTheme.whiteAlpha08, height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: RideBookingTheme.whiteAlpha80,
                  ),
                ),
                Text(
                  _money(context, booking.finalFare),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: RideBookingTheme.primaryPurple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fareRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: RideBookingTheme.whiteAlpha40,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: highlight
                  ? const Color(0xFF34C759)
                  : RideBookingTheme.whiteAlpha80,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSection(AppLocalizations l10n) {
    final recentAsync = ref.watch(recentSearchesProvider);
    return recentAsync.when(
      data: (recents) {
        if (recents.isEmpty) return const SizedBox.shrink();
        final items = recents.take(5).map((r) {
          return RecentDest(
            name: r.primaryText,
            address: r.secondaryText,
            icon: Icons.history_rounded,
            onTap: () {
              _dropoffController.text = r.secondaryText;
              ref
                  .read(rideBookingProvider.notifier)
                  .setDropoff(
                    r.secondaryText,
                    r.location.latitude,
                    r.location.longitude,
                  );
            },
          );
        }).toList();
        return RecentDestinationsSection(recents: items);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildBottomBar(AppLocalizations l10n, RideBookingState booking) {
    final bool isReview =
        booking.step == BookingStep.review && booking.selectedQuote != null;

    final String ctaText;
    final VoidCallback? ctaAction;

    if (isReview) {
      ctaText = '${l10n.confirmRide} Â· ${_money(context, booking.finalFare)}';
      ctaAction = booking.isRequesting ? null : () => _confirm();
    } else if (booking.isEstimating) {
      ctaText = l10n.searchingForLocation;
      ctaAction = null;
    } else {
      ctaText = l10n.confirmLocation;
      ctaAction = _openDestinationSearch;
    }

    return Container(
      padding: RideBookingTheme.screenPadding.add(
        const EdgeInsets.only(top: 10, bottom: 12),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            RideBookingTheme.darkBg.withValues(alpha: 0.0),
            RideBookingTheme.darkBg,
          ],
          stops: const [0.0, 0.3],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (booking.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                booking.error!,
                style: const TextStyle(
                  fontSize: 12,
                  color: RideBookingTheme.red,
                ),
              ),
            ),
          PrimaryCtaButton(
            onPressed: ctaAction,
            isLoading: booking.isRequesting,
            isEnabled: ctaAction != null,
            child: Text(
              ctaText,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
