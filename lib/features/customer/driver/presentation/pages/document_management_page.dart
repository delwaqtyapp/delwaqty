import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/customer/driver/driver_module.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/driver_document.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

final _documentsProvider = FutureProvider.family<List<DriverDocument>, String>((ref, driverId) async {
  final repo = ref.watch(driverRepositoryProvider);
  return repo.getDocuments(driverId);
});

class _DocTypeEntry {
  const _DocTypeEntry({
    required this.key,
    required this.icon,
  });

  final String key;
  final IconData icon;
}

const _docTypeEntries = [
  _DocTypeEntry(key: 'identity', icon: Icons.badge_rounded),
  _DocTypeEntry(key: 'driving_license', icon: Icons.credit_card_rounded),
  _DocTypeEntry(key: 'vehicle_registration', icon: Icons.description_rounded),
  _DocTypeEntry(key: 'insurance', icon: Icons.shield_rounded),
  _DocTypeEntry(key: 'vehicle_photo', icon: Icons.photo_camera_rounded),
  _DocTypeEntry(key: 'profile_photo', icon: Icons.person_rounded),
];

String _docTypeLabel(AppLocalizations l10n, String docType) {
  switch (docType) {
    case 'identity':
      return l10n.identityDocument;
    case 'driving_license':
      return l10n.drivingLicense;
    case 'vehicle_registration':
      return l10n.vehicleRegistration;
    case 'insurance':
      return l10n.insurance;
    case 'vehicle_photo':
      return l10n.vehiclePhoto;
    case 'profile_photo':
      return l10n.profilePhoto;
    default:
      return docType;
  }
}

class DocumentManagementPage extends ConsumerWidget {
  const DocumentManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);

    final userId = authState is AuthAuthenticated ? authState.user.id : null;
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.documentManagement)),
        body: Center(child: Text(l10n.pleaseLogIn)),
      );
    }

    final profileAsync = ref.watch(driverProfileProvider(userId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.documentManagement)),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorWithMessage(e.toString()))),
        data: (profile) {
          if (profile == null) {
            return Center(child: Text(l10n.noDocuments));
          }
          return _DocumentListBody(driverId: profile.id);
        },
      ),
    );
  }
}

class _DocumentListBody extends ConsumerWidget {
  const _DocumentListBody({required this.driverId});

  final String driverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final documentsAsync = ref.watch(_documentsProvider(driverId));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(_documentsProvider(driverId)),
      child: documentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorWithMessage(e.toString()))),
        data: (documents) {
          final docMap = <String, DriverDocument>{};
          for (final doc in documents) {
            docMap[doc.docType] = doc;
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _docTypeEntries.length,
            itemBuilder: (context, index) {
              final entry = _docTypeEntries[index];
              final doc = docMap[entry.key];
              return AnimatedFadeIn(
                delay: Duration(milliseconds: 80 * index),
                child: _DocumentCard(
                  docType: entry.key,
                  icon: entry.icon,
                  document: doc,
                  onTap: () => _showUploadPlaceholder(context),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showUploadPlaceholder(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.uploadComingSoon)),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.docType,
    required this.icon,
    required this.document,
    required this.onTap,
  });

  final String docType;
  final IconData icon;
  final DriverDocument? document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = document?.status ?? 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _docTypeLabel(l10n, docType),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _StatusBadge(status: status),
                        if (document?.expiresAt != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${l10n.expiresOn} ${document!.expiresAt!.day}/${document!.expiresAt!.month}/${document!.expiresAt!.year}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (document?.rejectionReason != null &&
                        document!.rejectionReason!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.rejectionReason}: ${document!.rejectionReason}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    Color backgroundColor;
    Color foregroundColor;
    String label;
    IconData icon;

    switch (status) {
      case 'verified':
        backgroundColor = AppColors.successLight.withValues(alpha: 0.15);
        foregroundColor = AppColors.successLight;
        label = l10n.documentVerified;
        icon = Icons.check_circle_rounded;
      case 'rejected':
        backgroundColor = theme.colorScheme.error.withValues(alpha: 0.15);
        foregroundColor = theme.colorScheme.error;
        label = l10n.documentRejected;
        icon = Icons.cancel_rounded;
      default:
        backgroundColor = AppColors.warningLight.withValues(alpha: 0.15);
        foregroundColor = AppColors.warningLight;
        label = l10n.documentPending;
        icon = Icons.schedule_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foregroundColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
