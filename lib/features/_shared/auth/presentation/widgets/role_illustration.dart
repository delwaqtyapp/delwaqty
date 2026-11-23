import 'package:delwaqty/core/theme/app_colors.dart';

import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

enum RoleCardIcon { customer, merchant, delivery, provider }

/// Original native scenes; ticks only while visible, foreground and allowed.
class RoleIllustration extends StatefulWidget {
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
  State<RoleIllustration> createState() => _RoleIllustrationState();
}

class _RoleIllustrationState extends State<RoleIllustration>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _clock;
  Timer? _visibilityCheck;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visibilityCheck?.cancel();
    if (!MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled) {
      _visibilityCheck = Timer.periodic(
        const Duration(milliseconds: 600),
        (_) => _syncClock(),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncClock();
    });
  }

  void _syncClock() {
    if (!mounted) return;
    final box = context.findRenderObject();
    var visible = false;
    if (box is RenderBox && box.hasSize && box.attached) {
      final rect = box.localToGlobal(Offset.zero) & box.size;
      visible = rect.overlaps(Offset.zero & MediaQuery.sizeOf(context));
    }
    final enabled =
        visible &&
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context) &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (enabled && !_clock.isAnimating) _clock.repeat();
    if (!enabled && _clock.isAnimating) _clock.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncClock();
  }

  @override
  void dispose() {
    _visibilityCheck?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _clock,
      builder: (context, child) {
        final scene = (_clock.value * 4).floor() % 4;
        final asset = switch (widget.role) {
          RoleCardIcon.delivery => 'scooter',
          RoleCardIcon.customer => 'shopper',
          RoleCardIcon.merchant when scene == 2 => 'market',
          _ => null,
        };
        if (asset == null) {
          return CustomPaint(
            size: const Size(100, 88),
            painter: _ScenePainter(widget.role, widget.color, _clock),
          );
        }
        return SizedBox(
          width: 100,
          height: 88,
          child: ClipRect(
            child: Transform.scale(
              scale: asset == 'shopper'
                  ? 1.35
                  : asset == 'scooter'
                  ? 1.15
                  : 1,
              child: Lottie.asset(
                'assets/lottie/roles/$asset.lottie',
                controller: _ScenePhase(_clock),
                animate: false,
                fit: BoxFit.contain,
                frameRate: const FrameRate(24),
                errorBuilder: (context, error, stackTrace) => CustomPaint(
                  size: const Size(100, 88),
                  painter: _ScenePainter(widget.role, widget.color, _clock),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _ScenePhase extends Animation<double>
    with AnimationWithParentMixin<double> {
  _ScenePhase(this.parent);
  @override
  final Animation<double> parent;
  @override
  double get value => (parent.value * 4) % 1;
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.role, this.color, this.clock) : super(repaint: clock);
  final RoleCardIcon role;
  final Color color;
  final Animation<double> clock;
  static const ink = AppColors.roleSceneInk;
  static const skin = AppColors.roleSceneSkin;

  @override
  void paint(Canvas c, Size size) {
    c.scale(size.width / 100, size.height / 88);
    final progress = clock.value;
    final phase = progress * math.pi * 12;
    final scene = (progress * 4).floor() % 4;
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
        // Walking shopper: gentle horizontal walk, alternating legs, market stall.
        rect(6, 28, 20, 24, pale, 3);
        rect(4, 25, 24, 6, color.withValues(alpha: .3), 2);
        circle(12, 37, 3, color);
        circle(21, 37, 3, deep);
        c.save();
        c.translate(
          math.sin(progress * math.pi * 2) * 5,
          math.sin(phase).abs() * -1.5,
        );
        line(
          Path()
            ..moveTo(44, 66)
            ..lineTo(42 + math.sin(phase) * 5, 79)
            ..moveTo(56, 66)
            ..lineTo(58 - math.sin(phase) * 5, 79),
          ink,
          5,
        );
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
        c.restore();
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
        // Counter changes: butcher, dairy, produce and bakery.
        rect(22, 60, 27, 15, deep, 3);
        switch (scene) {
          case 0:
            c.drawOval(
              const Rect.fromLTWH(26, 61, 18, 10),
              Paint()..color = AppColors.roleSceneAccent1,
            );
            line(
              Path()
                ..moveTo(32, 64)
                ..lineTo(37, 68),
              Colors.white,
              2,
            );
          case 1:
            rect(26, 62, 7, 11, Colors.white, 2);
            rect(36, 62, 7, 11, Colors.white, 2);
            rect(27, 59, 5, 4, color, 1);
            rect(37, 59, 5, 4, color, 1);
          case 2:
            circle(29, 66, 4, AppColors.roleSceneAccent2);
            circle(38, 66, 4, AppColors.roleSceneAccent3);
            circle(34, 61, 4, AppColors.roleSceneAccent4);
          case 3:
            c.drawOval(
              const Rect.fromLTWH(25, 62, 20, 10),
              Paint()..color = AppColors.roleSceneAccent5,
            );
        }
        line(
          Path()
            ..moveTo(68, 62)
            ..lineTo(74, 57 + math.sin(phase) * 3),
          skin,
          4,
        );
      case RoleCardIcon.delivery:
        // Road markers slide and wheels rotate as the captain rides.
        line(
          Path()
            ..moveTo(7, 81)
            ..lineTo(93, 81),
          color.withValues(alpha: .18),
          2,
        );
        for (var n = 0; n < 4; n++) {
          final x = ((n * 28 - progress * 420) % 112) - 6;
          line(
            Path()
              ..moveTo(x, 84)
              ..lineTo(x + 12, 84),
            color.withValues(alpha: .4),
            1.6,
          );
        }
        c.save();
        c.translate(0, math.sin(phase) * .8);
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
        for (final x in [28.0, 77.0]) {
          final dx = math.cos(phase * 2) * 4;
          final dy = math.sin(phase * 2) * 4;
          line(
            Path()
              ..moveTo(x - dx, 70 - dy)
              ..lineTo(x + dx, 70 + dy),
            color,
            1.5,
          );
        }
        c.restore();
      case RoleCardIcon.provider:
        if (scene != 0) {
          // Shared professional silhouette with distinct working scenes.
          rect(33, 43, 30, 32, color, 9);
          rect(45, 35, 10, 12, skin, 3);
          circle(50, 28, 12, skin);
          fill(
            Path()
              ..moveTo(38, 29)
              ..cubicTo(31, 9, 65, 9, 63, 29)
              ..lineTo(57, 22)
              ..lineTo(42, 23)
              ..close(),
            ink,
          );
          switch (scene) {
            case 1:
              // Carpenter hammering a wooden workbench.
              rect(15, 67, 69, 6, AppColors.roleSceneAccent6, 2);
              rect(21, 73, 5, 9, deep, 1);
              rect(75, 73, 5, 9, deep, 1);
              rect(62, 60, 14, 7, AppColors.roleSceneAccent7, 1);
              final lift = math.sin(phase * 2) * 5;
              line(
                Path()
                  ..moveTo(59, 49)
                  ..lineTo(68, 52 + lift),
                skin,
                5,
              );
              line(
                Path()
                  ..moveTo(69, 59 + lift)
                  ..lineTo(69, 44 + lift),
                ink,
                3,
              );
              rect(63, 41 + lift, 13, 5, deep, 1);
            case 2:
              // Electrician with a safe illustrative lightning panel.
              rect(65, 35, 21, 34, deep);
              fill(
                Path()
                  ..moveTo(77, 41)
                  ..lineTo(70, 53)
                  ..lineTo(77, 53)
                  ..lineTo(72, 63)
                  ..lineTo(82, 50)
                  ..lineTo(76, 50)
                  ..close(),
                AppColors.roleSceneAccent8,
              );
              line(
                Path()
                  ..moveTo(60, 50)
                  ..lineTo(70, 56 + math.sin(phase) * 2),
                skin,
                5,
              );
              fill(
                Path()
                  ..moveTo(36, 24)
                  ..quadraticBezierTo(50, 5, 64, 24)
                  ..close(),
                color,
              );
            case 3:
              // Teacher pointing at a board with simple lesson marks.
              rect(4, 26, 30, 35, deep, 3);
              line(
                Path()
                  ..moveTo(10, 35)
                  ..lineTo(27, 35)
                  ..moveTo(10, 43)
                  ..lineTo(23, 43)
                  ..moveTo(10, 51)
                  ..lineTo(27, 51),
                Colors.white.withValues(alpha: .8),
                2,
              );
              line(
                Path()
                  ..moveTo(37, 48)
                  ..lineTo(27, 45 + math.sin(phase) * 3),
                skin,
                5,
              );
              line(
                Path()
                  ..moveTo(28, 44)
                  ..lineTo(19, 35),
                ink,
                1.5,
              );
          }
          break;
        }
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
      old.role != role || old.color != color || old.clock != clock;
}
