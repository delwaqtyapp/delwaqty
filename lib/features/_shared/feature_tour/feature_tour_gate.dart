import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/constants/storage_keys.dart';
import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';
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

/// Shows [FeatureTourPage] as a full-screen dialog with a soft fade/scale in.
Future<void> showFeatureTour(
  BuildContext context, {
  required List<FeatureTourStep> Function(AppLocalizations l10n) stepsBuilder,
}) {
  return showGeneralDialog<void>(
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
}

/// Shows the tour once per install, remembered under [storageKey].
///
/// The flag is saved before the dialog opens so a fast rebuild can never
/// double-show it; worst case a killed app simply never shows the tour.
Future<void> showFeatureTourOnce(
  BuildContext context,
  WidgetRef ref, {
  required String storageKey,
  required List<FeatureTourStep> Function(AppLocalizations l10n) stepsBuilder,
}) async {
  final prefs = ref.read(sharedPreferencesProvider);
  if (prefs.getBool(key: storageKey)) return;
  await prefs.saveBool(key: storageKey, value: true);
  // Let the underlying page settle before covering it.
  await Future<void>.delayed(const Duration(milliseconds: 500));
  if (!context.mounted) return;
  await showFeatureTour(context, stepsBuilder: stepsBuilder);
}

/// Wraps a page and auto-shows a first-use tour over it once per install.
class FeatureTourGate extends ConsumerStatefulWidget {
  const FeatureTourGate({
    super.key,
    required this.storageKey,
    required this.stepsBuilder,
    required this.child,
  });

  final String storageKey;
  final List<FeatureTourStep> Function(AppLocalizations l10n) stepsBuilder;
  final Widget child;

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
