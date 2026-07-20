import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/localization/locale_provider.dart';
import 'package:delwaqty/core/theme/theme_mode_provider.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AnimatedFadeIn(
          child: _buildSection(context, l10n.appearance, [
            _buildThemeTile(context, ref, l10n, themeMode),
            _buildLanguageTile(context, ref, l10n, locale),
          ]),
        ),
        const SizedBox(height: 16),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 100),
          child: _buildSection(context, l10n.account, [
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: Text(l10n.profile),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/profile'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.lock_outline_rounded),
              title: Text(l10n.privacySecurity),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/settings/privacy-security'),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 200),
          child: _buildSection(context, l10n.helpCenter, [
            ListTile(
              leading: const Icon(Icons.help_outline_rounded),
              title: Text(l10n.helpCenter),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/settings/help-center'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(l10n.about),
              subtitle: Text(l10n.version),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/settings/about'),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 300),
          child: _buildSection(context, l10n.legal, [
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(l10n.termsOfService),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/settings/terms-of-service'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(l10n.privacyPolicy),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/settings/privacy-policy'),
            ),
          ]),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: context.textTheme.titleSmall?.copyWith(
              color: context.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildThemeTile(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    ThemeMode themeMode,
  ) {
    return ListTile(
      leading: Icon(
        themeMode == ThemeMode.dark
            ? Icons.dark_mode_rounded
            : Icons.light_mode_rounded,
      ),
      title: Text(l10n.darkMode),
      trailing: SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(
            value: ThemeMode.light,
            icon: Icon(Icons.light_mode_rounded, size: 18),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            icon: Icon(Icons.dark_mode_rounded, size: 18),
          ),
          ButtonSegment(
            value: ThemeMode.system,
            icon: Icon(Icons.brightness_auto_rounded, size: 18),
          ),
        ],
        selected: {themeMode},
        onSelectionChanged: (selected) {
          ref.read(themeModeProvider.notifier).setThemeMode(selected.first);
        },
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageTile(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    Locale locale,
  ) {
    return ListTile(
      leading: const Icon(Icons.language_rounded),
      title: Text(l10n.language),
      trailing: SegmentedButton<String>(
        segments: [
          ButtonSegment(value: 'en', label: Text(l10n.englishAbbreviation)),
          ButtonSegment(value: 'ar', label: Text(l10n.arabicAbbreviation)),
        ],
        selected: {locale.languageCode},
        onSelectionChanged: (selected) {
          ref.read(localeProvider.notifier).setLocale(Locale(selected.first));
        },
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }
}
