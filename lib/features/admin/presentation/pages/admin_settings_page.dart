import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

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
          _appNameController.text = data['app_name'] as String? ?? 'Delwaqty';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.platformSettings),
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
                  l10n.generalSettings,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 100),
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
                delay: const Duration(milliseconds: 200),
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
              const SizedBox(height: 24),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 300),
                child: Text(
                  l10n.dangerZone,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 400),
                child: Card(
                  child: ListTile(
                    title: Text(l10n.resetAllData),
                    subtitle: Text(l10n.resetAllDataDesc),
                    trailing: Icon(
                      Icons.warning,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(l10n.resetAllDataTitle),
                          content: Text(l10n.resetAllDataWarning),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(l10n.cancel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                l10n.reset,
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }

    ref.invalidate(platformSettingsProvider);
  }
}
