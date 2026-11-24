import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/constants/storage_keys.dart';
import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/_shared/feature_tour/feature_tour_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Tour content for the customer app's first run.
List<FeatureTourStep> buildCustomerTourSteps(AppLocalizations l10n) => [
  FeatureTourStep(
    icon: Icons.grid_view_rounded,
    color: const Color(0xFF2E7D6B),
    title: l10n.customerTourStep1Title,
    body: l10n.customerTourStep1Body,
  ),
  FeatureTourStep(
    icon: Icons.electric_moped_rounded,
    color: const Color(0xFF1565C0),
    title: l10n.customerTourStep2Title,
    body: l10n.customerTourStep2Body,
  ),
  FeatureTourStep(
    icon: Icons.map_rounded,
    color: const Color(0xFF6A3FB5),
    title: l10n.customerTourStep3Title,
    body: l10n.customerTourStep3Body,
  ),
  FeatureTourStep(
    icon: Icons.account_balance_wallet_rounded,
    color: const Color(0xFFC25E10),
    title: l10n.customerTourStep4Title,
    body: l10n.customerTourStep4Body,
  ),
  FeatureTourStep(
    icon: Icons.notifications_active_rounded,
    color: const Color(0xFFB03A5B),
    title: l10n.customerTourStep5Title,
    body: l10n.customerTourStep5Body,
  ),
];

/// Step-by-step guide for a merchant adding their first products.
List<FeatureTourStep> buildMerchantProductGuideSteps(AppLocalizations l10n) => [
  FeatureTourStep(
    icon: Icons.storefront_rounded,
    color: const Color(0xFF2E7D6B),
    title: l10n.merchantGuideStep1Title,
    body: l10n.merchantGuideStep1Body,
  ),
  FeatureTourStep(
    icon: Icons.add_circle_outline_rounded,
    color: const Color(0xFF1565C0),
    title: l10n.merchantGuideStep2Title,
    body: l10n.merchantGuideStep2Body,
  ),
  FeatureTourStep(
    icon: Icons.photo_camera_rounded,
    color: const Color(0xFF6A3FB5),
    title: l10n.merchantGuideStep3Title,
    body: l10n.merchantGuideStep3Body,
  ),
  FeatureTourStep(
    icon: Icons.sell_rounded,
    color: const Color(0xFFC25E10),
    title: l10n.merchantGuideStep4Title,
    body: l10n.merchantGuideStep4Body,
  ),
  FeatureTourStep(
    icon: Icons.check_circle_outline_rounded,
    color: const Color(0xFF3E8E41),
    title: l10n.merchantGuideStep5Title,
    body: l10n.merchantGuideStep5Body,
  ),
];

/// Single-flight guard shared by automatic (first-use) and manual
/// presentations: while a tour dialog is open (or opening), every other
/// request joins/ignores instead of stacking a second dialog.
Future<void>? _inFlightTour;

/// Shows [FeatureTourPage] as a full-screen dialog with a soft fade/scale in.
///
/// If a tour is already showing, returns the existing future instead of
/// opening a second dialog.
Future<void> showFeatureTour(
  BuildContext context, {
  required List<FeatureTourStep> Function(AppLocalizations l10n) stepsBuilder,
}) {
  final inFlight = _inFlightTour;
  if (inFlight != null) return inFlight;
  final future = showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: AppLocalizations.of(context).onboardingSkip,
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (dialogContext, _, _) => FeatureTourPage(
      steps: stepsBuilder(AppLocalizations.of(dialogContext)),
      onDone: () => Navigator.of(dialogContext).pop(),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
  _inFlightTour = future;
  future.whenComplete(() {
    if (identical(_inFlightTour, future)) _inFlightTour = null;
  });
  return future;
}

/// Waits briefly for a signed-in user id (the session may still be
/// restoring); returns null when there is none. The tour is never shown
/// or marked seen without a user id: completion flags are per account.
Future<String?> _resolveUserId(
  WidgetRef ref,
  String? Function()? currentUserId,
) async {
  final resolve =
      currentUserId ??
      () {
        try {
          return ref.read(supabaseClientProvider).auth.currentUser?.id;
        } catch (_) {
          // Supabase is not initialized (early startup, widget tests) or
          // the gate was unmounted mid-retry: treat as signed out.
          return null;
        }
      };
  for (var attempt = 0; attempt < 3; attempt++) {
    final id = resolve();
    if (id != null && id.isNotEmpty) return id;
    if (attempt < 2) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }
  return null;
}

/// Shows the tour once per account, remembered under
/// `storageKey@userId`.
///
/// Presentation is deferred until the underlying route is actually the
/// current one and the app is resumed, so the dialog can never cover an
/// active flow the user navigated to. If the route never settles, the
/// show is cancelled and NOTHING is written, so the next opportunity
/// tries again. The seen flag is saved only after the tour was actually
/// shown and dismissed - never on a cancelled or never-presented show.
Future<void> showFeatureTourOnce(
  BuildContext context,
  WidgetRef ref, {
  required String storageKey,
  required List<FeatureTourStep> Function(AppLocalizations l10n) stepsBuilder,
  String? Function()? currentUserId,
}) async {
  if (_inFlightTour != null) return;
  final prefs = ref.read(sharedPreferencesProvider);
  final userId = await _resolveUserId(ref, currentUserId);
  if (userId == null || !context.mounted) return;
  final key = '$storageKey@$userId';
  if (prefs.getBool(key: key)) return;

  final route = ModalRoute.of(context);
  // Let the underlying page settle; re-check that it is still the
  // current route and the app is resumed before covering it. A few
  // bounded retries, then cancel unmarked.
  for (var attempt = 0; attempt < 3; attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!context.mounted) return;
    final currentRoute = ModalRoute.of(context);
    final sameRoute = currentRoute == route && (route?.isCurrent ?? true);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final resumed = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    if (!sameRoute || !resumed) continue;
    if (_inFlightTour != null) return; // someone else opened a tour
    await showFeatureTour(context, stepsBuilder: stepsBuilder);
    // The tour was actually shown and dismissed: only now mark it seen.
    await prefs.saveBool(key: key, value: true);
    return;
  }
  // Route never settled: cancelled, nothing written.
}

/// Wraps a page and auto-shows a first-use tour over it once per install.
class FeatureTourGate extends ConsumerStatefulWidget {
  const FeatureTourGate({
    super.key,
    required this.storageKey,
    required this.stepsBuilder,
    required this.child,
    this.currentUserId,
  });

  final String storageKey;
  final List<FeatureTourStep> Function(AppLocalizations l10n) stepsBuilder;
  final Widget child;

  /// Test seam: overrides reading the signed-in user from Supabase auth.
  final String? Function()? currentUserId;

  @override
  ConsumerState<FeatureTourGate> createState() => _FeatureTourGateState();
}

class _FeatureTourGateState extends ConsumerState<FeatureTourGate> {
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scheduled || !mounted) return;
      _scheduled = true;
      showFeatureTourOnce(
        context,
        ref,
        storageKey: widget.storageKey,
        stepsBuilder: widget.stepsBuilder,
        currentUserId: widget.currentUserId,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// First-use tour shown over the customer home page once per install.
class CustomerFirstUseTourGate extends StatelessWidget {
  const CustomerFirstUseTourGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FeatureTourGate(
      storageKey: StorageKeys.firstUseTourCustomer,
      stepsBuilder: buildCustomerTourSteps,
      child: child,
    );
  }
}
