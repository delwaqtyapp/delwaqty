import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/core/theme/theme_mode_provider.dart';
import 'package:delwaqty/core/localization/locale_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'sidebar_theme.dart';

class QuickSettingsCard extends StatelessWidget {
  const QuickSettingsCard({
    super.key,
    required this.ref,
    required this.l10n,
  });

  final WidgetRef ref;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final st = Theme.of(context).extension<SidebarTheme>()!;
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
        children: [
          _QuickSettingTile(
            icon: themeMode == ThemeMode.dark
                ? Icons.dark_mode_rounded
                : Icons.light_mode_rounded,
            label: l10n.darkMode,
            st: st,
            trailing: Transform.scale(
              scale: 0.75,
              child: Switch(
                value: themeMode == ThemeMode.dark,
                activeThumbColor: st.selectedGradientStart,
                onChanged: (_) => ref.read(themeModeProvider.notifier).toggleTheme(),
              ),
            ),
          ),
          _QuickSettingTile(
            icon: Icons.language_rounded,
            label: l10n.language,
            st: st,
            subtitle: locale.languageCode == 'ar' ? 'العربية' : 'English',
            trailing: GestureDetector(
              onTap: () => ref.read(localeProvider.notifier).toggleLocale(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: st.dividerColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      locale.languageCode == 'ar' ? 'العربية' : 'English',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: st.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: st.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickSettingTile extends StatelessWidget {
  const _QuickSettingTile({
    required this.icon,
    required this.label,
    required this.st,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final SidebarTheme st;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Icon(icon, size: 18, color: st.iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: st.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: st.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
