import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/constants/app_constants.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/localization/admin_locale_provider.dart';

class AdminSettingsPage extends ConsumerStatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  ConsumerState<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends ConsumerState<AdminSettingsPage> {
  late TextEditingController _appNameController;
  late TextEditingController _supportEmailController;
  late TextEditingController _maxDriversPerZoneController;
  bool _maintenanceMode = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _appNameController = TextEditingController();
    _supportEmailController = TextEditingController();
    _maxDriversPerZoneController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = ref.read(platformSettingsProvider);
    settings.whenData((data) {
      if (data.isNotEmpty) {
        setState(() {
          _appNameController.text = data['app_name'] as String? ?? AppConstants.appName;
          _supportEmailController.text = data['support_email'] as String? ?? '';
          _maxDriversPerZoneController.text =
              (data['max_drivers_per_zone'] as int?)?.toString() ?? '10';
          _maintenanceMode = data['maintenance_mode'] as bool? ?? false;
        });
      }
    });
  }

  @override
  void dispose() {
    _appNameController.dispose();
    _supportEmailController.dispose();
    _maxDriversPerZoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settingsAsync = ref.watch(platformSettingsProvider);
    final adminLocale = ref.watch(adminLocaleProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminSettingsPage),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(platformSettingsProvider),
          ),
        ],
      ),
      body: settingsAsync.when(
        loading: () => const Center(
          child: AppLoaderCircular(),
        ),
        error: (e, _) => Center(
          child: PremiumEmptyState(
            icon: Icons.error_outline_rounded,
            title: l10n.error,
            message: l10n.errorLoading,
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(platformSettingsProvider),
          ),
        ),
        data: (_) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedFadeIn(
                child: Text(
                  l10n.adminPersonalSettings,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 60),
                child: Text(
                  l10n.adminPersonalSettingsDesc,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 120),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(l10n.adminLanguage),
                          subtitle: Text(l10n.adminLanguageDesc),
                          trailing: SegmentedButton<String>(
                            segments: [
                              ButtonSegment(
                                value: 'ar',
                                label: Text(l10n.arabicAbbreviation),
                              ),
                              ButtonSegment(
                                value: 'en',
                                label: Text(l10n.englishAbbreviation),
                              ),
                            ],
                            selected: {adminLocale.languageCode},
                            onSelectionChanged: (selected) {
                              ref
                                  .read(adminLocaleProvider.notifier)
                                  .setAdminLocale(
                                    Locale(selected.first),
                                  );
                            },
                            style: const ButtonStyle(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 180),
                child: Text(
                  l10n.adminGlobalSettings,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 240),
                child: Text(
                  l10n.adminGlobalSettingsDesc,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 300),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _appNameController,
                          decoration: InputDecoration(
                            labelText: l10n.appName,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _supportEmailController,
                          decoration: InputDecoration(
                            labelText: l10n.supportEmail,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _maxDriversPerZoneController,
                          decoration: InputDecoration(
                            labelText: l10n.maxDriversPerZone,
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: Text(l10n.maintenanceMode),
                          subtitle: Text(l10n.maintenanceModeDesc),
                          value: _maintenanceMode,
                          onChanged: (value) {
                            setState(() => _maintenanceMode = value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 360),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _saveSettings,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(l10n.saveSettings),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveSettings() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isLoading = true);

    final adminService = ref.read(adminServiceProvider);
    final success = await adminService.updateSettings({
      'app_name': _appNameController.text,
      'support_email': _supportEmailController.text,
      'max_drivers_per_zone':
          int.tryParse(_maxDriversPerZoneController.text) ?? 10,
      'maintenance_mode': _maintenanceMode,
    });

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? l10n.settingsSaved : l10n.settingsFailed),
          backgroundColor: success ? AppColors.successLight : AppColors.errorLight,
        ),
      );
    }

    ref.invalidate(platformSettingsProvider);
  }
}
