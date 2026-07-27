import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/ride/domain/entities/ride.dart';
import 'package:delwaqty/features/ride/presentation/providers/ride_providers.dart';
import 'package:delwaqty/features/ride/presentation/widgets/ride_map.dart';
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
  bool _ratingShown = false;
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

  String _money(BuildContext context, double amount) {
    final l10n = AppLocalizations.of(context);
    return l10n.amountWithCurrency(amount.toStringAsFixed(0), l10n.currencySymbol);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rideAsync = ref.watch(rideStreamProvider(widget.rideId));

    ref.listen(rideStreamProvider(widget.rideId), (prev, next) {
      final ride = next.valueOrNull;
      if (ride == null) return;
      if (ride.status == RideStatus.completed && !_ratingShown) {
        _ratingShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showRatingDialog(context, l10n);
        });
      } else if (ride.status == RideStatus.cancelled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.canPop()) context.pop();
        });
      }
    });

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: SafeArea(
        child: rideAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _buildError(context, l10n),
          data: (ride) => _buildContent(context, l10n, ride),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, AppLocalizations l10n) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline_rounded,
            size: 48, color: context.colorScheme.error),
        const SizedBox(height: 12),
        Text(l10n.errorLoading),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => ref.invalidate(rideStreamProvider(widget.rideId)),
          child: Text(l10n.retry),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations l10n, Ride ride) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(context, l10n),
                _buildStatusSteps(context, l10n, ride.status),
                if (ride.status == RideStatus.searching)
                  _buildSearching(context, l10n)
                else
                  _buildDriverCard(context, l10n, ride),
                _buildTrackingMap(context, ride),
                if (ride.status == RideStatus.matched ||
                    ride.status == RideStatus.arrived)
                  _buildOtpCard(context, l10n, ride),
                _buildBottomDetails(context, l10n, ride),
              ],
            ),
          ),
        ),
        _buildBottomActions(context, l10n, ride),
      ],
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
                child: Icon(Icons.arrow_back_rounded,
                    color: context.colorScheme.onSurface, size: 22),
              ),
            ),
            const SizedBox(width: 8),
            Text(l10n.trackRide,
                style: context.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  int _statusIndex(RideStatus status) {
    switch (status) {
      case RideStatus.searching:
        return 0;
      case RideStatus.matched:
        return 1;
      case RideStatus.arrived:
        return 2;
      case RideStatus.inTrip:
        return 3;
      case RideStatus.completed:
        return 4;
      case RideStatus.cancelled:
        return 1;
    }
  }

  Widget _buildStatusSteps(
      BuildContext context, AppLocalizations l10n, RideStatus status) {
    final active = _statusIndex(status);
    final steps = [
      (label: l10n.searchingForDriver, icon: Icons.search_rounded),
      (label: l10n.matched, icon: Icons.person_add_rounded),
      (label: l10n.arrived, icon: Icons.location_on_rounded),
      (label: l10n.inTrip, icon: Icons.navigation_rounded),
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
                color: context.colorScheme.outlineVariant.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(steps.length * 2 - 1, (index) {
              if (index.isOdd) {
                final prevDone = ((index - 1) ~/ 2) < active;
                return Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: prevDone
                          ? context.colorScheme.primary
                          : context.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                );
              }
              final stepIndex = index ~/ 2;
              final step = steps[stepIndex];
              final done = stepIndex < active;
              final current = stepIndex == active;
              return Column(
                children: [
                  ScaleTransition(
                    scale: current
                        ? _pulseAnimation
                        : const AlwaysStoppedAnimation(1.0),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: done
                            ? context.colorScheme.primary
                            : current
                                ? context.colorScheme.primaryContainer
                                : context.colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        step.icon,
                        size: 18,
                        color: done
                            ? context.colorScheme.onPrimary
                            : current
                                ? context.colorScheme.primary
                                : context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 64,
                    child: Text(
                      step.label,
                      style: context.textTheme.labelSmall?.copyWith(
                        fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                        color: current
                            ? context.colorScheme.primary
                            : context.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildSearching(BuildContext context, AppLocalizations l10n) {
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(24),
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: context.colorScheme.outlineVariant.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: context.colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.search_rounded,
                      color: context.colorScheme.primary, size: 32),
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.searchingForDriver,
                  style: context.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(l10n.waitingForAcceptance,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDriverCard(
      BuildContext context, AppLocalizations l10n, Ride ride) {
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
                color: context.colorScheme.outlineVariant.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: context.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.person_rounded,
                    color: context.colorScheme.primary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ride.driverName ?? l10n.yourDriver,
                        style: context.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      '${ride.vehicleColor ?? ''} ${ride.vehicleType ?? ''}'.trim(),
                      style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant),
                    ),
                    if (ride.vehiclePlate != null) ...[
                      const SizedBox(height: 2),
                      Text(ride.vehiclePlate!,
                          style: context.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.colorScheme.primary,
                              letterSpacing: 1)),
                    ],
                  ],
                ),
              ),
              if (ride.driverPhone != null)
                _buildActionCircle(context,
                    icon: Icons.call_rounded,
                    color: AppColors.successLight,
                    onTap: () => launchUrl(Uri.parse('tel:${ride.driverPhone}')),),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCircle(BuildContext context,
      {required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildOtpCard(BuildContext context, AppLocalizations l10n, Ride ride) {
    if (ride.pickupOtp == null) return const SizedBox.shrink();
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 250),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colorScheme.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(l10n.pickupCode,
                  style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: ride.pickupOtp!.split('').map((d) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: 44,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(d,
                        style: context.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: context.colorScheme.primary)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(l10n.shareCodeWithDriver,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackingMap(BuildContext context, Ride ride) {
    final driver = (ride.driverLatitude != null && ride.driverLongitude != null)
        ? LatLng(ride.driverLatitude!, ride.driverLongitude!)
        : null;
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: RideMap(
          pickup: LatLng(ride.pickupLatitude, ride.pickupLongitude),
          dropoff: LatLng(ride.dropoffLatitude, ride.dropoffLongitude),
          driver: driver,
        ),
      ),
    );
  }

  Widget _buildBottomDetails(
      BuildContext context, AppLocalizations l10n, Ride ride) {
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _addressRow(context, context.colorScheme.primary, ride.pickupAddress),
              Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Container(
                    width: 2,
                    height: 20,
                    color:
                        context.colorScheme.outlineVariant.withValues(alpha: 0.4)),
              ),
              _addressRow(context, context.colorScheme.error, ride.dropoffAddress),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _tripStat(context, Icons.straighten_rounded,
                      '${ride.distance?.toStringAsFixed(1) ?? '—'} ${l10n.kmUnit}'),
                  _tripStat(context, Icons.schedule_rounded,
                      '${ride.estimatedMinutes ?? '—'} ${l10n.minutesShort}'),
                  _tripStat(context, Icons.payments_rounded,
                      _money(context, ride.fare ?? 0)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addressRow(BuildContext context, Color color, String address) {
    return Row(
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(address,
              style: context.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _tripStat(BuildContext context, IconData icon, String value) {
    return Column(
      children: [
        Icon(icon, size: 18, color: context.colorScheme.primary),
        const SizedBox(height: 4),
        Text(value,
            style: context.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildBottomActions(
      BuildContext context, AppLocalizations l10n, Ride ride) {
    final canCancel = ride.status == RideStatus.searching ||
        ride.status == RideStatus.matched ||
        ride.status == RideStatus.arrived;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        border: Border(
          top: BorderSide(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.2)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _shareTrip(context, l10n),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: Text(l10n.shareTrip),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colorScheme.primary,
                  side: BorderSide(
                      color: context.colorScheme.primary.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
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
                  backgroundColor: AppColors.errorLight,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (canCancel) ...[
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showCancelDialog(context, l10n),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text(l10n.cancel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colorScheme.error,
                    side: BorderSide(
                        color: context.colorScheme.error.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _shareTrip(BuildContext context, AppLocalizations l10n) {
    ref.read(rideRepositoryProvider).shareTrip(widget.rideId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.tripShared),
        backgroundColor: AppColors.successLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSosDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.emergency_share_rounded, color: AppColors.errorLight, size: 48),
        title: Text(l10n.emergencyAlert),
        content: Text(l10n.emergencyConfirmation),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(rideRepositoryProvider).reportIssue(widget.rideId, 'SOS');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.emergencyServicesNotified),
                  backgroundColor: AppColors.errorLight,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorLight, foregroundColor: Theme.of(context).colorScheme.onPrimary),
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons.map((reason) {
              return ListTile(
                title: Text(reason),
                onTap: () {
                  Navigator.pop(ctx);
                  ref
                      .read(rideRepositoryProvider)
                      .cancelRide(widget.rideId, reason: reason);
                },
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.cancel_outlined,
                    color: context.colorScheme.error, size: 20),
              );
            }).toList(),
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.keepRide)),
        ],
      ),
    );
  }

  void _showRatingDialog(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
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
                  Text(l10n.rateYourTrip,
                      style: context.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(l10n.rateDriverPrompt,
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () =>
                            setSheetState(() => _selectedRating = index + 1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            index < _selectedRating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 44,
                            color: index < _selectedRating
                                ? AppColors.rating
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
                            borderRadius: BorderRadius.circular(14)),
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
                              if (context.canPop()) context.pop();
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colorScheme.primary,
                        foregroundColor: context.colorScheme.onPrimary,
                        disabledBackgroundColor:
                            context.colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(l10n.submitRating,
                          style: context.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
