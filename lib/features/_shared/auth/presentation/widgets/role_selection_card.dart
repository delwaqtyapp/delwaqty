import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'role_illustration.dart';

export 'role_illustration.dart' show RoleCardIcon;

/// Equal-size account choice with a single stroke-icon and selection system.
class RoleSelectionCard extends StatelessWidget {
  const RoleSelectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.entranceIndex = 0,
  });

  final RoleCardIcon icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final int entranceIndex;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final content = Semantics(
      button: true,
      selected: isSelected,
      label: '$title. $subtitle',
      child: ExcludeSemantics(
        child: SizedBox(
          height: 226 + math.max(0, scale - 1) * 155,
          child: AnimatedContainer(
            duration: reducedMotion
                ? Duration.zero
                : const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: isSelected
                  ? Color.alphaBlend(
                      color.withValues(alpha: 0.06),
                      Colors.white,
                    )
                  : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSelected ? color : const Color(0xFFE8E8F0),
                width: 2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.14),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 26, 10, 16),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 100,
                              height: 88,
                              child: RoleIllustration(
                                role: icon,
                                color: color,
                                selected: isSelected,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                height: 1.4,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1035),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.6,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      top: 10,
                      end: 10,
                      child: AnimatedContainer(
                        duration: reducedMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? color : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? color : const Color(0xFFDFE1EC),
                            width: 2,
                          ),
                        ),
                        child: AnimatedScale(
                          scale: isSelected ? 1 : 0,
                          duration: reducedMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 200),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (reducedMotion) return content;
    final delay = entranceIndex * 80;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + delay),
      child: content,
      builder: (context, value, child) {
        final progress = Curves.easeOutCubic.transform(
          ((value * (300 + delay) - delay) / 300).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - progress)),
            child: child,
          ),
        );
      },
    );
  }
}
