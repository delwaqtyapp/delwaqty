import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/confirm_dialog.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DataPrivacyPage extends StatelessWidget {
  const DataPrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dataPrivacy),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(l10n.exportMyData),
            subtitle: Text(l10n.exportDataDescription),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _exportMyData(context, l10n),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: AppColors.errorLight),
            title: Text(l10n.deleteAccount, style: const TextStyle(color: AppColors.errorLight)),
            subtitle: Text(l10n.deleteAccountDescription),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _confirmDelete(context, l10n),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.visibility_outlined),
            title: Text(l10n.dataSharing),
            subtitle: Text(l10n.dataSharingDescription),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.showAppSnackBar(l10n.dataSharingInfo),
          ),
        ],
      ),
    );
  }

  Future<void> _exportMyData(BuildContext context, AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.loginRequired), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    try {
      final profile = await client.from('users').select().eq('id', uid).maybeSingle();
      final orders = await client
          .from('orders')
          .select('id, status, total, payment_method, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(50);
      final export = jsonEncode({
        'exported_at': DateTime.now().toIso8601String(),
        'profile': profile,
        'orders': orders,
      });
      await Clipboard.setData(ClipboardData(text: export));
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.dataExported), behavior: SnackBarBehavior.floating),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.somethingWentWrong),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, AppLocalizations l10n) async {
      final confirmed = await ConfirmDialog.show(
        context,
        title: l10n.deleteAccount,
        message: l10n.deleteAccountConfirm,
        confirmLabel: l10n.delete,
        isDestructive: true,
      );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Real deletion through the security-definer RPC (supabase migration
      // 079_delete_my_account.sql): anonymizes the profile and revokes login.
      await Supabase.instance.client.rpc(
        'delete_my_account',
        params: {'p_reason': 'User requested account deletion'},
      );
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.accountDeleted)));
      }
    } catch (_) {
      // RPC not deployed yet: sign out locally and point the user to support.
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.accountDeletionInfo)));
      }
    }
  }
}
