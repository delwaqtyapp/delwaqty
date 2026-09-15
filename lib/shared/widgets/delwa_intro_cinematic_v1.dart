// =============================================================================
// INTRO 1 (backup of the previous cinematic intro).
//
// Identical to the state we shipped before the redesign. Keep this file as a
// restore point: to roll back, switch `splash_page.dart` to import this file
// and render `DelwaIntroSceneV1`.
// =============================================================================
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class IntroAssets {
  IntroAssets._();

  static const String logo = 'assets/egypt/delwaqty_logo_mark.png';
  static const String background =
      'assets/egypt/intro_egypt_cinematic_background.png';
}

class DelwaIntroSceneV1 extends StatefulWidget {
  const DelwaIntroSceneV1({super.key});

  @override
  State<DelwaIntroSceneV1> createState() => _DelwaIntroSceneState();
}

class _DelwaIntroSceneState extends State<DelwaIntroSceneV1>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  Timer? _navTimer;
  bool _navigated = false;

  static const _totalDuration = Duration(milliseconds: 9000);
  static const _contentDuration = Duration(milliseconds: 4500);
  static const _holdDuration = Duration(milliseconds: 800);

  static const _wordmarkStyle = TextStyle(
    fontFamily: 'Cairo',
    fontSize: 32,
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
    _gradBlueStop =
        _gradWhiteEnd + (1 - _gradWhiteEnd) * 0.5111111111;
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

          final bgFade = Curves.easeIn.transform(_clamp(t / 0.05));

          final egyptStatementFade =
              Curves.easeOutCubic.transform(_clamp((t - 0.033) / 0.08));
          final egyptStatementSlide =
              8.0 * (1 - Curves.easeOutCubic.transform(_clamp((t - 0.033) / 0.10)));

          final nileReflectionOpacity =
              _clamp((t - 0.078) / 0.10) * _clamp(1.0 - (t - 0.50) / 0.20);

          final lightTrailProgress =
              Curves.easeInOutCubic.transform(_clamp((t - 0.111) / 0.25));
          final lightTrailOpacity =
              _clamp((t - 0.111) / 0.12) * _clamp(1.0 - (t - 0.60) / 0.15);

          const logoRevealStart = 0.189;
          final logoOpacity =
              Curves.easeOutCubic.transform(_clamp((t - logoRevealStart) / 0.15));
          final logoScaleRaw =
              Curves.easeOutCubic.transform(_clamp((t - logoRevealStart) / 0.13));
          final logoScale = 0.82 + 0.23 * logoScaleRaw;
          final logoFinalScale = logoScale > 1.05
              ? 1.05 - 0.05 * Curves.easeOutCubic.transform(
                  _clamp((t - logoRevealStart - 0.13) / 0.05))
              : logoScale;

          final haloOpacity = _clamp((t - logoRevealStart) / 0.12);
          final haloPulse = 0.12 + 0.10 * (0.5 + 0.5 * math.sin(t * math.pi * 3));
          final haloEffective = haloOpacity * haloPulse;

          final delwaQtyFade =
              Curves.easeOutCubic.transform(_clamp((t - 0.278) / 0.10));
          final delwaQtySlide =
              14.0 * (1 - Curves.easeOutCubic.transform(_clamp((t - 0.278) / 0.12)));

          final dalwaqtyFade =
              Curves.easeOutCubic.transform(_clamp((t - 0.311) / 0.08));

          final arabicTagFade =
              Curves.easeOutCubic.transform(_clamp((t - 0.333) / 0.06));
          final englishTagFade =
              Curves.easeOutCubic.transform(_clamp((t - 0.356) / 0.06));

          final madeInEgyptFade =
              Curves.easeOutCubic.transform(_clamp((t - 0.378) / 0.08));

          final bgScale = 1.0 + 0.03 * Curves.linear.transform(_clamp(t / 1.0));

          final screenWidth = MediaQuery.of(context).size.width;
          final screenHeight = MediaQuery.of(context).size.height;

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
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0D0824).withValues(alpha: 0.25),
                      const Color(0xFF120A30).withValues(alpha: 0.15),
                      const Color(0xFF0D0824).withValues(alpha: 0.20),
                    ],
                  ),
                ),
              ),
              if (nileReflectionOpacity > 0.01)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: screenHeight * 0.35,
                  child: Opacity(
                    opacity: nileReflectionOpacity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0.0, 0.6),
                          radius: 1.2,
                          colors: [
                            const Color(0xFF19C8C8).withValues(alpha: 0.12),
                            const Color(0xFF4057D8).withValues(alpha: 0.06),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (lightTrailOpacity > 0.01)
                RepaintBoundary(
                  child: CustomPaint(
                    size: Size(screenWidth, screenHeight),
                    painter: _NileLightTrailPainter(
                      progress: lightTrailProgress,
                      opacity: lightTrailOpacity,
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  child: Align(
                    alignment: const Alignment(0.88, -0.88),
                    child: Opacity(
                      opacity: egyptStatementFade,
                      child: Transform.translate(
                        offset: Offset(0, egyptStatementSlide),
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              RichText(
                                textDirection: TextDirection.rtl,
                                text: const TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'مصر',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFD8A84E),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    TextSpan(
                                      text: '\nدايمًا بتقدم للعالم',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFFF7F7FA),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Egypt.\nAlways moving the world forward.',
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFFF7F7FA).withValues(alpha: 0.6),
                                  letterSpacing: 0.3,
                                  height: 1.3,
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
              Positioned(
                left: 0,
                right: 0,
                top: screenHeight * 0.36 - (screenWidth * 0.235) / 2,
                child: Center(
                  child: Opacity(
                    opacity: haloOpacity,
                    child: Container(
                      width: screenWidth * 0.50,
                      height: screenWidth * 0.50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF6C3CEB).withValues(alpha: haloEffective),
                            const Color(0xFF4057D8).withValues(alpha: haloEffective * 0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: screenHeight * 0.36 - (screenWidth * 0.235) / 2,
                child: Center(
                  child: Opacity(
                    opacity: logoOpacity,
                    child: Transform.scale(
                      scale: logoFinalScale,
                      child: _IntroImage(
                        assetPath: IntroAssets.logo,
                        width: screenWidth * 0.235,
                        height: screenWidth * 0.235,
                        cacheWidth: (screenWidth * 0.235 *
                                MediaQuery.of(context).devicePixelRatio)
                            .round(),
                        cacheHeight: (screenWidth * 0.235 *
                                MediaQuery.of(context).devicePixelRatio)
                            .round(),
                        fit: BoxFit.contain,
                        fallbackBuilder: (context) => Container(
                          width: screenWidth * 0.235,
                          height: screenWidth * 0.235,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF6C3CEB),
                                Color(0xFF19C8C8),
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
              Positioned(
                left: 0,
                right: 0,
                top: screenHeight * 0.36 + (screenWidth * 0.235) / 2 + 16,
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
                                  Color(0xFF6C3CEB),
                                  Color(0xFF4057D8),
                                  Color(0xFF19C8C8),
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
                        const SizedBox(height: 6),
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
                                color: Color(0xFFF7F7FA),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: screenHeight * 0.36 +
                    (screenWidth * 0.235) / 2 +
                    16 +
                    44 +
                    32 +
                    12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFFF7F7FA).withValues(alpha: 0.6),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: screenHeight * 0.09,
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
                                color: const Color(0xFFF7F7FA).withValues(alpha: 0.75),
                                letterSpacing: 0.3,
                              ),
                            ),
                            Transform.translate(
                              offset: Offset(
                                  2.0 *
                                      math.sin(
                                          _ctrl.value * math.pi * 4),
                                  0),
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
                                color:
                                    const Color(0xFFF7F7FA).withValues(alpha: 0.6),
                                letterSpacing: 0.3,
                              ),
                            ),
                            Transform.translate(
                              offset: Offset(
                                  2.0 *
                                      math.sin(
                                          _ctrl.value * math.pi * 4),
                                  0),
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
            ],
          );
        },
        ),
      ),
    );
  }
}

class _NileLightTrailPainter extends CustomPainter {
  const _NileLightTrailPainter({
    required this.progress,
    required this.opacity,
  });

  final double progress;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.01 || progress <= 0.01) return;

    final totalHeight = size.height;
    final trailHeight = totalHeight * 0.55;
    final trailBottom = totalHeight * 0.82;
    final currentTop = trailBottom - trailHeight * progress;

    final trailPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFF19C8C8).withValues(alpha: 0.0),
          const Color(0xFF19C8C8).withValues(alpha: 0.18 * opacity),
          const Color(0xFF4057D8).withValues(alpha: 0.25 * opacity),
          const Color(0xFF6C3CEB).withValues(alpha: 0.20 * opacity),
          const Color(0xFF6C3CEB).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.15, 0.45, 0.75, 1.0],
      ).createShader(Rect.fromLTRB(
        size.width * 0.40,
        currentTop,
        size.width * 0.60,
        trailBottom,
      ));

    final trailRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        size.width * 0.42,
        currentTop,
        size.width * 0.58,
        trailBottom,
      ),
      const Radius.circular(24),
    );
    canvas.drawRRect(trailRect, trailPaint);

    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFF19C8C8).withValues(alpha: 0.0),
          const Color(0xFF4057D8).withValues(alpha: 0.12 * opacity),
          const Color(0xFF6C3CEB).withValues(alpha: 0.08 * opacity),
          const Color(0xFF6C3CEB).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTRB(
        size.width * 0.30,
        currentTop - 20,
        size.width * 0.70,
        trailBottom + 10,
      ));

    final glowRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        size.width * 0.32,
        currentTop - 10,
        size.width * 0.68,
        trailBottom + 10,
      ),
      const Radius.circular(80),
    );
    canvas.drawRRect(glowRect, glowPaint);

    final spotCenter = Offset(size.width * 0.50, currentTop + trailHeight * 0.1);
    final spotPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF19C8C8).withValues(alpha: 0.22 * opacity),
          const Color(0xFF6C3CEB).withValues(alpha: 0.10 * opacity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: spotCenter, radius: 90));
    canvas.drawCircle(spotCenter, 90, spotPaint);
  }

  @override
  bool shouldRepaint(covariant _NileLightTrailPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.opacity != opacity;
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
