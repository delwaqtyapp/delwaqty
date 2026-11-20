// =============================================================================
// DelWaQty intro / splash.
//
// Bundled reference design:
//   * full-screen Pyramids / Nile background (BoxFit.cover) + light dim layer
//   * "Egypt" statement block pinned top-right inside SafeArea
//   * transparent logo (assets/egypt/delwaqty_logo_mark.webp) centered with a
//     soft purple/blue/cyan halo and a Fade + Scale (0.88 -> 1.0) reveal
//   * a quiet vertical light strip sweeping the Nile bottom -> top
//   * "DelwaQty" wordmark (Delwa white, Qty purple/blue/cyan gradient)
//   * Arabic tagline "دلوقتي" + descriptions
//   * "Made in Egypt" footer with the Egyptian flag emoji
//
// One AnimationController drives every stage with t (0..1 over 9s, content
// 4.5s, quiet-hold 0.8s, then a smooth route transition). All controllers are
// disposed; reduce-motion (disableAnimations) is respected.
//
// A restore point for the previous cinematic variant lives in
// `delwa_intro_cinematic_v1.dart` (class DelwaIntroSceneV1).
// =============================================================================
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class IntroAssets {
  IntroAssets._();

  static const String logo = 'assets/egypt/delwaqty_logo_mark.webp';
  static const String background =
      'assets/egypt/intro_egypt_cinematic_background.webp';
}

class DelwaIntroScene extends StatefulWidget {
  const DelwaIntroScene({super.key});

  @override
  State<DelwaIntroScene> createState() => _DelwaIntroSceneState();
}

