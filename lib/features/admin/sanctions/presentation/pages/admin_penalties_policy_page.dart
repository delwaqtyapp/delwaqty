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
/// Owner-only: the server RPC and the table guard both reject non-owner
/// writes; this page additionally hides the editor from scoped admins.
class AdminPenaltiesPolicyPage extends ConsumerWidget {
  const AdminPenaltiesPolicyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isOwner = ref.watch(adminIsOwnerProvider).value ?? false;
    final daysAsync = ref.watch(cancelSuspensionDaysProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.generalPenalties),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(cancelSuspensionDaysProvider),
          ),
        ],
      ),
      body: !isOwner
          ? PremiumEmptyState(
              icon: Icons.lock_outline_rounded,
              title: l10n.generalPenalties,
              message: l10n.ownerOnlyPenalties,
            )
          : daysAsync.when(
              loading: () => const Center(child: AppLoaderCircular()),
              error: (e, _) => PremiumEmptyState(
                icon: Icons.error_outline,
                title: l10n.error,
                message: appErrorText(context, e),
              ),
              data: (days) {
                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: Text(
                        l10n.generalPenaltiesSubtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    AnimatedFadeIn(
                      child: GlassCard(
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.warningLight.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.block_rounded,
                              color: AppColors.warningLight,
                            ),
                          ),
                          title: Text(
                            l10n.cancelSuspensionPenalty,
                            maxLines: 1,
                          ),
                          subtitle: Text(
                            '${l10n.cancelSuspensionPenaltyDescription}\n'
                            '${l10n.duration}: $days ${l10n.days}',
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            tooltip: l10n.editPenalty,
                            icon: const Icon(Icons.edit_rounded),
                            onPressed: () => _showEditDialog(
                              context,
                              ref,
                              currentDays: days,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref, {
    required int currentDays,
  }) async {
    final l10n = AppLocalizations.of(context);
    final daysController = TextEditingController(text: '$currentDays');
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editPenalty),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.cancelSuspensionPenalty,
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: daysController,
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
                controller: reasonController,
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
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final days = int.parse(daysController.text);
              try {
                final repo = ref.read(sanctionsRepositoryProvider);
                await repo.setCancelSuspensionDays(
                  days,
                  reason: reasonController.text,
                );
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(appErrorText(ctx, e))),
                  );
                }
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (saved == true && context.mounted) {
      ref.invalidate(cancelSuspensionDaysProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.penaltyUpdated)));
    }
  }
}
