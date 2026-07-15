import 'package:flutter/material.dart';

/// Animation design tokens for the Delwaqty platform.
///
/// Provides standardised durations and curves so that motion remains
/// consistent across every screen in the application.
abstract final class AppAnimation {
  // ---------------------------------------------------------------------------
  // Duration Constants
  // ---------------------------------------------------------------------------

  /// Instant transition — 100ms. Used for micro-interactions (opacity flicks, toggle snaps).
  static const Duration instant = Duration(milliseconds: 100);

  /// Fast transition — 200ms. Used for small UI changes (button press feedback).
  static const Duration fast = Duration(milliseconds: 200);

  /// Normal transition — 300ms. Default for most UI transitions (panels, cards).
  static const Duration normal = Duration(milliseconds: 300);

  /// Slow transition — 500ms. Used for larger layout shifts (page element reveals).
  static const Duration slow = Duration(milliseconds: 500);

  /// Very slow transition — 800ms. Used for splash / hero-style animations.
  static const Duration verySlow = Duration(milliseconds: 800);

  // ---------------------------------------------------------------------------
  // Curve Constants
  // ---------------------------------------------------------------------------

  /// Standard easing curve (decelerate) for entering elements.
  static const Curve standard = Curves.easeOutCubic;

  /// Decelerate curve for elements appearing on screen.
  static const Curve decelerate = Curves.decelerate;

  /// Accelerate curve for elements exiting the screen.
  static const Curve accelerate = Curves.easeInCubic;

  /// Sharp curve — quick start and end with a long middle.
  static const Curve sharp = Curves.easeInOutCubic;

  /// Bounce curve for playful emphasis animations.
  static const Curve bounce = Curves.elasticOut;

  // ---------------------------------------------------------------------------
  // Page Transition Durations
  // ---------------------------------------------------------------------------

  /// Default duration for page transitions.
  static const Duration pageTransitionDuration = normal;

  /// Duration for modal / dialog transitions.
  static const Duration modalTransitionDuration = fast;

  /// Duration for bottom sheet transitions.
  static const Duration bottomSheetTransitionDuration = normal;

  // ---------------------------------------------------------------------------
  // Convenience Curves
  // ---------------------------------------------------------------------------

  /// [CurveTween] wrapping [standard] for use with animation controllers.
  static final CurveTween standardTween = CurveTween(curve: standard);

  /// [CurveTween] wrapping [decelerate] for use with animation controllers.
  static final CurveTween decelerateTween = CurveTween(curve: decelerate);

  /// [CurveTween] wrapping [accelerate] for use with animation controllers.
  static final CurveTween accelerateTween = CurveTween(curve: accelerate);

  /// [CurveTween] wrapping [sharp] for use with animation controllers.
  static final CurveTween sharpTween = CurveTween(curve: sharp);

  /// [CurveTween] wrapping [bounce] for use with animation controllers.
  static final CurveTween bounceTween = CurveTween(curve: bounce);
}
