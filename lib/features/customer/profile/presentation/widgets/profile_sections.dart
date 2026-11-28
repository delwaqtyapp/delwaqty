import 'package:flutter/material.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';

/// Shared card/tile building blocks for the profile and settings screens.
class ProfileSectionCard extends StatelessWidget {
  const ProfileSectionCard({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.brandPurple, AppColors.brandViolet],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title!,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    letterSpacing: 0.15,
                  ),
                ),
              ],
            ),
          ),
        PremiumCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          radius: 20,
          color: cs.surfaceContainerLowest.withValues(alpha: 0.94),
          borderColor: cs.outlineVariant.withValues(alpha: 0.22),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: List.generate(children.length, (index) {
                final tile = children[index];
                return Column(
                  children: [
                    if (index > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Divider(
                          height: 1,
                          color: cs.outlineVariant.withValues(alpha: 0.25),
                        ),
                      ),
                    tile,
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

class ProfileSectionTile extends StatelessWidget {
  const ProfileSectionTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      minVerticalPadding: 10,
      leading: ProfileIconTile(icon: icon, color: color),
      title: Text(
        title,
        style: context.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: context.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
      ),
      onTap: onTap,
    );
  }
}

class ProfileIconTile extends StatelessWidget {
  const ProfileIconTile({super.key, required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}
