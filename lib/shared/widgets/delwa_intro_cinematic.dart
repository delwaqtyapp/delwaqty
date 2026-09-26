// =============================================================================
// DelWaQty intro / splash.
//
// Bundled reference design:
//   * full-screen Pyramids / Nile background (BoxFit.cover) + light dim layer
//   * "Egypt" statement block pinned top-right inside SafeArea
//   * transparent logo (assets/egypt/delwaqty_logo_mark.png) centered with a
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

  static const String logo = 'assets/egypt/delwaqty_logo_mark.png';
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
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
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
            final bgScale = 1.0 + 0.03 * Curves.linear.transform(_clamp(t / 1.0));

            // 2) Nile light: quiet bottom -> top sweep (about 2.4s).
            const nileStart = 0.055;
            final nileProgress =
                Curves.easeInOutCubic.transform(_clamp((t - nileStart) / 0.275));
            final nileStripOpacity =
                _clamp((t - nileStart) / 0.10) * (1 - _clamp((t - 0.40) / 0.08));
            final nileReflectionOpacity =
                _clamp((t - 0.08) / 0.12) * (1 - _clamp((t - 0.36) / 0.10));

            // 3) Halo around the logo.
            const haloStart = 0.20;
            final haloOpacity = _clamp((t - haloStart) / 0.12);
            final haloPulse =
                0.16 + 0.08 * (0.5 + 0.5 * math.sin(t * math.pi * 3));
            final haloEffective = haloOpacity * haloPulse;

            // 4) Logo Fade + Scale.
            const logoStart = 0.24;
            final logoOpacity =
                Curves.easeOutCubic.transform(_clamp((t - logoStart) / 0.14));
            final logoScale =
                0.88 + 0.12 * Curves.easeOutCubic.transform(_clamp((t - logoStart) / 0.15));

            // 5) DelwaQty wordmark (rise from the bottom).
            final delwaQtyFade =
                Curves.easeOutCubic.transform(_clamp((t - 0.36) / 0.10));
            final delwaQtySlide =
                16.0 * (1 - Curves.easeOutCubic.transform(_clamp((t - 0.36) / 0.12)));

            // 6) Arabic name + descriptions.
            final dalwaqtyFade =
                Curves.easeOutCubic.transform(_clamp((t - 0.38) / 0.08));
            final arabicTagFade =
                Curves.easeOutCubic.transform(_clamp((t - 0.40) / 0.06));
            final englishTagFade =
                Curves.easeOutCubic.transform(_clamp((t - 0.42) / 0.06));

            // 7) Egypt statement, top-right, appears quietly late.
            final egyptStatementFade =
                Curves.easeOutCubic.transform(_clamp((t - 0.42) / 0.08));
            final egyptStatementSlide =
                8.0 * (1 - Curves.easeOutCubic.transform(_clamp((t - 0.42) / 0.10)));

            // 8) Made in Egypt footer.
            final madeInEgyptFade =
                Curves.easeOutCubic.transform(_clamp((t - 0.44) / 0.06));

            final screenWidth = MediaQuery.of(context).size.width;
            final screenHeight = MediaQuery.of(context).size.height;
            final logoSize = (screenWidth * 0.30).clamp(110.0, 140.0);
            final logoCenterY = screenHeight * 0.37;

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
                // Cairo lights clearly visible.
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF0D0824).withValues(alpha: 0.20),
                          const Color(0xFF120A30).withValues(alpha: 0.12),
                          const Color(0xFF0D0824).withValues(alpha: 0.16),
                        ],
                      ),
                    ),
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
                // Transparent logo, centered above the wordmark.
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
                              (logoSize * MediaQuery.of(context).devicePixelRatio)
                                  .round(),
                          cacheHeight:
                              (logoSize * MediaQuery.of(context).devicePixelRatio)
                                  .round(),
                          fit: BoxFit.contain,
                          fallbackBuilder: (context) => Container(
                            width: logoSize,
                            height: logoSize,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  _gradientPurple,
                                  _gradientCyan,
                                ],
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
                // DelwaQty wordmark + Arabic name + descriptions.
                Positioned(
                  left: 0,
                  right: 0,
                  top: logoCenterY + logoSize / 2 + 16,
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
                                    Color(0xFFF7F7FA),
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
                          const SizedBox(height: 8),
                          Opacity(
                            opacity: dalwaqtyFade,
                            child: const Directionality(
                              textDirection: TextDirection.rtl,
                              child: Text(
                                'دلوقتي',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                  color: _textNearWhite,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Opacity(
                            opacity: arabicTagFade,
                            child: const Directionality(
                              textDirection: TextDirection.rtl,
                              child: Text(
                                'كل احتياجاتك... في تطبيق واحد',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xCCF2EEFF),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Opacity(
                            opacity: englishTagFade,
                            child: Text(
                              'Every need. One app.',
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: _textNearWhite.withValues(alpha: 0.6),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // 7) Egypt statement, top-right inside SafeArea.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: 14,
                        right: 16,
                        left: 60,
                      ),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Opacity(
                          opacity: egyptStatementFade,
                          child: Transform.translate(
                            offset: Offset(0, egyptStatementSlide),
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
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: _gold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: Text(
                                    'دائمًا بتقدم للعالم',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _textNearWhite,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    'Egypt',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                      color: _textNearWhite.withValues(alpha: 0.55),
                                      letterSpacing: 0.4,
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
                                      fontWeight: FontWeight.w400,
                                      color: _textNearWhite.withValues(alpha: 0.55),
                                      letterSpacing: 0.3,
                                      height: 1.25,
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Directionality(
                              textDirection: TextDirection.rtl,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'صنع في مصر ',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _textNearWhite.withValues(alpha: 0.75),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  Transform.translate(
                                    offset: Offset(
                                      2.0 * math.sin(_ctrl.value * math.pi * 4),
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
                            const SizedBox(height: 2),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Made in Egypt ',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                      color: _textNearWhite.withValues(alpha: 0.6),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  Transform.translate(
                                    offset: Offset(
                                      2.0 * math.sin(_ctrl.value * math.pi * 4),
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
              ],
            );
          },
        ),
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