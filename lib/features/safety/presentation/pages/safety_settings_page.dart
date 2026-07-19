import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/safety/presentation/safety_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';

class SafetySettingsPage extends ConsumerWidget {
  const SafetySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final contactsAsync = ref.watch(trustedContactsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.safetySettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(context, l10n.sosSettings, Icons.emergency_rounded),
          const SizedBox(height: 8),
          _buildSettingsCard(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_rounded, color: Colors.red),
                title: Text(l10n.sosAlertEnabled),
                subtitle: Text(l10n.sosAlertEnabledDescription),
                value: true,
                onChanged: null,
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(),
              SwitchListTile(
                secondary: const Icon(Icons.timer_rounded, color: Colors.orange),
                title: Text(l10n.autoSosTimer),
                subtitle: Text(l10n.autoSosTimerDescription),
                value: false,
                onChanged: null,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, l10n.tripSharing, Icons.share_rounded),
          const SizedBox(height: 8),
          _buildSettingsCard(
            children: [
              SwitchListTile(
                secondary: Icon(Icons.share_location_rounded, color: AppColors.primaryLight),
                title: Text(l10n.autoShareTrip),
                subtitle: Text(l10n.autoShareTripDescription),
                value: false,
                onChanged: null,
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.timer_rounded, color: Colors.blue),
                title: Text(l10n.shareDuration),
                subtitle: Text('60 ${l10n.minutes}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                contentPadding: EdgeInsets.zero,
                onTap: null,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, l10n.emergencyContacts, Icons.contacts_rounded),
          const SizedBox(height: 8),
          contactsAsync.when(
            loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const SizedBox.shrink(),
            data: (contacts) {
              final activeCount = contacts.where((c) => c.notifyOnRide).length;
              return _buildSettingsCard(
                children: [
                  ListTile(
                    leading: Icon(Icons.people_rounded, color: AppColors.primaryLight),
                    title: Text(l10n.trustedContacts),
                    subtitle: Text(
                      activeCount > 0
                          ? '$activeCount ${l10n.emergencyContacts.toLowerCase()}'
                          : l10n.noTrustedContacts,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    contentPadding: EdgeInsets.zero,
                    onTap: () => context.push('/safety/contacts'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, l10n.pickupVerification, Icons.pin_rounded),
          const SizedBox(height: 8),
          _buildSettingsCard(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.pin_rounded, color: Colors.green),
                title: Text(l10n.pickupOtpRequired),
                subtitle: Text(l10n.pickupOtpRequiredDescription),
                value: true,
                onChanged: null,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryLight),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryLight,
              ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(children: children),
      ),
    );
  }
}
