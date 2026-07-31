import 'dart:math' as math;
import 'package:flutter/material.dart';

class PulseAnimation extends StatefulWidget {
  const PulseAnimation({
    required this.child,
    super.key,
    this.color = const Color(0xFF34C759),
    this.size = 48,
  });

  final Widget child;
  final Color color;
  final double size;

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        final opacity = (1.0 - value) * 0.35;
        final scale = 1.0 + value * 0.5;
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: opacity),
                ),
              ),
            ),
            Transform.scale(
              scale: 1.0 + math.sin(value * math.pi * 2) * 0.04,
              child: child,
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

class SlowPulseAnimation extends StatefulWidget {
  const SlowPulseAnimation({
    required this.child,
    super.key,
    this.color = const Color(0xFF8B5CF6),
    this.size = 48,
  });

  final Widget child;
  final Color color;
  final double size;

  @override
  State<SlowPulseAnimation> createState() => _SlowPulseAnimationState();
}

class _SlowPulseAnimationState extends State<SlowPulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = Curves.easeInOut.transform(_controller.value);
        return Transform.scale(
          scale: 1.0 + value * 0.06,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.25 * (1 - value)),
                  blurRadius: 20 * (1 - value * 0.5),
                  spreadRadius: 4 * (1 - value),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class GlowWidget extends StatelessWidget {
  const GlowWidget({
    required this.child,
    super.key,
    this.color = const Color(0xFF8B5CF6),
    this.radius = 60,
    this.opacity = 0.08,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: opacity),
                  blurRadius: radius,
                  spreadRadius: radius * 0.3,
                ),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class StaggeredSlideIn extends StatefulWidget {
  const StaggeredSlideIn({
    required this.children,
    super.key,
    this.offset = const Offset(0, 0.04),
    this.duration = const Duration(milliseconds: 350),
    this.staggerDelay = const Duration(milliseconds: 50),
  });

  final List<Widget> children;
  final Offset offset;
  final Duration duration;
  final Duration staggerDelay;

  @override
  State<StaggeredSlideIn> createState() => _StaggeredSlideInState();
}

class _StaggeredSlideInState extends State<StaggeredSlideIn>
    with TickerProviderStateMixin {
  List<AnimationController> _controllers = [];
  List<Animation<double>> _fadeAnims = [];
  List<Animation<Offset>> _slideAnims = [];
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _buildAnimations(widget.children.length);
    _runStagger();
  }

  @override
  void didUpdateWidget(covariant StaggeredSlideIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.children.length != widget.children.length) {
      for (final c in _controllers) {
        c.dispose();
      }
      _buildAnimations(widget.children.length);
      _runStagger();
    }
  }

  void _buildAnimations(int count) {
    _controllers = List.generate(math.max(0, count), (i) {
      return AnimationController(
        vsync: this,
        duration: widget.duration,
      );
    });
    _fadeAnims = _controllers.map((c) {
      return CurvedAnimation(parent: c, curve: Curves.easeOut);
    }).toList();
    _slideAnims = _controllers.map((c) {
      return Tween<Offset>(
        begin: widget.offset,
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic));
    }).toList();
  }

  Future<void> _runStagger() async {
    final gen = ++_generation;
    final count = _controllers.length;
    for (var i = 0; i < count; i++) {
      await Future.delayed(widget.staggerDelay);
      if (!mounted || gen != _generation) return;
      if (i < _controllers.length) {
        _controllers[i].forward();
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = math.min(_controllers.length, widget.children.length);
    if (count == 0) return const SizedBox.shrink();
    return Column(
      children: List.generate(count, (i) {
        if (i >= _fadeAnims.length || i >= _slideAnims.length) {
          return widget.children[i];
        }
        return AnimatedBuilder(
          animation: _controllers[i],
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnims[i],
              child: SlideTransition(
                position: _slideAnims[i],
                child: child,
              ),
            );
          },
          child: widget.children[i],
        );
      }),
    );
  }
}

class GradientPulseButton extends StatefulWidget {
  const GradientPulseButton({
    required this.onPressed,
    required this.child,
    super.key,
    this.gradient,
    this.height = 60,
    this.borderRadius = 22,
    this.isLoading = false,
    this.isEnabled = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Gradient? gradient;
  final double height;
  final double borderRadius;
  final bool isLoading;
  final bool isEnabled;

  @override
  State<GradientPulseButton> createState() => _GradientPulseButtonState();
}

class _GradientPulseButtonState extends State<GradientPulseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled =
        widget.isEnabled && !widget.isLoading && widget.onPressed != null;
    final grad = widget.gradient ??
        const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6), Color(0xFFA78BFA)],
        );

    return GestureDetector(
      onTapDown: enabled ? (_) => _scaleController.forward() : null,
      onTapUp: enabled
          ? (_) {
              _scaleController.reverse();
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: enabled ? () => _scaleController.reverse() : null,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            gradient: enabled ? grad : null,
            color: enabled ? null : const Color(0xFF2A2A3A),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: grad.colors.first.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: grad.colors.last.withValues(alpha: 0.15),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: enabled
                          ? Colors.white.withValues(alpha: 0.8)
                          : const Color(0xFF666680),
                    ),
                  )
                : DefaultTextStyle(
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color:
                          enabled ? Colors.white : const Color(0xFF666680),
                    ),
                    child: widget.child,
                  ),
          ),
        ),
      ),
    );
  }
}
