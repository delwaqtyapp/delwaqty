import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/location/presentation/providers/location_provider.dart';
import 'package:delwaqty/features/ride/domain/entities/ride.dart';
import 'package:delwaqty/features/ride/presentation/providers/ride_providers.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';

class RideBookingPage extends ConsumerStatefulWidget {
  const RideBookingPage({super.key});

  @override
  ConsumerState<RideBookingPage> createState() => _RideBookingPageState();
}

class _RideBookingPageState extends ConsumerState<RideBookingPage> {
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  final _pickupFocus = FocusNode();
  final _dropoffFocus = FocusNode();

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    _pickupFocus.dispose();
    _dropoffFocus.dispose();
    super.dispose();
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
                    _buildLocationInputs(context, l10n, booking, locationAsync),
                    if (booking.step == BookingStep.review) ...[
                      _buildMapView(context),
                      _buildRideTypeSelector(context, l10n, booking),
                      _buildFareSummary(context, l10n, booking),
                    ],
                    _buildSafetyBadge(context, l10n),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            if (booking.step == BookingStep.review) _buildBottomBar(context, l10n, booking),
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
              onPressed: () => context.pop(),
              icon: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: context.colorScheme.onSurface,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.ride,
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
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
                          color: context.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 2,
                        height: 28,
                        decoration: BoxDecoration(
                          color: context.colorScheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: context.colorScheme.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        _buildLocationField(
                          context,
                          controller: _pickupController,
                          focusNode: _pickupFocus,
                          hint: booking.pickupAddress.isEmpty
                              ? l10n.currentLocation
                              : booking.pickupAddress,
                          isCurrentLocation: booking.pickupAddress.isEmpty,
                          onTap: () {
                            final loc = locationAsync.valueOrNull;
                            if (loc != null) {
                              _pickupController.text = loc.detailedAddress;
                              ref.read(rideBookingProvider.notifier).setPickup(
                                    loc.detailedAddress,
                                    loc.latitude,
                                    loc.longitude,
                                  );
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildLocationField(
                          context,
                          controller: _dropoffController,
                          focusNode: _dropoffFocus,
                          hint: l10n.whereTo,
                          isCurrentLocation: false,
                          onTap: () => _showDropoffPicker(context, l10n),
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

  Widget _buildLocationField(
    BuildContext context, {
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required bool isCurrentLocation,
    required VoidCallback onTap,
  }) {
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
            if (isCurrentLocation) ...[
              Icon(
                Icons.my_location_rounded,
                size: 16,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: controller.text.isNotEmpty
                  ? Text(
                      controller.text,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : Text(
                      hint,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: isCurrentLocation
                            ? context.colorScheme.primary
                            : context.colorScheme.onSurfaceVariant,
                        fontWeight: isCurrentLocation ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.colorScheme.onSurfaceVariant,
              size: 20,
            ),
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
    return Row(
      children: [
        _buildSavedPlaceChip(
          context,
          icon: Icons.home_rounded,
          label: l10n.home,
          onTap: () {
            final loc = locationAsync.valueOrNull;
            final lat = loc?.latitude ?? 24.7136;
            final lng = loc?.longitude ?? 46.6753;
            ref.read(rideBookingProvider.notifier).setDropoff(
                  l10n.home,
                  lat,
                  lng,
                );
            _dropoffController.text = l10n.home;
          },
        ),
        const SizedBox(width: 8),
        _buildSavedPlaceChip(
          context,
          icon: Icons.work_rounded,
          label: l10n.work,
          onTap: () {
            final loc = locationAsync.valueOrNull;
            final lat = (loc?.latitude ?? 24.7136) + 0.02;
            final lng = (loc?.longitude ?? 46.6753) + 0.01;
            ref.read(rideBookingProvider.notifier).setDropoff(
                  l10n.work,
                  lat,
                  lng,
                );
            _dropoffController.text = l10n.work;
          },
        ),
      ],
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

  Widget _buildMapView(BuildContext context) {
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.colorScheme.primaryContainer.withValues(alpha: 0.3),
                context.colorScheme.secondaryContainer.withValues(alpha: 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.map_rounded,
                      size: 40,
                      color: context.colorScheme.primary.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Map View',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Google Maps integration',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.colorScheme.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'API Key Set',
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRideTypeSelector(BuildContext context, AppLocalizations l10n, RideBookingState booking) {
    final types = [
      (
        type: RideType.economy,
        name: l10n.economy,
        desc: l10n.cheapest,
        icon: Icons.directions_car_rounded,
        multiplier: 1.0,
      ),
      (
        type: RideType.comfort,
        name: l10n.comfort,
        desc: l10n.medium,
        icon: Icons.local_taxi_rounded,
        multiplier: 1.6,
      ),
      (
        type: RideType.premium,
        name: l10n.premium,
        desc: l10n.luxury,
        icon: Icons.star_rounded,
        multiplier: 2.4,
      ),
    ];

    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.chooseRideType,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...types.map((t) {
              final isSelected = booking.rideType == t.type;
              final fare = booking.estimatedFare != null
                  ? (booking.estimatedFare! * t.multiplier).toStringAsFixed(1)
                  : '—';

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => ref.read(rideBookingProvider.notifier).setRideType(t.type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.colorScheme.primaryContainer.withValues(alpha: 0.4)
                          : context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
                                : context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            t.icon,
                            color: isSelected
                                ? context.colorScheme.primary
                                : context.colorScheme.onSurfaceVariant,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.name,
                                style: context.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t.desc,
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: context.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$fare SAR',
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? context.colorScheme.primary
                                : context.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isSelected)
                          Icon(
                            Icons.check_circle_rounded,
                            color: context.colorScheme.primary,
                            size: 22,
                          ),
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

  Widget _buildFareSummary(BuildContext context, AppLocalizations l10n, RideBookingState booking) {
    if (booking.estimatedDistance == null) return const SizedBox.shrink();

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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                context,
                Icons.straighten_rounded,
                '${booking.estimatedDistance!.toStringAsFixed(1)} km',
                l10n.distance,
              ),
              Container(
                width: 1,
                height: 32,
                color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              _buildStatItem(
                context,
                Icons.schedule_rounded,
                '${booking.estimatedMinutes ?? '—'} min',
                l10n.time,
              ),
              Container(
                width: 1,
                height: 32,
                color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              _buildStatItem(
                context,
                Icons.payments_rounded,
                '${booking.estimatedFare?.toStringAsFixed(1) ?? '—'} SAR',
                l10n.fare,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: context.colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyBadge(BuildContext context, AppLocalizations l10n) {
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 500),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.green.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.shield_rounded,
                color: Colors.green[600],
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.tripProtected,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: Colors.green[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, AppLocalizations l10n, RideBookingState booking) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
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
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.error,
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: booking.isRequesting || !booking.isReadyToBook
                  ? null
                  : () async {
                      final ride = await ref.read(rideBookingProvider.notifier).confirmRide();
                      if (ride != null && context.mounted) {
                        context.push('/ride/tracking/${ride.id}');
                        ref.read(rideBookingProvider.notifier).reset();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colorScheme.primary,
                foregroundColor: context.colorScheme.onPrimary,
                disabledBackgroundColor: context.colorScheme.surfaceContainerHighest,
                disabledForegroundColor: context.colorScheme.onSurfaceVariant,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: booking.isRequesting
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: context.colorScheme.onPrimary,
                      ),
                    )
                  : Text(
                      l10n.confirmRide,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.colorScheme.onPrimary,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDropoffPicker(BuildContext context, AppLocalizations l10n) {
    final controller = TextEditingController(text: _dropoffController.text);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.whereTo,
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.enterDestination,
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: context.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildQuickDestination(
                context,
                icon: Icons.home_rounded,
                title: l10n.home,
                subtitle: l10n.savedPlace,
                onTap: () {
                  Navigator.pop(ctx);
                  _dropoffController.text = l10n.home;
                  final loc = ref.read(userLocationProvider).valueOrNull;
                  ref.read(rideBookingProvider.notifier).setDropoff(
                        l10n.home,
                        loc?.latitude ?? 24.7136,
                        loc?.longitude ?? 46.6753,
                      );
                },
              ),
              _buildQuickDestination(
                context,
                icon: Icons.work_rounded,
                title: l10n.work,
                subtitle: l10n.savedPlace,
                onTap: () {
                  Navigator.pop(ctx);
                  _dropoffController.text = l10n.work;
                  final loc = ref.read(userLocationProvider).valueOrNull;
                  ref.read(rideBookingProvider.notifier).setDropoff(
                        l10n.work,
                        (loc?.latitude ?? 24.7136) + 0.02,
                        (loc?.longitude ?? 46.6753) + 0.01,
                      );
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (controller.text.isNotEmpty) {
                      Navigator.pop(ctx);
                      _dropoffController.text = controller.text;
                      final loc = ref.read(userLocationProvider).valueOrNull;
                      final randomOffset = 0.005 + (DateTime.now().millisecond % 100) * 0.0001;
                      ref.read(rideBookingProvider.notifier).setDropoff(
                            controller.text,
                            (loc?.latitude ?? 24.7136) + randomOffset,
                            (loc?.longitude ?? 46.6753) + randomOffset,
                          );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colorScheme.primary,
                    foregroundColor: context.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    l10n.setDestination,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickDestination(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: context.colorScheme.primary, size: 22),
      ),
      title: Text(
        title,
        style: context.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: context.textTheme.bodySmall?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: context.colorScheme.onSurfaceVariant,
      ),
      contentPadding: EdgeInsets.zero,
    );
  }
}
