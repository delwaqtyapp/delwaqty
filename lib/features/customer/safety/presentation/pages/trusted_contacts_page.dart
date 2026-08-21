import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/customer/safety/presentation/safety_providers.dart';
import 'package:delwaqty/features/customer/safety/domain/entities/trusted_contact.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';

class TrustedContactsPage extends ConsumerWidget {
  const TrustedContactsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(trustedContactsProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trustedContacts),
        actions: [
          IconButton(
            onPressed: () => _showAddContactSheet(context, ref),
            icon: const Icon(Icons.person_add_rounded),
          ),
        ],
      ),
      body: contactsAsync.when(
        loading: () => const SkeletonListTile(),
        error: (e, _) => Center(child: Text(l10n.errorLoadingData)),
        data: (contacts) {
          if (contacts.isEmpty) {
            return PremiumEmptyState(
              icon: Icons.contacts_rounded,
              title: l10n.noTrustedContacts,
              message: l10n.addTrustedContactsDescription,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: contacts.length,
            itemBuilder: (context, index) => _buildContactCard(
              context,
              ref,
              contacts[index],
              l10n,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddContactSheet(context, ref),
        icon: const Icon(Icons.person_add_rounded),
        label: Text(l10n.addTrustedContact),
      ),
    );
  }

  Widget _buildContactCard(
    BuildContext context,
    WidgetRef ref,
    TrustedContact contact,
    AppLocalizations l10n,
  ) {
    final relationshipLabel = contact.relationship != null
        ? _relationshipLabel(contact.relationship!, l10n)
        : '';
    final prefLabel = _preferenceLabel(contact.notificationPreference, l10n);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
          child: Text(
            contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryLight,
            ),
          ),
        ),
        title: Text(contact.name, style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(contact.phone, style: AppTextStyles.bodyMedium.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            if (contact.email != null)
              Text(contact.email!, style: AppTextStyles.bodySmall.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (relationshipLabel.isNotEmpty)
                  _buildChip(relationshipLabel, AppColors.infoLight),
                _buildChip(prefLabel, AppColors.successLight),
                if (!contact.notifyOnRide)
                  _buildChip(l10n.notificationsDisabled, AppColors.warningLight),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  const Icon(Icons.edit_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(l10n.edit),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete_rounded, size: 18, color: AppColors.errorLight),
                  const SizedBox(width: 8),
                  Text(l10n.delete, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.errorLight)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _showAddContactSheet(context, ref, contact: contact);
            } else if (value == 'delete') {
              _confirmDelete(context, ref, contact, l10n);
            }
          },
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: color),
      ),
    );
  }

  String _relationshipLabel(ContactRelationship r, AppLocalizations l10n) {
    switch (r) {
      case ContactRelationship.family:
        return l10n.family;
      case ContactRelationship.friend:
        return l10n.friend;
      case ContactRelationship.colleague:
        return l10n.colleague;
      case ContactRelationship.other:
        return l10n.other;
    }
  }

  String _preferenceLabel(NotificationPreference p, AppLocalizations l10n) {
    switch (p) {
      case NotificationPreference.sms:
        return 'SMS';
      case NotificationPreference.call:
        return l10n.call;
      case NotificationPreference.push:
        return l10n.pushNotification;
      case NotificationPreference.both:
        return l10n.both;
    }
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TrustedContact contact,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteContact),
        content: Text(l10n.deleteContactConfirmation(contact.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              try {
                ref.read(safetyRepositoryProvider).deleteTrustedContact(contact.id);
              } catch (e) {
                debugPrint('Failed to delete trusted contact: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorLight),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _showAddContactSheet(BuildContext context, WidgetRef ref, {TrustedContact? contact}) {
    final nameController = TextEditingController(text: contact?.name ?? '');
    final phoneController = TextEditingController(text: contact?.phone ?? '');
    final emailController = TextEditingController(text: contact?.email ?? '');
    ContactRelationship? selectedRelationship = contact?.relationship;
    bool notifyOnRide = contact?.notifyOnRide ?? true;
    NotificationPreference selectedPref = contact?.notificationPreference ?? NotificationPreference.both;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final l10n = AppLocalizations.of(ctx);
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    contact != null ? l10n.editContact : l10n.addTrustedContact,
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: l10n.name,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: l10n.phoneNumber,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: l10n.emailOptional,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ContactRelationship>(
                    initialValue: selectedRelationship,
                    decoration: InputDecoration(
                      labelText: l10n.relationship,
                      border: const OutlineInputBorder(),
                    ),
                    items: ContactRelationship.values
                        .map((r) => DropdownMenuItem(value: r, child: Text(_relationshipLabel(r, l10n))))
                        .toList(),
                    onChanged: (v) => setState(() => selectedRelationship = v),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: Text(l10n.notifyOnRide),
                    subtitle: Text(l10n.notifyOnRideDescription),
                    value: notifyOnRide,
                    onChanged: (v) => setState(() => notifyOnRide = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (notifyOnRide) ...[
                    const SizedBox(height: 8),
                    Text(l10n.notificationMethod, style: Theme.of(ctx).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SegmentedButton<NotificationPreference>(
                      segments: [
                        ButtonSegment(value: NotificationPreference.sms, label: Text(l10n.sms)),
                        ButtonSegment(value: NotificationPreference.call, label: Text(l10n.call)),
                        ButtonSegment(value: NotificationPreference.push, label: Text(l10n.pushNotification)),
                        ButtonSegment(value: NotificationPreference.both, label: Text(l10n.both)),
                      ],
                      selected: {selectedPref},
                      onSelectionChanged: (v) => setState(() => selectedPref = v.first),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.isEmpty || phoneController.text.isEmpty) return;
                        try {
                          await ref.read(safetyRepositoryProvider).upsertTrustedContact(
                                nameController.text.trim(),
                                phoneController.text.trim(),
                                id: contact?.id,
                                email: emailController.text.trim().isEmpty
                                    ? null
                                    : emailController.text.trim(),
                                relationship: selectedRelationship,
                                notifyOnRide: notifyOnRide,
                                notificationPreference: selectedPref,
                              );
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(AppLocalizations.of(ctx).somethingWentWrong)),
                            );
                          }
                        }
                      },
                      child: Text(contact != null ? l10n.saveLabel : l10n.addLabel),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
