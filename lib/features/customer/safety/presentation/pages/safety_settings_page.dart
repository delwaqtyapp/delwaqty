import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/customer/safety/presentation/safety_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';

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
          _GlassSection(
            title: l10n.sosSettings,
            icon: Icons.emergency_rounded,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_rounded, color: AppColors.errorLight),
                title: Text(l10n.sosAlertEnabled),
                subtitle: Text(l10n.sosAlertEnabledDescription),
                value: true,
                onChanged: null,
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.timer_rounded, color: AppColors.warningLight),
                title: Text(l10n.autoSosTimer),
                subtitle: Text(l10n.autoSosTimerDescription),
                value: false,
                onChanged: null,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _GlassSection(
            title: l10n.tripSharing,
            icon: Icons.share_rounded,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.share_location_rounded, color: AppColors.primaryLight),
                title: Text(l10n.autoShareTrip),
                subtitle: Text(l10n.autoShareTripDescription),
                value: false,
                onChanged: null,
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                leading: const Icon(Icons.timer_rounded, color: AppColors.infoLight),
                title: Text(l10n.shareDuration),
                subtitle: Text('60 ${l10n.minutes}'),
                contentPadding: EdgeInsets.zero,
                enabled: false,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _GlassSection(
            title: l10n.emergencyContacts,
            icon: Icons.contacts_rounded,
            children: [
              contactsAsync.when(
                loading: () => const SkeletonListTile(),
                error: (_, __) => Text(l10n.somethingWentWrong),
                data: (contacts) {
                  final activeCount = contacts.where((c) => c.notifyOnRide).length;
                  return ListTile(
                    leading: const Icon(Icons.people_rounded, color: AppColors.primaryLight),
                    title: Text(l10n.trustedContacts),
                    subtitle: Text(
                      activeCount > 0
                          ? '$activeCount ${l10n.emergencyContacts.toLowerCase()}'
                          : l10n.noTrustedContacts,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    contentPadding: EdgeInsets.zero,
                    onTap: () => context.push('/safety/contacts'),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _GlassSection(
            title: l10n.pickupVerification,
            icon: Icons.pin_rounded,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.pin_rounded, color: AppColors.successLight),
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
}

class _GlassSection extends StatelessWidget {
  const _GlassSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: cs.outline.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: AppColors.primaryLight),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      title,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryLight,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
