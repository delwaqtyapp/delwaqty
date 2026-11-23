import 'package:delwaqty/core/theme/app_colors.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

enum RoleCardIcon { customer, merchant, delivery, provider }

/// Lightweight original vector scenes. One short selection animation, no loop.
class RoleIllustration extends StatelessWidget {
  const RoleIllustration({
    super.key,
    required this.role,
    required this.color,
    required this.selected,
  });
  final RoleCardIcon role;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: selected ? 1 : 0),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 420),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) => Transform.translate(
      offset: Offset(0, -3 * math.sin(value * math.pi)),
      child: CustomPaint(
        size: const Size(100, 88),
        painter: _ScenePainter(role, color, value),
      ),
    ),
  );
}

class _ScenePainter extends CustomPainter {
  const _ScenePainter(this.role, this.color, this.progress);
  final RoleCardIcon role;
  final Color color;
  final double progress;
  static const ink = AppColors.roleSceneInk;
  static const skin = AppColors.roleSceneSkin;

  @override
  void paint(Canvas c, Size size) {
    c.scale(size.width / 100, size.height / 88);
    void fill(Path p, Color col) => c.drawPath(p, Paint()..color = col);
    void line(Path p, Color col, [double width = 2.5]) => c.drawPath(
      p,
      Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    void rect(
      double x,
      double y,
      double w,
      double h,
      Color col, [
      double r = 4,
    ]) => c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
      Paint()..color = col,
    );
    void circle(double x, double y, double r, Color col) =>
        c.drawCircle(Offset(x, y), r, Paint()..color = col);
    final pale = Color.lerp(color, Colors.white, .86)!;
    final deep = Color.lerp(color, ink, .23)!;
    c.drawCircle(
      const Offset(50, 42),
      35,
      Paint()
        ..shader = RadialGradient(colors: [Colors.white, pale])
            .createShader(const Rect.fromLTWH(15, 7, 70, 70)),
    );
    c.drawOval(
      const Rect.fromLTWH(15, 75, 72, 7),
      Paint()..color = color.withValues(alpha: .14),
    );
    circle(15, 29, 3, color.withValues(alpha: .35));
    circle(86, 51, 2, color.withValues(alpha: .40));
    line(
      Path()
        ..moveTo(80, 15)
        ..lineTo(80, 23)
        ..moveTo(76, 19)
        ..lineTo(84, 19),
      color.withValues(alpha: .45),
      1.8,
    );
    switch (role) {
      case RoleCardIcon.customer:
        // Shopper, blue jacket, two shopping bags.
        rect(33, 43, 32, 31, color, 10);
        fill(
          Path()
            ..moveTo(43, 44)
            ..lineTo(50, 56)
            ..lineTo(57, 44)
            ..close(),
          Colors.white,
        );
        rect(45, 35, 10, 12, skin, 3);
        circle(50, 28, 12, skin);
        fill(
          Path()
            ..moveTo(38, 29)
            ..cubicTo(31, 8, 65, 9, 63, 30)
            ..lineTo(58, 24)
            ..lineTo(46, 23)
            ..close(),
          ink,
        );
        line(
          Path()
            ..moveTo(36, 50)
            ..lineTo(26, 61)
            ..moveTo(64, 50)
            ..lineTo(73, 60),
          deep,
          7,
        );
        circle(26, 62, 3.5, skin);
        circle(74, 61, 3.5, skin);
        rect(13, 59, 23, 20, deep);
        rect(66, 59, 23, 20, color);
        line(
          Path()
            ..moveTo(20, 62)
            ..lineTo(20, 55)
            ..quadraticBezierTo(25, 51, 29, 55)
            ..lineTo(29, 62),
          Colors.white,
          2,
        );
        line(
          Path()
            ..moveTo(72, 62)
            ..lineTo(72, 54)
            ..quadraticBezierTo(77, 50, 82, 54)
            ..lineTo(82, 62),
          Colors.white,
          2,
        );
        line(
          Path()
            ..moveTo(49, 59)
            ..lineTo(49, 70),
          Colors.white.withValues(alpha: .6),
          1.5,
        );
      case RoleCardIcon.merchant:
        // Shopfront with striped canopy and welcoming owner.
        rect(19, 30, 63, 47, Colors.white, 6);
        rect(22, 36, 57, 41, pale, 3);
        rect(25, 47, 20, 24, color, 3);
        rect(51, 46, 23, 31, deep, 3);
        rect(28, 50, 14, 14, Colors.white.withValues(alpha: .7), 2);
        fill(
          Path()
            ..moveTo(16, 32)
            ..lineTo(25, 17)
            ..lineTo(75, 17)
            ..lineTo(85, 32)
            ..close(),
          color,
        );
        for (var i = 0; i < 5; i++) {
          fill(
            Path()
              ..moveTo(25 + i * 10, 17)
              ..lineTo(30 + i * 10, 17)
              ..lineTo(29 + i * 13.0, 32)
              ..lineTo(22 + i * 13.0, 32)
              ..close(),
            i.isEven
                ? Colors.white.withValues(alpha: .85)
                : deep.withValues(alpha: .25),
          );
        }
        for (var i = 0; i < 5; i++) {
          rect(16 + i * 13.8, 30, 13.8, 10, i.isEven ? color : Colors.white, 5);
        }
        circle(63, 52, 6, skin);
        circle(63, 48, 6, ink);
        rect(54, 59, 18, 17, color, 5);
        rect(59, 59, 8, 17, Colors.white, 2);
        rect(50, 72, 25, 5, deep, 2);
      case RoleCardIcon.delivery:
        // Delivery captain on a scooter, parcel box, helmet and wheels.
        rect(7, 35, 23, 20, color);
        line(
          Path()
            ..moveTo(18, 36)
            ..lineTo(18, 47)
            ..lineTo(24, 47),
          Colors.white,
          2,
        );
        circle(28, 70, 10, ink);
        circle(77, 70, 10, ink);
        circle(28, 70, 5, Colors.white);
        circle(77, 70, 5, Colors.white);
        line(
          Path()
            ..moveTo(28, 70)
            ..lineTo(42, 70)
            ..lineTo(67, 70)
            ..lineTo(76, 51),
          deep,
          6,
        );
        rect(21, 52, 35, 13, color, 7);
        fill(
          Path()
            ..moveTo(64, 68)
            ..lineTo(67, 44)
            ..quadraticBezierTo(75, 41, 78, 47)
            ..lineTo(80, 61)
            ..close(),
          color,
        );
        line(
          Path()
            ..moveTo(69, 44)
            ..lineTo(66, 38)
            ..lineTo(75, 38),
          ink,
          3,
        );
        line(
          Path()
            ..moveTo(46, 51)
            ..lineTo(53, 58)
            ..lineTo(48, 69),
          ink,
          7,
        );
        rect(39, 30, 16, 24, deep, 7);
        line(
          Path()
            ..moveTo(52, 36)
            ..lineTo(60, 45)
            ..lineTo(68, 43),
          skin,
          5,
        );
        circle(47, 23, 9, skin);
        fill(
          Path()
            ..moveTo(37, 25)
            ..cubicTo(34, 7, 60, 8, 58, 25)
            ..lineTo(51, 25)
            ..lineTo(49, 20)
            ..lineTo(38, 20)
            ..close(),
          color,
        );
        rect(45, 15, 14, 5, Colors.white.withValues(alpha: .8), 2);
        line(
          Path()
            ..moveTo(8, 60)
            ..lineTo(16, 60)
            ..moveTo(5, 66)
            ..lineTo(13, 66),
          color.withValues(alpha: .45),
          2,
        );
      case RoleCardIcon.provider:
        // Professional in a white coat, plus cross and tool badges.
        rect(29, 44, 42, 33, Colors.white, 10);
        fill(
          Path()
            ..moveTo(44, 45)
            ..lineTo(50, 57)
            ..lineTo(56, 45)
            ..lineTo(60, 77)
            ..lineTo(40, 77)
            ..close(),
          color,
        );
        line(
          Path()
            ..moveTo(41, 44)
            ..lineTo(36, 55)
            ..lineTo(43, 60)
            ..moveTo(59, 44)
            ..lineTo(64, 55)
            ..lineTo(57, 60),
          deep.withValues(alpha: .5),
          2,
        );
        rect(45, 35, 10, 12, skin, 3);
        circle(50, 28, 12, skin);
        fill(
          Path()
            ..moveTo(38, 29)
            ..cubicTo(30, 9, 65, 8, 63, 30)
            ..lineTo(59, 23)
            ..lineTo(43, 23)
            ..close(),
          ink,
        );
        line(
          Path()
            ..moveTo(43, 24)
            ..lineTo(49, 25)
            ..lineTo(51, 25)
            ..lineTo(57, 24),
          deep,
          2,
        );
        circle(45, 27, 4, Colors.white.withValues(alpha: .55));
        circle(55, 27, 4, Colors.white.withValues(alpha: .55));
        line(
          Path()
            ..moveTo(40, 49)
            ..lineTo(40, 60)
            ..quadraticBezierTo(46, 70, 51, 60),
          deep,
          2,
        );
        circle(52, 61, 3, deep);
        circle(21, 48, 12, color);
        rect(18.5, 40.5, 5, 15, Colors.white, 1);
        rect(13.5, 45.5, 15, 5, Colors.white, 1);
        circle(79, 66, 12, deep);
        line(
          Path()
            ..moveTo(74, 72)
            ..lineTo(83, 61)
            ..moveTo(79, 60)
            ..lineTo(84, 64),
          Colors.white,
          3,
        );
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.role != role || old.color != color || old.progress != progress;
}
