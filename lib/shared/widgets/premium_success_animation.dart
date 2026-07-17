import 'package:flutter/material.dart';

class PremiumSuccessAnimation extends StatefulWidget {
  const PremiumSuccessAnimation({
    super.key,
    this.size = 120,
    this.color,
    this.onComplete,
  });

  final double size;
  final Color? color;
  final VoidCallback? onComplete;

  @override
  State<PremiumSuccessAnimation> createState() =>
      _PremiumSuccessAnimationState();
}

class _PremiumSuccessAnimationState extends State<PremiumSuccessAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final AnimationController _checkController;
  late final AnimationController _glowController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _checkAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _checkAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.easeOutCubic),
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _scaleController.forward().then((_) {
      _checkController.forward().then((_) {
        widget.onComplete?.call();
      });
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _checkController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _glowAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: _glowAnimation.value * 0.2),
                  color.withValues(alpha: 0.05),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: _glowAnimation.value * 0.3),
                  blurRadius: 40 * _glowAnimation.value,
                  spreadRadius: 10 * _glowAnimation.value,
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
              child: AnimatedBuilder(
                animation: _checkAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _CheckPainter(
                      progress: _checkAnimation.value,
                      color: Colors.white,
                      strokeWidth: widget.size * 0.06,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final checkPath = Path();
    checkPath.moveTo(center.dx - size.width * 0.2, center.dy);
    checkPath.lineTo(center.dx - size.width * 0.05, center.dy + size.height * 0.15);
    checkPath.lineTo(center.dx + size.width * 0.2, center.dy - size.height * 0.15);

    final metric = checkPath.computeMetrics().first;
    final extractedPath = metric.extractPath(0, metric.length * progress);

    canvas.drawPath(extractedPath, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}
