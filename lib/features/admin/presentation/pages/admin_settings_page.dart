import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/admin/admin_service.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';

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
    final settingsAsync = ref.watch(platformSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(platformSettingsProvider),
          ),
        ],
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (_) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'General Settings',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _appNameController,
                        decoration: const InputDecoration(
                          labelText: 'App Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _supportEmailController,
                        decoration: const InputDecoration(
                          labelText: 'Support Email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _maxDriversPerZoneController,
                        decoration: const InputDecoration(
                          labelText: 'Max Drivers Per Zone',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('Maintenance Mode'),
                        subtitle: const Text('Temporarily disable the app'),
                        value: _maintenanceMode,
                        onChanged: (value) {
                          setState(() => _maintenanceMode = value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveSettings,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Settings'),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Danger Zone',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  title: const Text('Reset All Data'),
                  subtitle: const Text('Permanently delete all platform data'),
                  trailing: const Icon(Icons.warning, color: Colors.red),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Reset All Data?'),
                        content: const Text(
                          'This action cannot be undone. All data will be permanently deleted.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Reset',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    final adminService = ref.read(adminServiceProvider);
    final success = await adminService.updateSettings({
      'app_name': _appNameController.text,
      'support_email': _supportEmailController.text,
      'max_drivers_per_zone': int.tryParse(_maxDriversPerZoneController.text) ?? 10,
      'maintenance_mode': _maintenanceMode,
    });

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Settings saved' : 'Failed to save settings'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }

    ref.invalidate(platformSettingsProvider);
  }
}