class _DelwaIntroSceneState extends State<DelwaIntroScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  Timer? _navTimer;
  bool _navigated = false;

  static const _totalDuration = Duration(milliseconds: 9000);
  static const _contentDuration = Duration(milliseconds: 4500);
  static const _holdDuration = Duration(milliseconds: 800);

  static const _gradientPurple = Color(0xFF6C3CEB);
  static const _gradientBlue = Color(0xFF4057D8);
  static const _gradientCyan = Color(0xFF19C8C8);
  static const _gold = Color(0xFFD8A84E);
  static const _textNearWhite = Color(0xFFF7F7FA);

  static const _wordmarkStyle = TextStyle(
    fontFamily: 'Cairo',
    fontSize: 34,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 1.2,
  );
  double _gradWhiteEnd = 0.5;
  late double _gradBlueStop;

  void _measureWordmark(TextScaler textScaler) {
    final tp = TextPainter(
      text: const TextSpan(text: 'DelwaQty', style: _wordmarkStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    double aEnd = tp.width * 0.625;
    if (tp.width > 0) {
      final box = tp.getBoxesForSelection(
        const TextSelection(baseOffset: 4, extentOffset: 5),
      );
      if (box.isNotEmpty) {
        aEnd = box.first.right;
      }
    }
    _gradWhiteEnd = tp.width > 0 ? aEnd / tp.width : 0.5;
    _gradBlueStop = _gradWhiteEnd + (1 - _gradWhiteEnd) * 0.5111111111;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _measureWordmark(MediaQuery.textScalerOf(context));
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _totalDuration);
    final reduced = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    if (reduced) {
      _ctrl.value = 1.0;
    } else {
      _ctrl.forward();
    }
    _navTimer = Timer(_contentDuration + _holdDuration, _go);
  }

  void _go() {
    if (!mounted || _navigated) return;
    _navigated = true;
    context.go('/login');
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  double _clamp(double v) => v.clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) {
            final t = _ctrl.value;

            final bgFade = Curves.easeIn.transform(_clamp(t / 0.045));
            final bgScale =
                1.0 + 0.03 * Curves.linear.transform(_clamp(t / 1.0));

            // 1.5) Modern luxury opening light curtain & expanding royal aura rings.
            final openingCurtain =
                _clamp(t / 0.08) * (1 - _clamp((t - 0.34) / 0.16));
            final openingRingProgress = Curves.easeOutCubic.transform(
              _clamp((t - 0.04) / 0.36),
            );
            final openingRingOpacity =
                _clamp((t - 0.03) / 0.08) * (1 - _clamp((t - 0.32) / 0.12));

            // 2) Nile light: quiet bottom -> top sweep (about 2.4s).
            const nileStart = 0.055;
            final nileProgress = Curves.easeInOutCubic.transform(
              _clamp((t - nileStart) / 0.275),
            );
            final nileStripOpacity =
                _clamp((t - nileStart) / 0.10) *
                (1 - _clamp((t - 0.40) / 0.08));
            final nileReflectionOpacity =
                _clamp((t - 0.08) / 0.12) * (1 - _clamp((t - 0.36) / 0.10));

            // 3) Halo around the logo.
            const haloStart = 0.20;
            final haloOpacity = _clamp((t - haloStart) / 0.12);
            final haloPulse =
                0.16 + 0.08 * (0.5 + 0.5 * math.sin(t * math.pi * 3));
            final haloEffective = haloOpacity * haloPulse;

            // 4) Logo Fade + Scale (UNTOUCHED per user instruction).
            const logoStart = 0.24;
            final logoOpacity = Curves.easeOutCubic.transform(
              _clamp((t - logoStart) / 0.14),
            );
            final logoScale =
                0.88 +
                0.12 *
                    Curves.easeOutCubic.transform(
                      _clamp((t - logoStart) / 0.15),
                    );

            // 5) DelwaQty wordmark (rise from the bottom with smooth modern glide).
            final delwaQtyFade = Curves.easeOutCubic.transform(
              _clamp((t - 0.34) / 0.10),
            );
            final delwaQtySlide =
                18.0 *
                (1 - Curves.easeOutBack.transform(_clamp((t - 0.34) / 0.13)));

            // 6) Arabic name + descriptions.
            final dalwaqtyFade = Curves.easeOutCubic.transform(
              _clamp((t - 0.37) / 0.09),
            );
            final dalwaqtySlide =
                10.0 *
                (1 - Curves.easeOutCubic.transform(_clamp((t - 0.37) / 0.10)));
            final arabicTagFade = Curves.easeOutCubic.transform(
              _clamp((t - 0.40) / 0.07),
            );
            final englishTagFade = Curves.easeOutCubic.transform(
              _clamp((t - 0.42) / 0.07),
            );

            // 7) Egypt statement, top-right, appears with modern slide-in.
            final egyptStatementFade = Curves.easeOutCubic.transform(
              _clamp((t - 0.40) / 0.09),
            );
            final egyptStatementSlide =
                10.0 *
                (1 - Curves.easeOutCubic.transform(_clamp((t - 0.40) / 0.11)));

            // 8) Made in Egypt footer.
            final madeInEgyptFade = Curves.easeOutCubic.transform(
              _clamp((t - 0.43) / 0.07),
            );

            final screenWidth = MediaQuery.of(context).size.width;
            final screenHeight = MediaQuery.of(context).size.height;
            final isCompactHeight = screenHeight < 560;
            final logoSize = (screenWidth * 0.30).clamp(110.0, 140.0);
            final logoCenterY = screenHeight * (isCompactHeight ? 0.34 : 0.36);

            return Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: bgFade,
                  child: Transform.scale(
                    scale: bgScale,
                    child: const _IntroImage(
                      assetPath: IntroAssets.background,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Light dim layer — keeps the pyramids, the Nile and the
                // Cairo lights clearly visible while boosting text contrast.
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF0D0824).withValues(alpha: 0.28),
                          const Color(0xFF120A30).withValues(alpha: 0.14),
                          const Color(0xFF0B061E).withValues(alpha: 0.34),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                // Modern luxury opening light horizon & expanding royal rings.
                if (openingCurtain > 0.01)
                  IgnorePointer(
                    child: Opacity(
                      opacity: openingCurtain,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0.0, -0.15),
                            radius: 0.95 + 0.35 * openingRingProgress,
                            colors: [
                              _gold.withValues(alpha: 0.18),
                              _gradientPurple.withValues(alpha: 0.14),
                              _gradientCyan.withValues(alpha: 0.06),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.38, 0.72, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (openingRingOpacity > 0.01)
                  Positioned(
                    left: 0,
                    right: 0,
                    top:
                        logoCenterY -
                        logoSize * (0.9 + 0.65 * openingRingProgress),
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: openingRingOpacity,
                        child: Center(
                          child: Container(
                            width: logoSize * (1.8 + 1.3 * openingRingProgress),
                            height:
                                logoSize * (1.8 + 1.3 * openingRingProgress),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _gold.withValues(alpha: 0.28),
                                width: 1.2,
                              ),
                              gradient: RadialGradient(
                                colors: [
                                  Colors.transparent,
                                  _gold.withValues(alpha: 0.07),
                                  _gradientCyan.withValues(alpha: 0.08),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.68, 0.9, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Subtle floating golden stardust motes around the horizon.
                IgnorePointer(
                  child: _buildGoldenStardust(
                    t: t,
                    screenWidth: screenWidth,
                    screenHeight: screenHeight,
                  ),
                ),
                // Nile light strip: soft vertical gradient sweeping up.
                IgnorePointer(
                  child: Opacity(
                    opacity: nileStripOpacity,
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment(0, 1 - 2 * nileProgress),
                        child: Container(
                          width: screenWidth * 0.22,
                          height: screenHeight * 0.60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(40),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                _gradientCyan.withValues(alpha: 0.0),
                                _gradientCyan.withValues(alpha: 0.13),
                                _gradientBlue.withValues(alpha: 0.10),
                                _gradientPurple.withValues(alpha: 0.07),
                                _gradientPurple.withValues(alpha: 0.0),
                              ],
                              stops: const [0.0, 0.40, 0.65, 0.90, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (nileReflectionOpacity > 0.01)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: screenHeight * 0.35,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: nileReflectionOpacity,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(0.0, 0.55),
                              radius: 1.2,
                              colors: [
                                _gradientCyan.withValues(alpha: 0.10),
                                _gradientBlue.withValues(alpha: 0.05),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Soft purple/blue/cyan halo.
                Positioned(
                  left: 0,
                  right: 0,
                  top: logoCenterY - logoSize * 1.05,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: haloEffective,
                      child: Center(
                        child: Container(
                          width: logoSize * 2.1,
                          height: logoSize * 2.1,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                _gradientPurple.withValues(alpha: 0.16),
                                _gradientBlue.withValues(alpha: 0.09),
                                _gradientCyan.withValues(alpha: 0.05),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.45, 0.75, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Transparent logo, centered above the wordmark (UNTOUCHED).
                Positioned(
                  left: 0,
                  right: 0,
                  top: logoCenterY - logoSize / 2,
                  child: Center(
                    child: Opacity(
                      opacity: logoOpacity,
                      child: Transform.scale(
                        scale: logoScale,
                        child: _IntroImage(
                          assetPath: IntroAssets.logo,
                          width: logoSize,
                          height: logoSize,
                          cacheWidth:
                              (logoSize *
                                      MediaQuery.of(context).devicePixelRatio)
                                  .round(),
                          cacheHeight:
                              (logoSize *
                                      MediaQuery.of(context).devicePixelRatio)
                                  .round(),
                          fit: BoxFit.contain,
                          fallbackBuilder: (context) => Container(
                            width: logoSize,
                            height: logoSize,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [_gradientPurple, _gradientCyan],
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'D',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 48,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // DelwaQty wordmark + Arabic name + descriptions (improved position & colors).
                Positioned(
                  left: 16,
                  right: 16,
                  top: logoCenterY + logoSize / 2 + (isCompactHeight ? 8 : 14),
                  child: Opacity(
                    opacity: delwaQtyFade,
                    child: Transform.translate(
                      offset: Offset(0, delwaQtySlide),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: ShaderMask(
                              shaderCallback: (Rect bounds) {
                                final whiteEnd = _gradWhiteEnd;
                                return LinearGradient(
                                  colors: const [
                                    Color(0xFFFFFFFF),
                                    Color(0xFFF7F7FA),
                                    _gradientPurple,
                                    _gradientBlue,
                                    _gradientCyan,
                                  ],
                                  stops: [
                                    0.0,
                                    whiteEnd,
                                    whiteEnd,
                                    _gradBlueStop,
                                    1.0,
                                  ],
                                ).createShader(bounds);
                              },
                              child: const Text(
                                'DelwaQty',
                                style: _wordmarkStyle,
                              ),
                            ),
                          ),
                          SizedBox(height: isCompactHeight ? 4 : 6),
                          Opacity(
                            opacity: dalwaqtyFade,
                            child: Transform.translate(
                              offset: Offset(0, dalwaqtySlide),
                              child: Directionality(
                                textDirection: TextDirection.rtl,
                                child: ShaderMask(
                                  shaderCallback: (Rect bounds) {
                                    return const LinearGradient(
                                      colors: [
                                        Color(0xFFFFF3C4),
                                        Color(0xFFF4C96B),
                                        Color(0xFFFFF6D6),
                                      ],
                                    ).createShader(bounds);
                                  },
                                  child: const Text(
                                    'دلوقتي',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 27,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.6,
                                      shadows: [
                                        Shadow(
                                          color: Color(0x66000000),
                                          blurRadius: 12,
                                          offset: Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: isCompactHeight ? 6 : 10),
                          Opacity(
                            opacity: arabicTagFade,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF140B30)
                                    .withValues(alpha: 0.44),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: _gold.withValues(alpha: 0.34),
                                ),
                              ),
                              child: const Directionality(
                                textDirection: TextDirection.rtl,
                                child: Text(
                                  'كل احتياجاتك... في تطبيق واحد',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFFFFDF7),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: isCompactHeight ? 3 : 6),
                          Opacity(
                            opacity: englishTagFade,
                            child: Text(
                              'Every need. One app.',
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFF6E3B4)
                                    .withValues(alpha: 0.86),
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // 7) Egypt statement, top-right inside SafeArea with royal gold & ivory palette.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        top: 10,
                        end: 14,
                        start: 44,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.topEnd,
                        child: Opacity(
                          opacity: egyptStatementFade,
                          child: Transform.translate(
                            offset: Offset(0, egyptStatementSlide),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0E0826)
                                    .withValues(alpha: 0.38),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _gold.withValues(alpha: 0.34),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: Text(
                                      'مصر',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 21,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFF7D47B),
                                        letterSpacing: 0.5,
                                        shadows: [
                                          Shadow(
                                            color: Color(0x66000000),
                                            blurRadius: 8,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: Text(
                                      'دائمًا بتقدم للعالم',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFFFF9EC),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(
                                      'Egypt',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFF5D076)
                                            .withValues(alpha: 0.9),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(
                                      'Always moving the world forward',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: _textNearWhite.withValues(
                                          alpha: 0.78,
                                        ),
                                        letterSpacing: 0.3,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // 8) Made in Egypt footer.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Opacity(
                        opacity: madeInEgyptFade,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E0826)
                                  .withValues(alpha: 0.42),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _gold.withValues(alpha: 0.28),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'صنع في مصر ',
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFF6D788),
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      Transform.translate(
                                        offset: Offset(
                                          2.0 *
                                              math.sin(
                                                _ctrl.value * math.pi * 4,
                                              ),
                                          0,
                                        ),
                                        child: const Text(
                                          '🇪🇬',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Made in Egypt ',
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: _textNearWhite.withValues(
                                            alpha: 0.85,
                                          ),
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                      Transform.translate(
                                        offset: Offset(
                                          2.0 *
                                              math.sin(
                                                _ctrl.value * math.pi * 4,
                                              ),
                                          0,
                                        ),
                                        child: const Text(
                                          '🇪🇬',
                                          style: TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGoldenStardust({
    required double t,
    required double screenWidth,
    required double screenHeight,
  }) {
    final fade = _clamp((t - 0.06) / 0.14) * (1 - _clamp((t - 0.52) / 0.16));
    if (fade <= 0.01) return const SizedBox.shrink();

    const seeds = <(double, double, double, bool)>[
      (0.18, 0.42, 4.0, true),
      (0.82, 0.38, 3.5, false),
      (0.26, 0.28, 3.0, false),
      (0.74, 0.25, 4.5, true),
      (0.14, 0.56, 3.2, true),
      (0.86, 0.54, 3.8, false),
    ];

    return Opacity(
      opacity: fade,
      child: Stack(
        children: [
          for (var i = 0; i < seeds.length; i++)
            Positioned(
              left:
                  screenWidth * seeds[i].$1 +
                  math.sin((t * 3 + i) * math.pi) * 6,
              top: screenHeight * seeds[i].$2 - (t * 36),
              child: Container(
                width: seeds[i].$3,
                height: seeds[i].$3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (seeds[i].$4 ? _gold : _gradientCyan).withValues(
                    alpha: (0.45 + 0.35 * math.sin((t * 5 + i) * math.pi))
                        .clamp(0.1, 0.85),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Loads a bundled intro image, falling back to [fallbackBuilder] if the
/// asset is missing. Assets ship inside the app, so the intro is stable and
/// does not depend on device storage.
class _IntroImage extends StatefulWidget {
  const _IntroImage({
    required this.assetPath,
    this.fit,
    this.width,
    this.height,
    this.cacheWidth,
    this.cacheHeight,
    this.fallbackBuilder,
  });

  final String assetPath;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final int? cacheHeight;
  final WidgetBuilder? fallbackBuilder;

  @override
  State<_IntroImage> createState() => _IntroImageState();
}

class _IntroImageState extends State<_IntroImage> {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      widget.assetPath,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      cacheWidth: widget.cacheWidth,
      cacheHeight: widget.cacheHeight,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) =>
          widget.fallbackBuilder?.call(context) ?? const SizedBox.shrink(),
    );
  }
}
