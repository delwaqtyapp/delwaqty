import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/ride/domain/entities/ride.dart';
import 'package:delwaqty/features/ride/presentation/providers/ride_providers.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';

class RideTrackingPage extends ConsumerStatefulWidget {
  const RideTrackingPage({required this.rideId, super.key});

  final String rideId;

  @override
  ConsumerState<RideTrackingPage> createState() => _RideTrackingPageState();
}

class _RideTrackingPageState extends ConsumerState<RideTrackingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  int _selectedRating = 0;
  final _feedbackController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final booking = ref.watch(rideBookingProvider);

    final mockRide = Ride(
      id: widget.rideId,
      riderId: 'current-user',
      pickupLatitude: booking.pickupLatitude ?? 24.7136,
      pickupLongitude: booking.pickupLongitude ?? 46.6753,
      pickupAddress: booking.pickupAddress.isNotEmpty ? booking.pickupAddress : l10n.currentLocation,
      dropoffLatitude: booking.dropoffLatitude ?? 24.6877,
      dropoffLongitude: booking.dropoffLongitude ?? 46.7219,
      dropoffAddress: booking.dropoffAddress.isNotEmpty ? booking.dropoffAddress : l10n.destination,
      rideType: booking.rideType,
      status: RideStatus.matched,
      fare: booking.estimatedFare ?? 25.0,
      distance: booking.estimatedDistance ?? 8.5,
      estimatedMinutes: booking.estimatedMinutes ?? 18,
      driverName: 'Ahmed Mohammed',
      driverPhone: '+966501234567',
      driverPhoto: null,
      vehicleType: 'Toyota Camry',
      vehiclePlate: 'ABC 1234',
      vehicleColor: 'White',
      createdAt: DateTime.now(),
      matchedAt: DateTime.now().subtract(const Duration(minutes: 2)),
    );

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeader(context, l10n),
                    _buildStatusSteps(context, l10n, mockRide.status),
                    _buildDriverCard(context, l10n, mockRide),
                    _buildTrackingMap(context, l10n),
                    _buildBottomDetails(context, l10n, mockRide),
                  ],
                ),
              ),
            ),
            _buildBottomActions(context, l10n, mockRide),
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
              l10n.trackRide,
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSteps(BuildContext context, AppLocalizations l10n, RideStatus status) {
    final steps = [
      (label: l10n.matched, icon: Icons.person_add_rounded, completed: true),
      (label: l10n.driverArriving, icon: Icons.directions_car_rounded, completed: false),
      (label: l10n.inTrip, icon: Icons.navigation_rounded, completed: false),
      (label: l10n.arrived, icon: Icons.location_on_rounded, completed: false),
    ];

    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 100),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(steps.length * 2 - 1, (index) {
              if (index.isOdd) {
                final prevCompleted = steps[(index - 1) ~/ 2].completed;
                return Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: prevCompleted
                          ? context.colorScheme.primary
                          : context.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                );
              }
              final stepIndex = index ~/ 2;
              final step = steps[stepIndex];
              return Column(
                children: [
                  ScaleTransition(
                    scale: stepIndex == 1 ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: step.completed
                            ? context.colorScheme.primary
                            : stepIndex == 1
                                ? context.colorScheme.primaryContainer
                                : context.colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        step.icon,
                        size: 18,
                        color: step.completed
                            ? context.colorScheme.onPrimary
                            : stepIndex == 1
                                ? context.colorScheme.primary
                                : context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    step.label,
                    style: context.textTheme.labelSmall?.copyWith(
                      fontWeight: stepIndex == 1 ? FontWeight.w700 : FontWeight.w500,
                      color: stepIndex == 1
                          ? context.colorScheme.primary
                          : context.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildDriverCard(BuildContext context, AppLocalizations l10n, Ride ride) {
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.colorScheme.primaryContainer,
                      context.colorScheme.primaryContainer.withValues(alpha: 0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: context.colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ride.driverName ?? 'Driver',
                      style: context.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 16, color: Colors.amber[600]),
                        const SizedBox(width: 2),
                        Text(
                          '4.8',
                          style: context.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${ride.vehicleColor ?? ''} ${ride.vehicleType ?? ''}',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ride.vehiclePlate ?? '',
                      style: context.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.colorScheme.primary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  _buildActionCircle(
                    context,
                    icon: Icons.call_rounded,
                    color: Colors.green,
                    onTap: () {},
                  ),
                  const SizedBox(height: 8),
                  _buildActionCircle(
                    context,
                    icon: Icons.chat_rounded,
                    color: context.colorScheme.primary,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCircle(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildTrackingMap(BuildContext context, AppLocalizations l10n) {
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.colorScheme.primaryContainer.withValues(alpha: 0.3),
                context.colorScheme.secondaryContainer.withValues(alpha: 0.2),
                context.colorScheme.tertiaryContainer.withValues(alpha: 0.15),
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
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: context.colorScheme.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.directions_car_rounded,
                              color: context.colorScheme.primary,
                              size: 32,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.driverEnRoute,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.colorScheme.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_rounded, size: 14, color: context.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        '5 min',
                        style: context.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomDetails(BuildContext context, AppLocalizations l10n, Ride ride) {
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
                children: [
                  Icon(Icons.circle, size: 8, color: context.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ride.pickupAddress,
                      style: context.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Container(
                  width: 2,
                  height: 20,
                  decoration: BoxDecoration(
                    color: context.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.circle, size: 8, color: context.colorScheme.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ride.dropoffAddress,
                      style: context.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTripStat(
                    context,
                    Icons.straighten_rounded,
                    '${ride.distance?.toStringAsFixed(1) ?? '—'} km',
                  ),
                  _buildTripStat(
                    context,
                    Icons.schedule_rounded,
                    '${ride.estimatedMinutes ?? '—'} min',
                  ),
                  _buildTripStat(
                    context,
                    Icons.payments_rounded,
                    '${ride.fare?.toStringAsFixed(1) ?? '—'} SAR',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripStat(BuildContext context, IconData icon, String value) {
    return Column(
      children: [
        Icon(icon, size: 18, color: context.colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: context.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(BuildContext context, AppLocalizations l10n, Ride ride) {
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
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showShareTripDialog(context, l10n),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: Text(l10n.shareTrip),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colorScheme.primary,
                  side: BorderSide(color: context.colorScheme.primary.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showSosDialog(context, l10n),
                icon: const Icon(Icons.emergency_share_rounded, size: 18),
                label: Text(l10n.sos),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showCancelDialog(context, l10n),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: Text(l10n.cancel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colorScheme.error,
                  side: BorderSide(color: context.colorScheme.error.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShareTripDialog(BuildContext context, AppLocalizations l10n) {
    ref.read(rideRepositoryProvider).shareTrip(widget.rideId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.tripShared),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSosDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.emergency_share_rounded, color: Colors.red, size: 48),
        title: Text(l10n.emergencyAlert),
        content: Text(l10n.emergencyConfirmation),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(rideRepositoryProvider).reportIssue(widget.rideId, 'SOS');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.emergencyServicesNotified),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.confirmSOS),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, AppLocalizations l10n) {
    final reasons = [
      l10n.cancelReasonWrongAddress,
      l10n.cancelReasonChangedMind,
      l10n.cancelReasonDriverDelay,
      l10n.cancelReasonOther,
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cancelRide),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.map((reason) {
            return ListTile(
              title: Text(reason),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(rideRepositoryProvider).cancelRide(widget.rideId, reason: reason);
                context.pop();
              },
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.cancel_outlined,
                color: context.colorScheme.error,
                size: 20,
              ),
            );
          }).toList(),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.keepRide),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                l10n.rateYourTrip,
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.rateDriverPrompt,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () => setSheetState(() => _selectedRating = index + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        index < _selectedRating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 44,
                        color: index < _selectedRating
                            ? Colors.amber[600]
                            : context.colorScheme.outlineVariant,
                      ),
                    ),
                  );
                }),
              ),
              if (_selectedRating > 0) ...[
                const SizedBox(height: 20),
                TextField(
                  controller: _feedbackController,
                  decoration: InputDecoration(
                    hintText: l10n.addFeedback,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  maxLines: 3,
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _selectedRating > 0
                      ? () {
                          ref.read(rideRepositoryProvider).rateRide(
                                widget.rideId,
                                _selectedRating,
                                feedback: _feedbackController.text.isNotEmpty
                                    ? _feedbackController.text
                                    : null,
                              );
                          Navigator.pop(ctx);
                          context.go('/ride/book');
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colorScheme.primary,
                    foregroundColor: context.colorScheme.onPrimary,
                    disabledBackgroundColor: context.colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    l10n.submitRating,
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
}
