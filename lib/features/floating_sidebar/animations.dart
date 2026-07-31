import 'package:flutter/material.dart';

class StaggerAnimation extends StatelessWidget {
  const StaggerAnimation({
    super.key,
    required this.controller,
    required this.index,
    required this.child,
    this.delay = 40,
    this.duration = 300,
  });

  final Animation<double> controller;
  final int index;
  final Widget child;
  final int delay;
  final int duration;

  @override
  Widget build(BuildContext context) {
    final double start = index * delay / 1000;
    final double end = start + duration / 1000;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final double t = (controller.value - start) / (end - start);
        final double clamped = t.clamp(0.0, 1.0);

        return Opacity(
          opacity: clamped,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - clamped)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class ScaleFadeAnimation extends StatelessWidget {
  const ScaleFadeAnimation({
    super.key,
    required this.controller,
    required this.child,
    this.beginScale = 0.95,
  });

  final Animation<double> controller;
  final Widget child;
  final double beginScale;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final double scale = beginScale + (1 - beginScale) * controller.value;
        return Opacity(
          opacity: controller.value,
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class SlideDownAnimation extends StatelessWidget {
  const SlideDownAnimation({
    super.key,
    required this.controller,
    required this.child,
    this.beginOffset = const Offset(0, -8),
  });

  final Animation<double> controller;
  final Widget child;
  final Offset beginOffset;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.translate(
          offset: beginOffset * (1 - controller.value),
          child: Opacity(
            opacity: controller.value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
