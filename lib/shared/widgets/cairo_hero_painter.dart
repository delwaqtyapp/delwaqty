import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Layered vector dusk scene of Cairo for the profile hero: sky, stars, sun
/// glow, pyramids on the far horizon, the Citadel, old-city minarets and
/// domes, Cairo Tower, the Nile with a felucca. Painted in code, no assets.
class CairoHeroPainter extends CustomPainter {
  const CairoHeroPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.865;

    final skyStops = dark
        ? const [
            Color(0xFF0B0820),
            Color(0xFF241447),
            Color(0xFF5A2A5E),
            Color(0xFFB5503F),
          ]
        : const [
            Color(0xFF4B2F86),
            Color(0xFF9B4F96),
            Color(0xFFE9806E),
            Color(0xFFFFC27A),
          ];
    final far = dark ? const Color(0xFF4A2A68) : const Color(0xFFC0779A);
    final mid = dark ? const Color(0xFF26143F) : const Color(0xFF7A4586);
    final near = dark ? const Color(0xFF120A26) : const Color(0xFF3C2459);
    final glowColor = dark ? const Color(0xFFFF9A5C) : const Color(0xFFFFE2A0);

    // Sky.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, horizon + 2),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: skyStops,
          stops: const [0, 0.42, 0.75, 1],
        ).createShader(Rect.fromLTWH(0, 0, w, horizon)),
    );

    // Stars: deterministic, more visible in dark mode.
    var seed = 7;
    double rnd() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    }

    final starPaint = Paint();
    final stars = dark ? 46 : 14;
    for (var i = 0; i < stars; i++) {
      final x = rnd() * w;
      final y = rnd() * horizon * 0.55;
      final r = 0.5 + rnd() * (dark ? 1.1 : 0.7);
      starPaint.color = Colors.white.withValues(
        alpha: (dark ? 0.35 : 0.22) + rnd() * 0.4,
      );
      canvas.drawCircle(Offset(x, y), r, starPaint);
    }

    // Sun / moon glow at the horizon.
    final glowC = Offset(w * 0.30, horizon - h * 0.02);
    canvas.drawCircle(
      glowC,
      w * 0.6,
      Paint()
        ..shader = RadialGradient(
          colors: [
            glowColor.withValues(alpha: dark ? 0.55 : 0.85),
            glowColor.withValues(alpha: dark ? 0.12 : 0.25),
            glowColor.withValues(alpha: 0),
          ],
          stops: const [0, 0.35, 1],
        ).createShader(Rect.fromCircle(center: glowC, radius: w * 0.6)),
    );
    canvas.drawCircle(
      glowC,
      h * 0.045,
      Paint()
        ..color = (dark ? const Color(0xFFFFD9A8) : Colors.white).withValues(
          alpha: 0.9,
        ),
    );

    // Readability scrim behind the name area (sky only, silhouettes sit above).
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.42, w, horizon - h * 0.42),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: dark ? 0.32 : 0.36),
          ],
        ).createShader(Rect.fromLTWH(0, h * 0.42, w, horizon - h * 0.42)),
    );

    // Pyramids on the far horizon.
    final pyr = Paint()..color = far.withValues(alpha: 0.75);
    void pyramid(double cx, double base, double half, double height) {
      canvas.drawPath(
        Path()
          ..moveTo(cx - half, base)
          ..lineTo(cx, base - height)
          ..lineTo(cx + half, base)
          ..close(),
        pyr,
      );
      canvas.drawPath(
        Path()
          ..moveTo(cx, base - height)
          ..lineTo(cx + half, base)
          ..lineTo(cx + half * 0.15, base)
          ..close(),
        Paint()..color = Colors.black.withValues(alpha: 0.12),
      );
    }

    pyramid(w * 0.60, horizon - 2, w * 0.085, h * 0.115);
    pyramid(w * 0.71, horizon - 2, w * 0.065, h * 0.088);
    pyramid(w * 0.52, horizon - 2, w * 0.04, h * 0.055);

    // Haze band at the horizon.
    canvas.drawRect(
      Rect.fromLTWH(0, horizon - h * 0.10, w, h * 0.10),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            glowColor.withValues(alpha: 0),
            glowColor.withValues(alpha: dark ? 0.18 : 0.35),
          ],
        ).createShader(Rect.fromLTWH(0, horizon - h * 0.10, w, h * 0.10)),
    );

    // Far layer: Citadel hill with the Muhammad Ali mosque.
    final farPaint = Paint()..color = far;
    canvas.drawPath(
      Path()
        ..moveTo(-10, horizon)
        ..quadraticBezierTo(
          w * 0.10,
          horizon - h * 0.10,
          w * 0.24,
          horizon - h * 0.085,
        )
        ..quadraticBezierTo(w * 0.40, horizon - h * 0.07, w * 0.50, horizon)
        ..close(),
      farPaint,
    );
    final cx = w * 0.22;
    final cb = horizon - h * 0.083;
    // Main dome, two half domes, courtyard wall.
    canvas.drawRect(
      Rect.fromLTWH(cx - w * 0.06, cb - h * 0.035, w * 0.12, h * 0.035),
      farPaint,
    );
    _dome(canvas, cx, cb - h * 0.035, w * 0.050, h * 0.060, farPaint);
    _dome(
      canvas,
      cx - w * 0.050,
      cb - h * 0.012,
      w * 0.026,
      h * 0.030,
      farPaint,
    );
    _dome(
      canvas,
      cx + w * 0.050,
      cb - h * 0.012,
      w * 0.026,
      h * 0.030,
      farPaint,
    );
    _minaret(
      canvas,
      cx - w * 0.075,
      cb - h * 0.005,
      w * 0.009,
      h * 0.125,
      farPaint,
      slim: true,
    );
    _minaret(
      canvas,
      cx + w * 0.075,
      cb - h * 0.005,
      w * 0.009,
      h * 0.125,
      farPaint,
      slim: true,
    );

    // Mid layer: old Cairo, domes and minarets.
    final midPaint = Paint()..color = mid;
    final mb = horizon + h * 0.012;
    final blocks = <List<double>>[
      // x, width, height (fractions of w, w, h)
      [0.00, 0.10, 0.075], [0.09, 0.07, 0.105], [0.15, 0.09, 0.065],
      [0.30, 0.07, 0.085], [0.36, 0.09, 0.060], [0.44, 0.06, 0.095],
      [0.52, 0.10, 0.065], [0.60, 0.07, 0.085], [0.66, 0.09, 0.060],
      [0.88, 0.07, 0.090], [0.94, 0.08, 0.070],
    ];
    for (final b in blocks) {
      canvas.drawRect(
        Rect.fromLTWH(w * b[0], mb - h * b[2], w * b[1], h * b[2] + 2),
        midPaint,
      );
    }
    _dome(canvas, w * 0.125, mb - h * 0.105, w * 0.034, h * 0.040, midPaint);
    _dome(canvas, w * 0.405, mb - h * 0.060, w * 0.034, h * 0.034, midPaint);
    _dome(canvas, w * 0.565, mb - h * 0.065, w * 0.042, h * 0.044, midPaint);
    _minaret(canvas, w * 0.285, mb, w * 0.012, h * 0.19, midPaint);
    _minaret(canvas, w * 0.475, mb - h * 0.095, w * 0.011, h * 0.12, midPaint);
    _minaret(canvas, w * 0.64, mb, w * 0.011, h * 0.17, midPaint);

    // Cairo Tower (lotus lattice), right of centre.
    final tx = w * 0.80;
    final tower = Paint()..color = near;
    final towerTop = h * 0.30;
    canvas.drawPath(
      Path()
        ..moveTo(tx - w * 0.017, mb)
        ..lineTo(tx - w * 0.009, towerTop + h * 0.16)
        ..lineTo(tx + w * 0.009, towerTop + h * 0.16)
        ..lineTo(tx + w * 0.017, mb)
        ..close(),
      tower,
    );
    // Lattice crown: flared body, then neck, observation deck, spire.
    canvas.drawPath(
      Path()
        ..moveTo(tx - w * 0.009, towerTop + h * 0.16)
        ..quadraticBezierTo(
          tx - w * 0.040,
          towerTop + h * 0.10,
          tx - w * 0.034,
          towerTop + h * 0.045,
        )
        ..lineTo(tx + w * 0.034, towerTop + h * 0.045)
        ..quadraticBezierTo(
          tx + w * 0.040,
          towerTop + h * 0.10,
          tx + w * 0.009,
          towerTop + h * 0.16,
        )
        ..close(),
      tower,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(tx, towerTop + h * 0.035),
          width: w * 0.085,
          height: h * 0.022,
        ),
        const Radius.circular(3),
      ),
      tower,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(tx, towerTop + h * 0.012),
        width: w * 0.012,
        height: h * 0.030,
      ),
      tower,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(tx, towerTop - h * 0.030),
        width: w * 0.003,
        height: h * 0.07,
      ),
      tower,
    );
    // Lattice diamonds cut out of the crown in the sky colour.
    final lattice = Paint()
      ..color = skyStops[2].withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    for (var i = 0; i < 5; i++) {
      final lx = tx - w * 0.026 + i * w * 0.013;
      canvas.drawLine(
        Offset(lx, towerTop + h * 0.056),
        Offset(lx + w * 0.013, towerTop + h * 0.11),
        lattice,
      );
      canvas.drawLine(
        Offset(lx + w * 0.013, towerTop + h * 0.056),
        Offset(lx, towerTop + h * 0.11),
        lattice,
      );
    }

    // Near layer: dark buildings on the banks and palms.
    final nearPaint = Paint()..color = near;
    final nb = horizon + h * 0.022;
    for (final b in const [
      [0.00, 0.075, 0.12],
      [0.07, 0.06, 0.085],
      [0.93, 0.07, 0.115],
      [0.87, 0.07, 0.075],
    ]) {
      canvas.drawRect(
        Rect.fromLTWH(w * b[0], nb - h * b[2], w * b[1], h * b[2] + 2),
        nearPaint,
      );
    }
    _palm(canvas, w * 0.075, nb - h * 0.02, h * 0.17, nearPaint);
    _palm(canvas, w * 0.105, nb - h * 0.01, h * 0.12, nearPaint);
    _palm(canvas, w * 0.915, nb - h * 0.02, h * 0.15, nearPaint);
    // Lit windows.
    final win = Paint();
    seed = 91;
    for (var i = 0; i < 26; i++) {
      final x = rnd() * w;
      final y = nb - h * (0.02 + rnd() * 0.10);
      final inNear = x < w * 0.135 || x > w * 0.87;
      if (!inNear) continue;
      win.color = const Color(0xFFFFC96B).withValues(alpha: dark ? 0.9 : 0.6);
      canvas.drawRect(Rect.fromLTWH(x, y, 2, 2.6), win);
    }

    // Nile.
    final nileTop = nb;
    final nileRect = Rect.fromLTWH(0, nileTop, w, h - nileTop);
    canvas.drawRect(
      nileRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF7A3B52), Color(0xFF2A1646), Color(0xFF120A26)]
              : const [Color(0xFFF2A078), Color(0xFF8B4F86), Color(0xFF4B2F86)],
        ).createShader(nileRect),
    );
    // Sun reflection streaks.
    final streak = Paint()
      ..color = glowColor.withValues(alpha: dark ? 0.45 : 0.6);
    for (var i = 0; i < 6; i++) {
      final y = nileTop + 3 + i * (h - nileTop) / 7.5;
      final half = w * (0.10 - i * 0.012);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(w * 0.30 + (i.isEven ? 6 : -6), y),
            width: half * 2,
            height: 1.6,
          ),
          const Radius.circular(1),
        ),
        streak
          ..color = streak.color.withValues(
            alpha: math.max(0.12, (dark ? 0.45 : 0.6) - i * 0.07),
          ),
      );
    }
    // Felucca: hull, mast and lateen sail, plus a soft reflection.
    final fx = w * 0.60;
    final fy = nileTop + (h - nileTop) * 0.42;
    final hull = Paint()
      ..color = dark ? const Color(0xFF0C0618) : const Color(0xFF2A1745);
    canvas.drawPath(
      Path()
        ..moveTo(fx - w * 0.075, fy)
        ..quadraticBezierTo(fx, fy + h * 0.030, fx + w * 0.085, fy - h * 0.012)
        ..lineTo(fx + w * 0.070, fy - h * 0.004)
        ..quadraticBezierTo(fx, fy + h * 0.016, fx - w * 0.066, fy - h * 0.006)
        ..close(),
      hull,
    );
    canvas.drawLine(
      Offset(fx + w * 0.005, fy - h * 0.004),
      Offset(fx + w * 0.005, fy - h * 0.150),
      Paint()
        ..color = hull.color
        ..strokeWidth = 1.6,
    );
    final sail = Paint()
      ..color = dark ? const Color(0xFFF1D9B8) : const Color(0xFFFFF1D6);
    canvas.drawPath(
      Path()
        ..moveTo(fx + w * 0.008, fy - h * 0.145)
        ..quadraticBezierTo(
          fx + w * 0.030,
          fy - h * 0.062,
          fx + w * 0.082,
          fy - h * 0.018,
        )
        ..lineTo(fx + w * 0.008, fy - h * 0.024)
        ..close(),
      sail,
    );
    canvas.drawPath(
      Path()
        ..moveTo(fx - w * 0.002, fy - h * 0.125)
        ..quadraticBezierTo(
          fx - w * 0.026,
          fy - h * 0.066,
          fx - w * 0.066,
          fy - h * 0.026,
        )
        ..lineTo(fx - w * 0.002, fy - h * 0.026)
        ..close(),
      Paint()..color = sail.color.withValues(alpha: 0.82),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(fx + w * 0.005, fy + h * 0.032),
          width: w * 0.12,
          height: 2,
        ),
        const Radius.circular(1),
      ),
      Paint()..color = hull.color.withValues(alpha: 0.35),
    );
  }

  static void _dome(
    Canvas c,
    double cx,
    double base,
    double rx,
    double ry,
    Paint p,
  ) {
    c.drawPath(
      Path()
        ..moveTo(cx - rx, base)
        ..quadraticBezierTo(cx - rx, base - ry * 1.15, cx, base - ry * 1.12)
        ..quadraticBezierTo(cx + rx, base - ry * 1.15, cx + rx, base)
        ..close(),
      p,
    );
    c.drawRect(
      Rect.fromLTWH(cx - 0.6, base - ry * 1.12 - ry * 0.28, 1.2, ry * 0.28),
      p,
    );
  }

  static void _minaret(
    Canvas c,
    double cx,
    double base,
    double w,
    double h,
    Paint p, {
    bool slim = false,
  }) {
    final shaftW = slim ? w * 0.55 : w * 0.7;
    c.drawRect(Rect.fromLTWH(cx - shaftW / 2, base - h, shaftW, h), p);
    // Balcony and cap.
    c.drawRect(
      Rect.fromCenter(
        center: Offset(cx, base - h * 0.72),
        width: w * 1.6,
        height: h * 0.035,
      ),
      p,
    );
    c.drawRect(
      Rect.fromCenter(
        center: Offset(cx, base - h * 0.90),
        width: w * 1.3,
        height: h * 0.03,
      ),
      p,
    );
    c.drawPath(
      Path()
        ..moveTo(cx - w * 0.55, base - h)
        ..lineTo(cx, base - h - h * 0.12)
        ..lineTo(cx + w * 0.55, base - h)
        ..close(),
      p,
    );
  }

  static void _palm(Canvas c, double x, double base, double h, Paint p) {
    final stroke = Paint()
      ..color = p.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final top = Offset(x + h * 0.06, base - h);
    c.drawPath(
      Path()
        ..moveTo(x, base)
        ..quadraticBezierTo(x + h * 0.02, base - h * 0.6, top.dx, top.dy),
      stroke,
    );
    for (final a in const [-2.6, -2.0, -1.4, -0.8, -0.3, 0.3]) {
      final end =
          top +
          Offset(math.cos(a) * h * 0.34, math.sin(a) * h * 0.34 + h * 0.10);
      c.drawPath(
        Path()
          ..moveTo(top.dx, top.dy)
          ..quadraticBezierTo(
            (top.dx + end.dx) / 2,
            top.dy + math.sin(a) * h * 0.2 - h * 0.05,
            end.dx,
            end.dy,
          ),
        stroke..strokeWidth = 1.6,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CairoHeroPainter old) => old.dark != dark;
}
