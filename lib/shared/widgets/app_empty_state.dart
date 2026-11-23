import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';

/// Canonical empty-state widget for the whole platform.
///
/// Merges the old `EmptyState` / `PremiumEmptyState` pair: the premium
/// visual (gradient illustration disc, gentle bounce, token spacing) is now
/// the single look. The legacy names remain as deprecated aliases.
class AppEmptyState extends StatefulWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.illustrationColor,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? illustrationColor;

  @override
  State<AppEmptyState> createState() => _AppEmptyStateState();
}

class _AppEmptyStateState extends State<AppEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _bounceAnimation = Tween<double>(begin: 0, end: -12).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = widget.illustrationColor ?? colorScheme.primary;

    // Content-sized and scrollable: at narrow widths and large text
    // scales the message wraps and the action button must never be
    // pushed off-screen or covered.
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _bounceAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _bounceAnimation.value),
                    child: child,
                  );
                },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                      colors: [
                        color.withValues(alpha: 0.15),
                        color.withValues(alpha: 0.05),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: Icon(widget.icon, size: 56, color: color),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.actionLabel != null && widget.onAction != null) ...[
                const SizedBox(height: AppSpacing.xl),
                FilledButton.tonal(
                  onPressed: widget.onAction,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl,
                      vertical: AppSpacing.md,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppSpacing.borderRadiusLg,
                    ),
                  ),
                  child: Text(widget.actionLabel!),
                ),
              ],
            ],
          ),
        );
        final scrollable = SingleChildScrollView(
          child: constraints.hasBoundedHeight
              ? ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(child: content),
                )
              : content,
        );
        return scrollable;
      },
    );
  }
}
