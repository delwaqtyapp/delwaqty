import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/admin/sanctions/presentation/sanctions_providers.dart';
import 'package:delwaqty/features/admin/financial/presentation/providers/admin_financial_providers.dart';
import 'package:delwaqty/shared/widgets/glass_card.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';

/// Platform-wide penalties list ("قايمة العقوبات العامة").
/// Owner-only: the server RPCs and the table guard both reject non-owner
/// writes; this page additionally hides the editor from scoped admins.
class AdminPenaltiesPolicyPage extends ConsumerWidget {
  const AdminPenaltiesPolicyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isOwner = ref.watch(adminIsOwnerProvider).value ?? false;
    final cancelDaysAsync = ref.watch(cancelSuspensionDaysProvider);
    final refusalDaysAsync = ref.watch(refusalSuspensionDaysProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.generalPenalties),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(cancelSuspensionDaysProvider);
              ref.invalidate(refusalSuspensionDaysProvider);
            },
          ),
        ],
      ),
      body: !isOwner
          ? PremiumEmptyState(
              icon: Icons.lock_outline_rounded,
              title: l10n.generalPenalties,
              message: l10n.ownerOnlyPenalties,
            )
          : _buildOwnerList(context, ref, cancelDaysAsync, refusalDaysAsync),
    );
  }

  Widget _buildOwnerList(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<int> cancelDaysAsync,
    AsyncValue<int> refusalDaysAsync,
  ) {
    final l10n = AppLocalizations.of(context);
    if (cancelDaysAsync.isLoading || refusalDaysAsync.isLoading) {
      return const Center(child: AppLoaderCircular());
    }
    final error = cancelDaysAsync.error ?? refusalDaysAsync.error;
    if (error != null) {
      return PremiumEmptyState(
        icon: Icons.error_outline,
        title: l10n.error,
        message: appErrorText(context, error),
      );
    }
    final cancelDays = cancelDaysAsync.value ?? 5;
    final refusalDays = refusalDaysAsync.value ?? 5;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            l10n.generalPenaltiesSubtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        AnimatedFadeIn(
          child: _penaltyCard(
            context,
            ref,
            icon: Icons.cancel_outlined,
            title: l10n.cancelSuspensionPenalty,
            description: l10n.cancelSuspensionPenaltyDescription,
            days: cancelDays,
            onSave: (days, reason) => ref
                .read(sanctionsRepositoryProvider)
                .setCancelSuspensionDays(days, reason: reason),
            onSaved: () => ref.invalidate(cancelSuspensionDaysProvider),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedFadeIn(
          child: _penaltyCard(
            context,
            ref,
            icon: Icons.block_rounded,
            title: l10n.refusalSuspensionPenalty,
            description: l10n.refusalSuspensionPenaltyDescription,
            days: refusalDays,
            onSave: (days, reason) => ref
                .read(sanctionsRepositoryProvider)
                .setRefusalSuspensionDays(days, reason: reason),
            onSaved: () => ref.invalidate(refusalSuspensionDaysProvider),
          ),
        ),
      ],
    );
  }

  Widget _penaltyCard(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String title,
    required String description,
    required int days,
    required Future<int> Function(int days, String reason) onSave,
    required VoidCallback onSaved,
  }) {
    final l10n = AppLocalizations.of(context);
    return GlassCard(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.warningLight.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.warningLight),
        ),
        title: Text(title, maxLines: 1),
        subtitle: Text('$description\n${l10n.duration}: $days ${l10n.days}'),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: l10n.editPenalty,
          icon: const Icon(Icons.edit_rounded),
          onPressed: () => _showEditDialog(
            context,
            ref,
            title: title,
            currentDays: days,
            onSave: onSave,
            onSaved: onSaved,
          ),
        ),
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required int currentDays,
    required Future<int> Function(int days, String reason) onSave,
    required VoidCallback onSaved,
  }) async {
    final l10n = AppLocalizations.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _PenaltyEditDialog(
        title: title,
        currentDays: currentDays,
        onSave: onSave,
      ),
    );

    if (saved == true && context.mounted) {
      onSaved();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.penaltyUpdated)));
    }
  }
}

/// Edit dialog for one penalty row. Owns its controllers so they are
/// disposed with the dialog widget (disposing them right after showDialog
/// returns would race the exit animation), and locks both actions while a
/// save is in flight so a double-tap cannot submit twice.
class _PenaltyEditDialog extends StatefulWidget {
  const _PenaltyEditDialog({
    required this.title,
    required this.currentDays,
    required this.onSave,
  });

  final String title;
  final int currentDays;
  final Future<int> Function(int days, String reason) onSave;

  @override
  State<_PenaltyEditDialog> createState() => _PenaltyEditDialogState();
}

class _PenaltyEditDialogState extends State<_PenaltyEditDialog> {
  late final TextEditingController _daysController;
  final TextEditingController _reasonController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _daysController = TextEditingController(text: '${widget.currentDays}');
  }

  @override
  void dispose() {
    _daysController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final days = int.parse(_daysController.text);
    setState(() => _saving = true);
    try {
      await widget.onSave(days, _reasonController.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(appErrorText(context, e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // While a write is in flight, block barrier taps and back-button
    // dismissal so the dialog cannot vanish mid-save.
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(l10n.editPenalty),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              TextFormField(
                controller: _daysController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.suspensionDaysLabel,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  final parsed = int.tryParse(value ?? '');
                  if (parsed == null || parsed < 1 || parsed > 365) {
                    return l10n.invalidSuspensionDays;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: l10n.penaltyChangeReasonHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: _saving ? null : _submit,
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
