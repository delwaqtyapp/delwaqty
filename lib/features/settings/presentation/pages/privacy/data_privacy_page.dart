import 'package:flutter/material.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/confirm_dialog.dart';
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
            onTap: () => context.showAppSnackBar(l10n.exportRequestSubmitted),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            title: Text(l10n.deleteAccount, style: const TextStyle(color: Colors.red)),
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

  Future<void> _confirmDelete(BuildContext context, AppLocalizations l10n) async {
      final confirmed = await ConfirmDialog.show(
        context,
        title: l10n.deleteAccount,
        message: l10n.deleteAccountConfirm,
        confirmLabel: l10n.delete,
        isDestructive: true,
      );
    if (confirmed == true && context.mounted) {
      try {
        await Supabase.instance.client.auth.signOut();
        if (context.mounted) {
          context.showAppSnackBar(l10n.accountDeleted);
        }
      } catch (e) {
        if (context.mounted) {
          context.showAppSnackBar('${l10n.error}: $e');
        }
      }
    }
  }
}
