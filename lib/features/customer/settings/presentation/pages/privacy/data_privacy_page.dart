import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/shared/widgets/confirm_dialog.dart';

class DataPrivacyPage extends ConsumerStatefulWidget {
  const DataPrivacyPage({super.key});

  @override
  ConsumerState<DataPrivacyPage> createState() => _DataPrivacyPageState();
}

class _DataPrivacyPageState extends ConsumerState<DataPrivacyPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dataPrivacy),
        leading: IconButton(
          tooltip: l10n.back,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.brandPurpleDeep,
                  AppColors.brandPurple,
                  AppColors.brandViolet,
                ],
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandPurple.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.storage_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.dataPrivacy,
                        style: context.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.privacy,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Material(
            color: cs.surfaceContainerLowest,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.download_outlined,
                      color: cs.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    l10n.exportMyData,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    l10n.exportDataDescription,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                  onTap: () => _exportMyData(l10n),
                ),
                Divider(
                  height: 1,
                  indent: 66,
                  endIndent: 16,
                  color: cs.outlineVariant.withValues(alpha: 0.35),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.visibility_outlined,
                      color: cs.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    l10n.dataSharing,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    l10n.dataSharingDescription,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                  onTap: () => context.showAppSnackBar(l10n.dataSharingInfo),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Material(
            color: AppColors.errorLight.withValues(alpha: 0.06),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: AppColors.errorLight.withValues(alpha: 0.25),
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.errorLight.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.errorLight,
                  size: 20,
                ),
              ),
              title: Text(
                l10n.deleteAccount,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: AppColors.errorLight,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                l10n.deleteAccountDescription,
                style: context.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.errorLight,
              ),
              onTap: () => _confirmDelete(l10n),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportMyData(AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    final client = ref.read(supabaseClientProvider);
    final uid = client.auth.currentUser?.id;
    if (uid == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.loginRequired),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      final profile = await client
          .from('users')
          .select()
          .eq('id', uid)
          .maybeSingle();
      final orders = await client
          .from('orders')
          .select('id, status, total_amount, payment_method, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(50);
      final export = jsonEncode({
        'exported_at': DateTime.now().toIso8601String(),
        'profile': profile,
        'orders': orders,
      });
      await Clipboard.setData(ClipboardData(text: export));
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.dataExported),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.somethingWentWrong),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDelete(AppLocalizations l10n) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: l10n.deleteAccount,
      message: l10n.deleteAccountConfirm,
      confirmLabel: l10n.delete,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(authStateProvider.notifier).deleteAccount();
    if (!mounted) return;
    final authState = ref.read(authStateProvider);
    if (authState is AuthUnauthenticated) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountDeleted)));
    } else if (authState is AuthError) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountDeletionInfo)));
    }
  }
}
