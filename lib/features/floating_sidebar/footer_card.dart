import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'sidebar_theme.dart';

class FooterCard extends StatelessWidget {
  const FooterCard({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final st = Theme.of(context).extension<SidebarTheme>()!;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      decoration: BoxDecoration(
        color: st.quickSettingsBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: st.dividerColor,
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class FooterTile extends StatelessWidget {
  const FooterTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.isDestructive = false,
    this.showTopBorder = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool isDestructive;
  final bool showTopBorder;

  @override
  Widget build(BuildContext context) {
    final st = Theme.of(context).extension<SidebarTheme>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showTopBorder)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(height: 0.5, color: st.dividerColor),
          ),
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Icon(
                    icon,
                    size: 18,
                    color: isDestructive ? st.selectedGradientStart : st.iconColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: isDestructive ? st.selectedGradientStart : st.textPrimary,
                      fontSize: 13,
                      fontWeight: isDestructive ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (trailing != null)
                  trailing!
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: st.iconColor.withValues(alpha: 0.3),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AppVersionTile extends StatelessWidget {
  const AppVersionTile({super.key, required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    final st = Theme.of(context).extension<SidebarTheme>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Icon(Icons.info_outline_rounded, size: 16, color: st.iconColor),
          ),
          const SizedBox(width: 12),
          Text(
            'App Version',
            style: AppTextStyles.labelMedium.copyWith(
              color: st.textSecondary,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            version,
            style: AppTextStyles.labelSmall.copyWith(
              color: st.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
