import 'package:flutter/material.dart';

/// Wraps [child] with a subtle press-down scale animation for tactile feedback.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.96,
    this.onTapUp,
  });

  final Widget child;

  /// Called when the wrapped widget is tapped.
  final VoidCallback onTap;

  /// Scale applied while pressed. Defaults to 0.96.
  final double scale;

  /// Optional callback fired when the press is released.
  final VoidCallback? onTapUp;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTapUp?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
