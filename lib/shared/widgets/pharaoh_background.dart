import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Bundled cinematic Egyptian backgrounds (no network dependency).
class EgyptAssets {
  EgyptAssets._();

  /// Cairo at night — wide skyline, PRIMARY concept.
  static const String cairoNight = 'assets/egypt/cairo_night.jpg';

  /// Cairo Nile / Zamalek at night (alternate concept).
  static const String cairoNileNight = 'assets/egypt/cairo_nile_night.jpg';

  /// Wide Giza landscape, pyramids distant (alternate concept).
  static const String gizaWide = 'assets/egypt/giza_wide.jpg';

  /// Cairo aerial portrait (alternate concept).
  static const String cairoAerial = 'assets/egypt/cairo_aerial.jpg';
}

/// Cinematic Egyptian-futurism backdrop.
///
/// Bundled photograph + dark gradient + faint purple/cyan atmospheric tint +
/// minimal vignette + extremely subtle Egyptian geometry. The image never
/// competes with the brand.
class PharaohBackground extends StatelessWidget {
  const PharaohBackground({
    super.key,
    this.imageAsset = EgyptAssets.cairoNight,
    this.parallaxOffset = Offset.zero,
    this.child,
  });

  /// Bundled asset path — never a remote URL.
  final String imageAsset;

  /// Subtle 1–3% parallax drift supplied by the parent.
  final Offset parallaxOffset;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final maxShift = screen.width * 0.02;
    final shift = Offset(
      parallaxOffset.dx * maxShift,
      parallaxOffset.dy * maxShift,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: const Color(0xFF120B2E)),
        Transform.translate(
          offset: shift,
          child: Transform.scale(
            scale: 1.04,
            child: Transform.translate(
              offset: Offset(-shift.dx * 1.04, -shift.dy * 1.04),
              child: Image.asset(
                imageAsset,
                fit: BoxFit.cover,
                alignment: const Alignment(0.0, -0.1),
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF120B2E),
                        Color(0xFF2E146F),
                        Color(0xFF120B2E),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Cinematic dark gradient — keeps lower text area quiet but image visible.
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0E0824).withValues(alpha: 0.55),
                const Color(0xFF0E0824).withValues(alpha: 0.12),
                const Color(0xFF0E0824).withValues(alpha: 0.18),
                const Color(0xFF0E0824).withValues(alpha: 0.55),
                const Color(0xFF0E0824).withValues(alpha: 0.82),
              ],
              stops: const [0.0, 0.25, 0.55, 0.8, 1.0],
            ),
          ),
        ),
        // Subtle brand atmospheric tint (purple + faint cyan).
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.15),
              radius: 1.1,
              colors: [
                const Color(0xFF6C3CEB).withValues(alpha: 0.10),
                const Color(0xFF19C8C8).withValues(alpha: 0.04),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        // Minimal vignette.
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.05,
              colors: [
                Colors.transparent,
                const Color(0xFF0A0618).withValues(alpha: 0.35),
              ],
            ),
          ),
        ),
        // Extremely subtle Egyptian geometry (barely visible).
        const Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _SubtleEgyptianGeometryPainter(),
            ),
          ),
        ),
        ?child,
      ],
    );
  }
}

/// Barely-visible lotus/papyrus inspired abstract geometry (3–8% opacity).
class _SubtleEgyptianGeometryPainter extends CustomPainter {
  const _SubtleEgyptianGeometryPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = const Color(0xFF19C8C8).withValues(alpha: 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    // Papyrus-head geometry — upper left.
    final cx = w * 0.12;
    final cy = h * 0.22;
    for (var i = -2; i <= 2; i++) {
      final dx = cx + i * 7.0;
      final path = Path()
        ..moveTo(dx, cy + 26)
        ..quadraticBezierTo(dx + 3, cy, dx, cy - 26);
      canvas.drawPath(path, paint);
      canvas.drawCircle(Offset(dx, cy - 26), 2.2, paint);
    }

    // Abstract lotus arc — lower right.
    final lx = w * 0.88;
    final ly = h * 0.78;
    for (var i = 0; i < 4; i++) {
      final arc = Path()
        ..moveTo(lx - 30, ly + 40 - i * 8)
        ..quadraticBezierTo(lx, ly - 18 - i * 8, lx + 30, ly + 40 - i * 8);
      canvas.drawPath(arc, paint);
    }

    // Converging diagonal lines — temple geometry, faint.
    final diagPaint = Paint()
      ..color = const Color(0xFF6C3CEB).withValues(alpha: 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(w * 0.02, h * 0.95),
      Offset(w * 0.18, h * 0.72),
      diagPaint,
    );
    canvas.drawLine(
      Offset(w * 0.98, h * 0.95),
      Offset(w * 0.84, h * 0.74),
      diagPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SubtleEgyptianGeometryPainter old) => false;
}

/// Animated golden pharaonic wings drawn behind the logo.
class PharaohWingsPainter extends CustomPainter {
  PharaohWingsPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Curves.easeOutCubic.transform(progress);
    if (p <= 0) return;

    final centerX = size.width / 2;
    final centerY = size.height * 0.18;

    final goldPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFD8A84E),
          Color(0xFFFFE4A0),
          Color(0xFFD8A84E),
        ],
      ).createShader(Rect.fromLTWH(0, centerY - 40, size.width, 80))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final glowPaint = Paint()
      ..color = const Color(0xFFD8A84E).withValues(alpha: 0.12 * p)
      ..style = PaintingStyle.fill;

    final wingSpan = size.width * 0.42 * p;

    _drawWing(canvas, centerX - 30, centerY, wingSpan, -1, goldPaint, glowPaint, p);
    _drawWing(canvas, centerX + 30, centerY, wingSpan, 1, goldPaint, glowPaint, p);
  }

  void _drawWing(
    Canvas canvas,
    double startX,
    double centerY,
    double span,
    int dir,
    Paint stroke,
    Paint fill,
    double p,
  ) {
    const featherCount = 7;
    final path = Path();

    path.moveTo(startX, centerY);

    for (var i = 0; i < featherCount; i++) {
      final t = (i + 1) / featherCount;
      final x = startX + span * t * dir;
      final y = centerY - 15 * math.sin(t * math.pi * 0.7) * p;
      final cpx = x - span * 0.05 * dir;
      final cpy = y - (8 + i * 3.0) * p;
      path.quadraticBezierTo(cpx, cpy, x, y);
    }

    final tipX = startX + span * dir;
    path.lineTo(tipX, centerY + 5 * p);
    path.quadraticBezierTo(
      tipX - span * 0.3 * dir,
      centerY + 12 * p,
      startX,
      centerY + 3 * p,
    );
    path.close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);

    for (var i = 1; i <= featherCount; i++) {
      final t = i / featherCount;
      final fx = startX + span * t * dir;
      final fy = centerY - 15 * math.sin(t * math.pi * 0.7) * p;

      canvas.drawLine(
        Offset(fx, fy),
        Offset(fx - 3 * dir, fy + 10 * p),
        Paint()
          ..color = const Color(0xFFD8A84E).withValues(alpha: 0.3 * p)
          ..strokeWidth = 0.8,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PharaohWingsPainter old) => old.progress != progress;
}