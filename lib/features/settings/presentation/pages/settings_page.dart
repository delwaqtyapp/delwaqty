import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/localization/locale_provider.dart';
import 'package:delwaqty/core/theme/theme_mode_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.settings,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: Text(l10n.darkMode),
          subtitle: Text(
            themeMode == ThemeMode.dark ? l10n.yes : l10n.no,
          ),
          value: themeMode == ThemeMode.dark,
          onChanged: (_) {
            ref.read(themeModeProvider.notifier).toggleTheme();
          },
        ),
        const Divider(),
        Text(
          l10n.language,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 8),
        RadioGroup<String>(
          groupValue: locale.languageCode,
          onChanged: (String? value) {
            if (value != null) {
              ref.read(localeProvider.notifier).setLocale(Locale(value));
            }
          },
          child: const Column(
            children: [
              ListTile(
                leading: Radio<String>(value: 'en'),
                title: Text('English'),
              ),
              ListTile(
                leading: Radio<String>(value: 'ar'),
                title: Text('العربية'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
