import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Springy scale-in success toast with an animated checkmark.
///
/// Shows briefly over the current screen and auto-dismisses with a fade.
/// Replaces plain SnackBars for confirmations in the admin app.
void showAnimatedSuccessToast(
  BuildContext context, {
  required String message,
  String? title,
  IconData icon = Icons.check_circle_rounded,
  Color? color,
  Duration duration = const Duration(milliseconds: 2200),
}) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => AnimatedSuccessToast(
      message: message,
      title: title,
      icon: icon,
      color: color,
      duration: duration,
      onDone: entry.remove,
    ),
  );
  overlay.insert(entry);
}

/// Scales + fades a [child] in with a spring curve (dialog / card entrance).
class SpringScaleIn extends StatefulWidget {
  const SpringScaleIn({
    super.key,
    required this.child,
    this.curve = Curves.easeOutBack,
  });

  final Widget child;
  final Curve curve;

  @override
  State<SpringScaleIn> createState() => _SpringScaleInState();
}

class _SpringScaleInState extends State<SpringScaleIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: widget.curve,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _animation, child: widget.child);
  }
}

/// Animated confirmation dialog: springy entrance, destructive-style button.
///
/// Returns `true` when confirmed, `false` on dismiss.
Future<bool> showAnimatedConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  IconData icon = Icons.warning_amber_rounded,
  Color? confirmColor,
}) async {
  final confirmed = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (ctx, _, __) {
      final theme = Theme.of(ctx);
      final color = confirmColor ?? theme.colorScheme.error;
      return AlertDialog(
        icon: Icon(icon, size: 42, color: color),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(cancelLabel),
            ),
          ),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: color),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(confirmLabel),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: curved, child: child),
      );
    },
  );
  return confirmed ?? false;
}

class AnimatedSuccessToast extends StatefulWidget {
  const AnimatedSuccessToast({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.check_circle_rounded,
    this.color,
    this.duration = const Duration(milliseconds: 2200),
    this.onDone,
  });

  final String message;
  final String? title;
  final IconData icon;
  final Color? color;
  final Duration duration;
  final VoidCallback? onDone;

  @override
  State<AnimatedSuccessToast> createState() => _AnimatedSuccessToastState();
}

class _AnimatedSuccessToastState extends State<AnimatedSuccessToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.25, curve: Curves.easeOutBack),
  );
  late final Animation<double> _fadeOut = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.8, 1, curve: Curves.easeIn),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(() {
      widget.onDone?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? const Color(0xFF22C55E);
    return Positioned(
      bottom: MediaQuery.of(context).size.height * 0.14,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Opacity(
                opacity: 1 - _fadeOut.value,
                child: Transform.scale(
                  scale: _scale.value,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF101828).withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _BouncingCheck(
                            controller: _controller,
                            icon: widget.icon,
                            color: color,
                          ),
                          const SizedBox(width: 14),
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.title != null) ...[
                                  Text(
                                    widget.title!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                Text(
                                  widget.message,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
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
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Checkmark that draws itself (stroke animation) inside a pulsing circle.
class _BouncingCheck extends StatelessWidget {
  const _BouncingCheck({
    required this.controller,
    required this.icon,
    required this.color,
  });

  final AnimationController controller;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        final circleScale = 0.7 + 0.3 * math.sin(t * math.pi * 4).abs();
        return Transform.scale(
          scale: circleScale.clamp(0.7, 1.0),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        );
      },
    );
  }
}